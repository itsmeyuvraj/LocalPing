import Foundation
import Network
import Observation

@MainActor
@Observable
public final class NetworkManager {
    public static let serviceType = "_localping._tcp"

    public private(set) var peers: [Peer] = []
    public private(set) var isAdvertising = false
    public private(set) var isBrowsing = false
    public private(set) var listenerPort: UInt16?

    public let transferManager: TransferManager
    public let userProfile: UserProfile

    @ObservationIgnored private var listener: NWListener?
    @ObservationIgnored private var browser: NWBrowser?
    @ObservationIgnored private let listenerQueue = DispatchQueue(label: "localping.net.listener", qos: .userInitiated)
    @ObservationIgnored private let browserQueue = DispatchQueue(label: "localping.net.browser", qos: .userInitiated)

    public init(userProfile: UserProfile, transferManager: TransferManager) {
        self.userProfile = userProfile
        self.transferManager = transferManager
        ClipboardSyncManager.shared.networkManager = self
        SharedCanvasManager.shared.networkManager = self
        ChatRoomManager.shared.networkManager = self
    }

    // MARK: - Lifecycle

    public func start() {
        startListener()
        startBrowser()
    }

    public func stop() {
        stopListener()
        stopBrowser()
        peers = []
    }

    public func restart() {
        stop()
        start()
    }

    // MARK: - Broadcaster / Listener

    public func updatePresence() {
        // Re-publish the service with updated username & status
        guard isAdvertising else { return }
        stopListener()
        startListener()
    }

    private func startListener() {
        guard !isAdvertising else { return }

        do {
            let tcpOptions = NWProtocolTCP.Options()
            tcpOptions.enableKeepalive = true
            tcpOptions.keepaliveIdle = 5

            let parameters = NWParameters(tls: nil, tcp: tcpOptions)
            parameters.includePeerToPeer = true

            let listener = try NWListener(using: parameters)

            var txtRecord = NWTXTRecord()
            txtRecord["id"] = userProfile.peerID
            txtRecord["name"] = userProfile.username
            txtRecord["status"] = userProfile.status

            // Unique service name with suffix prevents Bonjour name clash on same machine/network
            let serviceSuffix = String(userProfile.peerID.prefix(6))
            let advertisedName = "\(userProfile.username)-\(serviceSuffix)"

            listener.service = NWListener.Service(
                name: advertisedName,
                type: Self.serviceType,
                domain: nil,
                txtRecord: txtRecord
            )

            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    switch state {
                    case .ready:
                        self.isAdvertising = true
                        if let port = listener.port?.rawValue {
                            self.listenerPort = port
                        }
                    case .failed, .cancelled:
                        self.isAdvertising = false
                        self.listenerPort = nil
                    default:
                        break
                    }
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
                    self?.transferManager.handleIncomingConnection(connection)
                }
            }

            listener.start(queue: listenerQueue)
            self.listener = listener
        } catch {
            print("Failed to start listener: \(error.localizedDescription)")
            self.isAdvertising = false
        }
    }

    private func stopListener() {
        listener?.cancel()
        listener = nil
        isAdvertising = false
        listenerPort = nil
    }

    // MARK: - Discovery Browser

    private func startBrowser() {
        guard !isBrowsing else { return }

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let descriptor = NWBrowser.Descriptor.bonjourWithTXTRecord(type: Self.serviceType, domain: nil)
        let browser = NWBrowser(for: descriptor, using: parameters)

        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .ready:
                    self.isBrowsing = true
                case .failed, .cancelled:
                    self.isBrowsing = false
                default:
                    break
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor [weak self] in
                self?.handleBrowserResults(results)
            }
        }

        browser.start(queue: browserQueue)
        self.browser = browser
    }

    private func stopBrowser() {
        browser?.cancel()
        browser = nil
        isBrowsing = false
    }

    private func handleBrowserResults(_ results: Set<NWBrowser.Result>) {
        var updatedPeers: [Peer] = []

        for result in results {
            var peerID = ""
            var peerName = "LocalPing Device"
            var peerStatus = "Available"

            if case .bonjour(let txtRecord) = result.metadata {
                if let id = txtRecord["id"] {
                    peerID = id
                }
                if let name = txtRecord["name"] {
                    peerName = name
                }
                if let status = txtRecord["status"] {
                    peerStatus = status
                }
            }

            // Fallback for ID if not in TXT record
            if peerID.isEmpty {
                if case .service(let name, _, _, _) = result.endpoint {
                    peerID = name
                    peerName = name
                } else {
                    peerID = result.endpoint.debugDescription
                }
            }

            // Include local machine as a test target so users can immediately test drops
            if peerID == userProfile.peerID {
                let selfPeer = Peer(
                    id: "\(peerID)-self-test",
                    name: "\(userProfile.username) (This Mac - Drop Test)",
                    status: "📦 Drop files here to test P2P drop",
                    endpoint: result.endpoint,
                    lastSeen: Date(),
                    resolvedAddress: "127.0.0.1 (Loopback)"
                )
                updatedPeers.append(selfPeer)
                continue
            }

            var addressString: String? = nil
            if case .service(_, _, _, let interface) = result.endpoint {
                addressString = interface?.name
            }

            let peer = Peer(
                id: peerID,
                name: peerName,
                status: peerStatus,
                endpoint: result.endpoint,
                lastSeen: Date(),
                resolvedAddress: addressString
            )
            updatedPeers.append(peer)
        }

        // Sort peers alphabetically by name
        self.peers = updatedPeers.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
