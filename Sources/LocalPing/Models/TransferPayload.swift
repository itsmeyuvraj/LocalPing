import Foundation

public enum PayloadType: String, Codable, Sendable {
    case file
    case text
    case audioStream
    case clipboardSync
    case canvasAction
    case chatMessage
}

public struct TransferHeader: Codable, Sendable {
    public static let magic: UInt32 = 0x4C504E47 // "LPNG" in ASCII

    public let transferId: String
    public let senderName: String
    public let payloadType: PayloadType
    public let fileName: String?
    public let fileSize: UInt64
    public let mimeType: String?
    public let textContent: String?
    public let sampleRate: Double?
    public let channels: UInt32?
    public let timestamp: Date?

    public init(
        transferId: String = UUID().uuidString,
        senderName: String,
        payloadType: PayloadType,
        fileName: String? = nil,
        fileSize: UInt64 = 0,
        mimeType: String? = nil,
        textContent: String? = nil,
        sampleRate: Double? = nil,
        channels: UInt32? = nil,
        timestamp: Date? = nil
    ) {
        self.transferId = transferId
        self.senderName = senderName
        self.payloadType = payloadType
        self.fileName = fileName
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.textContent = textContent
        self.sampleRate = sampleRate
        self.channels = channels
        self.timestamp = timestamp
    }
}

public enum TransferDirection: String, Sendable {
    case incoming
    case outgoing
}

public enum TransferState: Equatable, Sendable {
    case queued
    case transferring(progress: Double)
    case completed
    case failed(reason: String)

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed: return true
        default: return false
        }
    }
}

public struct TransferTask: Identifiable, Sendable {
    public let id: String
    public let peerName: String
    public let direction: TransferDirection
    public let type: PayloadType
    public let fileName: String?
    public let fileSize: UInt64
    public var bytesTransferred: UInt64
    public var state: TransferState
    public var localURL: URL?
    public var textContent: String?
    public let timestamp: Date

    public init(
        id: String = UUID().uuidString,
        peerName: String,
        direction: TransferDirection,
        type: PayloadType,
        fileName: String? = nil,
        fileSize: UInt64 = 0,
        bytesTransferred: UInt64 = 0,
        state: TransferState = .queued,
        localURL: URL? = nil,
        textContent: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.peerName = peerName
        self.direction = direction
        self.type = type
        self.fileName = fileName
        self.fileSize = fileSize
        self.bytesTransferred = bytesTransferred
        self.state = state
        self.localURL = localURL
        self.textContent = textContent
        self.timestamp = timestamp
    }

    public var progress: Double {
        guard fileSize > 0 else {
            if case .completed = state { return 1.0 }
            return 0.0
        }
        return min(1.0, max(0.0, Double(bytesTransferred) / Double(fileSize)))
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }

    public var formattedTransferred: String {
        ByteCountFormatter.string(fromByteCount: Int64(bytesTransferred), countStyle: .file)
    }
}
