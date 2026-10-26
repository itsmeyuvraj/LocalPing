import Foundation
import Network
import AppKit

public enum TransferError: LocalizedError, Sendable {
    case invalidMagic
    case invalidHeader
    case invalidPayload
    case connectionClosedPrematurely
    case fileAccessError(String)
    case connectionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidMagic:
            return "Invalid protocol magic header (not a LocalPing stream)."
        case .invalidHeader:
            return "Failed to decode transfer metadata header."
        case .invalidPayload:
            return "Received unexpected or corrupt payload data."
        case .connectionClosedPrematurely:
            return "Connection was closed before payload transfer completed."
        case .fileAccessError(let reason):
            return "File access error: \(reason)"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        }
    }
}

@MainActor
@Observable
public final class TransferManager {
    public private(set) var activeTransfers: [TransferTask] = []
    public private(set) var completedTransfers: [TransferTask] = []

    private let downloadsDirectory: URL

    public init() {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        self.downloadsDirectory = downloads.appendingPathComponent("LocalPing", isDirectory: true)

        try? FileManager.default.createDirectory(at: self.downloadsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Incoming Connection Handling

    public func handleIncomingConnection(_ connection: NWConnection) {
        let queue = DispatchQueue(label: "localping.transfer.incoming.\(UUID().uuidString)")
        connection.start(queue: queue)

        Task {
            await self.processIncomingStream(connection)
        }
    }

    private func processIncomingStream(_ connection: NWConnection) async {
        var taskId: String?
        do {
            // 1. Read 4 bytes Magic Header
            let magicData = try await receiveExact(connection: connection, count: 4)
            let magic = magicData.withUnsafeBytes { $0.load(as: UInt32.self) }
            guard UInt32(bigEndian: magic) == TransferHeader.magic else {
                throw TransferError.invalidMagic
            }

            // 2. Read 4 bytes JSON Header Length
            let lengthData = try await receiveExact(connection: connection, count: 4)
            let headerLengthBigEndian = lengthData.withUnsafeBytes { $0.load(as: UInt32.self) }
            let headerLength = Int(UInt32(bigEndian: headerLengthBigEndian))

            guard headerLength > 0 && headerLength < 1_000_000 else {
                throw TransferError.invalidHeader
            }

            // 3. Read JSON Header
            let headerData = try await receiveExact(connection: connection, count: headerLength)
            let header = try JSONDecoder().decode(TransferHeader.self, from: headerData)

            // 4. Create Task
            let task = TransferTask(
                id: header.transferId,
                peerName: header.senderName,
                direction: .incoming,
                type: header.payloadType,
                fileName: header.fileName,
                fileSize: header.fileSize,
                bytesTransferred: 0,
                state: .transferring(progress: 0.0),
                textContent: header.textContent
            )
            taskId = task.id
            if header.payloadType != .canvasAction && header.payloadType != .chatMessage {
                self.addTransfer(task)
            }

            // 5. Receive Payload
            switch header.payloadType {
            case .text:
                if header.fileSize > 0 {
                    let textData = try await receiveExact(connection: connection, count: Int(header.fileSize))
                    let text = String(data: textData, encoding: .utf8) ?? ""
                    self.updateTransfer(id: task.id) { t in
                        t.textContent = text
                        t.bytesTransferred = UInt64(textData.count)
                        t.state = .completed
                    }
                    self.copyToClipboardIfDesired(text)
                } else {
                    self.updateTransfer(id: task.id) { t in
                        t.state = .completed
                    }
                    if let text = header.textContent {
                        self.copyToClipboardIfDesired(text)
                    }
                }
                NSSound(named: "Glass")?.play()

            case .clipboardSync:
                let text = header.textContent ?? ""
                ClipboardSyncManager.shared.handleIncomingClipboard(
                    senderName: header.senderName,
                    content: text,
                    timestamp: header.timestamp ?? Date()
                )
                if let id = taskId {
                    self.updateTransfer(id: id) { t in
                        t.textContent = text
                        t.state = .completed
                    }
                }

            case .canvasAction:
                if let jsonString = header.textContent,
                   let data = jsonString.data(using: .utf8),
                   let action = try? JSONDecoder().decode(CanvasAction.self, from: data) {
                    SharedCanvasManager.shared.handleIncomingAction(
                        action,
                        fromPeer: header.senderName,
                        peerEndpoint: connection.endpoint
                    )
                }
                if let id = taskId {
                    self.updateTransfer(id: id) { t in
                        t.state = .completed
                    }
                }

            case .chatMessage:
                if let jsonString = header.textContent,
                   let data = jsonString.data(using: .utf8),
                   let message = try? JSONDecoder().decode(ChatMessage.self, from: data) {
                    ChatRoomManager.shared.handleIncomingMessage(message)
                }
                if let id = taskId {
                    self.updateTransfer(id: id) { t in
                        t.state = .completed
                    }
                }

            case .file:
                guard let fileName = header.fileName else {
                    throw TransferError.invalidHeader
                }

                let targetURL = self.resolveDestinationURL(fileName: fileName, in: self.downloadsDirectory)
                FileManager.default.createFile(atPath: targetURL.path, contents: nil)

                guard let fileHandle = try? FileHandle(forWritingTo: targetURL) else {
                    throw TransferError.fileAccessError("Could not open destination file for writing.")
                }

                defer { try? fileHandle.close() }

                var bytesRemaining = header.fileSize
                var bytesReceived: UInt64 = 0

                while bytesRemaining > 0 {
                    let requestCount = min(bytesRemaining, 65_536)
                    let chunk = try await receiveChunk(connection: connection, maxCount: Int(requestCount))
                    guard !chunk.isEmpty else {
                        throw TransferError.connectionClosedPrematurely
                    }

                    try fileHandle.write(contentsOf: chunk)
                    bytesReceived += UInt64(chunk.count)
                    bytesRemaining -= UInt64(chunk.count)

                    let progress = Double(bytesReceived) / Double(max(1, header.fileSize))
                    self.updateTransfer(id: task.id) { t in
                        t.bytesTransferred = bytesReceived
                        t.state = .transferring(progress: progress)
                        t.localURL = targetURL
                    }
                }

                self.updateTransfer(id: task.id) { t in
                    t.state = .completed
                    t.localURL = targetURL
                }
                NSSound(named: "Glass")?.play()

            case .audioStream:
                AudioStreamManager.shared.setReceivingState(active: true, peerName: header.senderName)
                defer {
                    AudioStreamManager.shared.setReceivingState(active: false, peerName: nil)
                }

                self.updateTransfer(id: task.id) { t in
                    t.state = .transferring(progress: 1.0)
                }

                while true {
                    let lengthData = try await receiveExact(connection: connection, count: 4)
                    let packetLengthBigEndian = lengthData.withUnsafeBytes { $0.load(as: UInt32.self) }
                    let packetLength = Int(UInt32(bigEndian: packetLengthBigEndian))

                    guard packetLength > 0 else {
                        break
                    }

                    guard packetLength < 1_000_000 else {
                        throw TransferError.invalidPayload
                    }

                    let audioData = try await receiveExact(connection: connection, count: packetLength)
                    AudioStreamManager.shared.schedulePlayback(data: audioData)
                }

                self.updateTransfer(id: task.id) { t in
                    t.state = .completed
                }
            }

            connection.cancel()
        } catch {
            if let id = taskId {
                self.updateTransfer(id: id) { t in
                    t.state = .failed(reason: error.localizedDescription)
                }
            }
            connection.cancel()
        }
    }

    // MARK: - Outgoing Transfers

    public func sendFile(
        url: URL,
        to endpoint: NWEndpoint,
        peerName: String,
        localSenderName: String
    ) {
        let task = TransferTask(
            id: UUID().uuidString,
            peerName: peerName,
            direction: .outgoing,
            type: .file,
            fileName: url.lastPathComponent,
            fileSize: (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize.map(UInt64.init)) ?? 0,
            bytesTransferred: 0,
            state: .queued,
            localURL: url
        )
        self.addTransfer(task)

        Task {
            await self.executeFileSend(task: task, fileURL: url, endpoint: endpoint, localSenderName: localSenderName)
        }
    }

    public func sendText(
        text: String,
        to endpoint: NWEndpoint,
        peerName: String,
        localSenderName: String
    ) {
        let data = Data(text.utf8)
        let task = TransferTask(
            id: UUID().uuidString,
            peerName: peerName,
            direction: .outgoing,
            type: .text,
            fileName: "Snippet.txt",
            fileSize: UInt64(data.count),
            bytesTransferred: 0,
            state: .queued,
            textContent: text
        )
        self.addTransfer(task)

        Task {
            await self.executeTextSend(task: task, textData: data, endpoint: endpoint, localSenderName: localSenderName)
        }
    }

    private func executeFileSend(
        task: TransferTask,
        fileURL: URL,
        endpoint: NWEndpoint,
        localSenderName: String
    ) async {
        do {
            let connection = try await establishConnection(to: endpoint)

            let header = TransferHeader(
                transferId: task.id,
                senderName: localSenderName,
                payloadType: .file,
                fileName: fileURL.lastPathComponent,
                fileSize: task.fileSize,
                mimeType: nil,
                textContent: nil
            )

            try await sendHeader(header: header, over: connection)

            guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
                throw TransferError.fileAccessError("Could not read source file at \(fileURL.path)")
            }
            defer { try? fileHandle.close() }

            var bytesSent: UInt64 = 0
            while bytesSent < task.fileSize {
                let chunkSize = min(65_536, task.fileSize - bytesSent)
                guard let chunk = try fileHandle.read(upToCount: Int(chunkSize)), !chunk.isEmpty else {
                    break
                }

                let isLast = (bytesSent + UInt64(chunk.count)) >= task.fileSize
                try await sendData(connection: connection, data: chunk, isComplete: isLast)

                bytesSent += UInt64(chunk.count)
                let progress = Double(bytesSent) / Double(max(1, task.fileSize))
                self.updateTransfer(id: task.id) { t in
                    t.bytesTransferred = bytesSent
                    t.state = .transferring(progress: progress)
                }
            }

            self.updateTransfer(id: task.id) { t in
                t.bytesTransferred = bytesSent
                t.state = .completed
            }
            connection.cancel()
        } catch {
            self.updateTransfer(id: task.id) { t in
                t.state = .failed(reason: error.localizedDescription)
            }
        }
    }

    private func executeTextSend(
        task: TransferTask,
        textData: Data,
        endpoint: NWEndpoint,
        localSenderName: String
    ) async {
        do {
            let connection = try await establishConnection(to: endpoint)

            let header = TransferHeader(
                transferId: task.id,
                senderName: localSenderName,
                payloadType: .text,
                fileName: "Snippet.txt",
                fileSize: UInt64(textData.count),
                mimeType: "text/plain",
                textContent: task.textContent
            )

            try await sendHeader(header: header, over: connection)

            if !textData.isEmpty {
                try await sendData(connection: connection, data: textData, isComplete: true)
            }

            self.updateTransfer(id: task.id) { t in
                t.bytesTransferred = UInt64(textData.count)
                t.state = .completed
            }
            connection.cancel()
        } catch {
            self.updateTransfer(id: task.id) { t in
                t.state = .failed(reason: error.localizedDescription)
            }
        }
    }

    public func sendClipboardSync(
        text: String,
        to endpoint: NWEndpoint,
        peerName: String,
        localSenderName: String
    ) {
        Task {
            do {
                let connection = try await establishConnection(to: endpoint)
                let header = TransferHeader(
                    transferId: UUID().uuidString,
                    senderName: localSenderName,
                    payloadType: .clipboardSync,
                    fileName: "ClipboardSync",
                    fileSize: UInt64(text.utf8.count),
                    mimeType: "text/plain",
                    textContent: text,
                    timestamp: Date()
                )
                try await sendHeader(header: header, over: connection)
                connection.cancel()
            } catch {
                print("Failed to dispatch clipboard sync to \(peerName): \(error.localizedDescription)")
            }
        }
    }

    public func sendCanvasAction(
        _ action: CanvasAction,
        to endpoint: NWEndpoint,
        peerName: String,
        localSenderName: String
    ) {
        Task {
            do {
                let actionData = try JSONEncoder().encode(action)
                guard let jsonString = String(data: actionData, encoding: .utf8) else { return }

                let connection = try await establishConnection(to: endpoint)
                let header = TransferHeader(
                    transferId: UUID().uuidString,
                    senderName: localSenderName,
                    payloadType: .canvasAction,
                    fileName: "CanvasAction",
                    fileSize: UInt64(actionData.count),
                    mimeType: "application/json",
                    textContent: jsonString,
                    timestamp: Date()
                )
                try await sendHeader(header: header, over: connection)
                connection.cancel()
            } catch {
                print("Failed to dispatch canvas action to \(peerName): \(error.localizedDescription)")
            }
        }
    }

    public func broadcastChatMessage(_ message: ChatMessage, to peers: [Peer]) {
        for peer in peers {
            sendChatMessage(message, to: peer.endpoint, peerName: peer.name, localSenderName: message.senderName)
        }
    }

    public func sendChatMessage(
        _ message: ChatMessage,
        to endpoint: NWEndpoint,
        peerName: String,
        localSenderName: String
    ) {
        Task {
            do {
                let msgData = try JSONEncoder().encode(message)
                guard let jsonString = String(data: msgData, encoding: .utf8) else { return }

                let connection = try await establishConnection(to: endpoint)
                let header = TransferHeader(
                    transferId: message.id.uuidString,
                    senderName: localSenderName,
                    payloadType: .chatMessage,
                    fileName: "ChatMessage",
                    fileSize: UInt64(msgData.count),
                    mimeType: "application/json",
                    textContent: jsonString,
                    timestamp: message.timestamp
                )
                try await sendHeader(header: header, over: connection)
                connection.cancel()
            } catch {
                print("Failed to dispatch chat message to \(peerName): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Connection & Low-level Stream Helpers

    private final class SafeConnectionContinuation: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<NWConnection, Error>?
        private let connection: NWConnection

        init(_ continuation: CheckedContinuation<NWConnection, Error>, connection: NWConnection) {
            self.continuation = continuation
            self.connection = connection
        }

        func resumeReady() {
            lock.lock()
            defer { lock.unlock() }
            continuation?.resume(returning: connection)
            continuation = nil
        }

        func resume(throwing error: Error) {
            lock.lock()
            defer { lock.unlock() }
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }

    private func establishConnection(to endpoint: NWEndpoint) async throws -> NWConnection {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        let params = NWParameters(tls: nil, tcp: tcpOptions)
        params.includePeerToPeer = true

        let connection = NWConnection(to: endpoint, using: params)
        let queue = DispatchQueue(label: "localping.transfer.out.\(UUID().uuidString)")

        return try await withCheckedThrowingContinuation { continuation in
            let safeContinuation = SafeConnectionContinuation(continuation, connection: connection)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    safeContinuation.resumeReady()
                case .failed(let error):
                    safeContinuation.resume(throwing: TransferError.connectionFailed(error.localizedDescription))
                case .cancelled:
                    safeContinuation.resume(throwing: TransferError.connectionClosedPrematurely)
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    private func sendHeader(header: TransferHeader, over connection: NWConnection) async throws {
        let jsonData = try JSONEncoder().encode(header)
        var magic = TransferHeader.magic.bigEndian
        let magicData = Data(bytes: &magic, count: 4)

        var length = UInt32(jsonData.count).bigEndian
        let lengthData = Data(bytes: &length, count: 4)

        var packet = Data()
        packet.append(magicData)
        packet.append(lengthData)
        packet.append(jsonData)

        try await sendData(connection: connection, data: packet, isComplete: false)
    }

    private func sendData(connection: NWConnection, data: Data, isComplete: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, isComplete: isComplete, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }

    private func receiveExact(connection: NWConnection, count: Int) async throws -> Data {
        var accumulated = Data()
        while accumulated.count < count {
            let needed = count - accumulated.count
            let chunk = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                connection.receive(minimumIncompleteLength: 1, maximumLength: needed) { data, _, isComplete, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let data = data, !data.isEmpty {
                        continuation.resume(returning: data)
                    } else if isComplete {
                        continuation.resume(throwing: TransferError.connectionClosedPrematurely)
                    } else {
                        continuation.resume(throwing: TransferError.invalidPayload)
                    }
                }
            }
            accumulated.append(chunk)
        }
        return accumulated
    }

    private func receiveChunk(connection: NWConnection, maxCount: Int) async throws -> Data {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: maxCount) { data, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(returning: Data())
                } else {
                    continuation.resume(returning: Data())
                }
            }
        }
    }

    // MARK: - State Management

    private func addTransfer(_ task: TransferTask) {
        activeTransfers.insert(task, at: 0)
    }

    private func updateTransfer(id: String, mutate: (inout TransferTask) -> Void) {
        if let idx = activeTransfers.firstIndex(where: { $0.id == id }) {
            var task = activeTransfers[idx]
            mutate(&task)
            if task.state.isTerminal {
                activeTransfers.remove(at: idx)
                completedTransfers.insert(task, at: 0)
                if completedTransfers.count > 20 {
                    completedTransfers.removeLast()
                }
            } else {
                activeTransfers[idx] = task
            }
        }
    }

    private func copyToClipboardIfDesired(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func resolveDestinationURL(fileName: String, in directory: URL) -> URL {
        var destination = directory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: destination.path) else {
            return destination
        }

        let baseName = destination.deletingPathExtension().lastPathComponent
        let ext = destination.pathExtension
        var counter = 1

        while FileManager.default.fileExists(atPath: destination.path) {
            let newName = ext.isEmpty ? "\(baseName) (\(counter))" : "\(baseName) (\(counter)).\(ext)"
            destination = directory.appendingPathComponent(newName)
            counter += 1
        }
        return destination
    }

    public func openDownloadsFolder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: downloadsDirectory.path)
    }
}
