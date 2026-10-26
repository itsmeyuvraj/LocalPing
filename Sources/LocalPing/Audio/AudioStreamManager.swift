import Foundation
import AVFoundation
import Network
import Observation

@MainActor
@Observable
public final class AudioStreamManager: @unchecked Sendable {
    public static let shared = AudioStreamManager()

    // MARK: - Observable State for UI
    public private(set) var isTransmitting: Bool = false
    public private(set) var isReceiving: Bool = false
    public private(set) var transmittingToPeerId: String? = nil
    public private(set) var receivingFromPeerName: String? = nil
    public private(set) var micLevel: Float = 0.0
    public private(set) var hasMicrophonePermission: Bool = false

    // MARK: - Audio Configuration
    public let targetSampleRate: Double = 16000.0
    public let targetChannels: UInt32 = 1
    @ObservationIgnored
    public let targetFormat: AVAudioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000.0, channels: 1, interleaved: false)!

    // MARK: - Internal Audio Engines
    private var captureEngine: AVAudioEngine?
    private var playbackEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var activeConnection: NWConnection?

    private let audioQueue = DispatchQueue(label: "localping.audio.capture", qos: .userInteractive)
    private let sendQueue = DispatchQueue(label: "localping.audio.send", qos: .userInteractive)

    public init() {
        setupPlaybackEngine()
        checkMicrophonePermission()
    }

    // MARK: - Permissions

    public func checkMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            self.hasMicrophonePermission = true
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .audio)
                await MainActor.run {
                    self.hasMicrophonePermission = granted
                }
            }
        default:
            self.hasMicrophonePermission = false
        }
    }

    // MARK: - Playback Setup

    private func setupPlaybackEngine() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: targetFormat)

        do {
            try engine.start()
            self.playbackEngine = engine
            self.playerNode = player
        } catch {
            print("Failed to start playback engine: \(error.localizedDescription)")
        }
    }

    public func schedulePlayback(data: Data) {
        guard let player = playerNode, let engine = playbackEngine else { return }

        if !engine.isRunning {
            try? engine.start()
        }

        let frameCount = UInt32(data.count / MemoryLayout<Float>.size)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else { return }

        buffer.frameLength = frameCount

        data.withUnsafeBytes { rawBuffer in
            if let src = rawBuffer.baseAddress, let dst = buffer.floatChannelData?[0] {
                dst.update(from: src.assumingMemoryBound(to: Float.self), count: Int(frameCount))
            }
        }

        player.scheduleBuffer(buffer)
        if !player.isPlaying {
            player.play()
        }
    }

    public func setReceivingState(active: Bool, peerName: String?) {
        self.isReceiving = active
        self.receivingFromPeerName = peerName
    }

    // MARK: - Push-to-Talk Transmission

    public func startPushToTalk(to peer: Peer, localUserName: String) {
        guard !isTransmitting else { return }

        guard hasMicrophonePermission else {
            checkMicrophonePermission()
            return
        }

        self.isTransmitting = true
        self.transmittingToPeerId = peer.id

        Task {
            await self.beginTransmissionStream(to: peer, localUserName: localUserName)
        }
    }

    public func stopPushToTalk() {
        guard isTransmitting else { return }

        stopCapture()

        if let conn = activeConnection {
            // Send empty closing packet
            var zeroLength: UInt32 = 0
            let endData = Data(bytes: &zeroLength, count: 4)
            conn.send(content: endData, isComplete: true, completion: .contentProcessed { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.activeConnection?.cancel()
                    self?.activeConnection = nil
                }
            })
        }

        self.isTransmitting = false
        self.transmittingToPeerId = nil
        self.micLevel = 0.0
    }

    private func beginTransmissionStream(to peer: Peer, localUserName: String) async {
        do {
            let tcpOptions = NWProtocolTCP.Options()
            tcpOptions.enableKeepalive = true
            tcpOptions.noDelay = true // Zero buffering for real-time live audio

            let params = NWParameters(tls: nil, tcp: tcpOptions)
            params.includePeerToPeer = true

            let connection = NWConnection(to: peer.endpoint, using: params)
            self.activeConnection = connection

            try await establishConnection(connection)

            // Send Audio Header
            let header = TransferHeader(
                transferId: UUID().uuidString,
                senderName: localUserName,
                payloadType: .audioStream,
                fileName: "VoiceStream",
                fileSize: 0,
                mimeType: "audio/pcm",
                sampleRate: targetSampleRate,
                channels: targetChannels
            )

            try await sendHeader(header: header, connection: connection)

            // Start Audio Capture & Streaming
            startCapture { [weak self] pcmData in
                self?.sendAudioChunk(pcmData, over: connection)
            }
        } catch {
            print("Failed to start voice stream: \(error.localizedDescription)")
            await MainActor.run {
                self.stopPushToTalk()
            }
        }
    }

    // MARK: - Audio Capture & Conversion

    private func startCapture(onChunk: @escaping @Sendable (Data) -> Void) {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let hwFormat = inputNode.inputFormat(forBus: 0)

        guard hwFormat.sampleRate > 0 else { return }

        guard let converter = AVAudioConverter(from: hwFormat, to: targetFormat) else {
            print("Failed to create audio converter from \(hwFormat) to \(targetFormat)")
            return
        }

        let bufferSize: AVAudioFrameCount = 1024
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: hwFormat) { [weak self] inBuffer, _ in
            let frameCount = AVAudioFrameCount(Double(inBuffer.frameLength) * (16000.0 / hwFormat.sampleRate))
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: self?.targetFormat ?? hwFormat, frameCapacity: max(1, frameCount)) else { return }

            var error: NSError?
            var allConsumed = false

            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                if allConsumed {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                allConsumed = true
                outStatus.pointee = .haveData
                return inBuffer
            }

            guard error == nil, convertedBuffer.frameLength > 0 else { return }

            if let channelData = convertedBuffer.floatChannelData?[0] {
                let length = Int(convertedBuffer.frameLength)

                // Compute RMS for mic meter
                var sum: Float = 0.0
                for i in 0..<length {
                    sum += channelData[i] * channelData[i]
                }
                let rms = sqrt(sum / Float(max(1, length)))
                let normalized = min(1.0, rms * 6.0)

                Task { @MainActor [weak self] in
                    self?.micLevel = normalized
                }

                let byteCount = length * MemoryLayout<Float>.size
                let data = Data(bytes: channelData, count: byteCount)
                onChunk(data)
            }
        }

        do {
            try engine.start()
            self.captureEngine = engine
        } catch {
            print("Failed to start capture engine: \(error.localizedDescription)")
        }
    }

    private func stopCapture() {
        captureEngine?.inputNode.removeTap(onBus: 0)
        captureEngine?.stop()
        captureEngine = nil
    }

    // MARK: - Low-Level Network Helpers

    nonisolated private func sendAudioChunk(_ data: Data, over connection: NWConnection) {
        guard !data.isEmpty else { return }

        var length = UInt32(data.count).bigEndian
        var packet = Data(bytes: &length, count: 4)
        packet.append(data)

        connection.send(content: packet, isComplete: false, completion: .contentProcessed { _ in })
    }

    private func sendHeader(header: TransferHeader, connection: NWConnection) async throws {
        let jsonData = try JSONEncoder().encode(header)
        var magic = TransferHeader.magic.bigEndian
        let magicData = Data(bytes: &magic, count: 4)

        var length = UInt32(jsonData.count).bigEndian
        let lengthData = Data(bytes: &length, count: 4)

        var packet = Data()
        packet.append(magicData)
        packet.append(lengthData)
        packet.append(jsonData)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: packet, isComplete: false, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }

    private func establishConnection(_ connection: NWConnection) async throws {
        final class SafeConnection: @unchecked Sendable {
            private let lock = NSLock()
            private var continuation: CheckedContinuation<Void, Error>?

            init(_ continuation: CheckedContinuation<Void, Error>) {
                self.continuation = continuation
            }

            func resumeSuccess() {
                lock.lock()
                defer { lock.unlock() }
                continuation?.resume(returning: ())
                continuation = nil
            }

            func resumeFailure(_ error: Error) {
                lock.lock()
                defer { lock.unlock() }
                continuation?.resume(throwing: error)
                continuation = nil
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            let safe = SafeConnection(continuation)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    safe.resumeSuccess()
                case .failed(let err):
                    safe.resumeFailure(err)
                case .cancelled:
                    safe.resumeFailure(TransferError.connectionClosedPrematurely)
                default:
                    break
                }
            }
            connection.start(queue: sendQueue)
        }
    }
}
