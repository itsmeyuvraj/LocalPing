import Foundation
import AppKit
import Observation

@MainActor
@Observable
public final class ClipboardSyncManager {
    public static let shared = ClipboardSyncManager()

    private let kBroadcastEnabled = "localping.clipboard.broadcast"
    private let kAutoCopyEnabled = "localping.clipboard.autocopy"

    public var isBroadcastingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isBroadcastingEnabled, forKey: kBroadcastEnabled)
            if isBroadcastingEnabled {
                startMonitoring()
            }
        }
    }

    public var isAutoCopyEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAutoCopyEnabled, forKey: kAutoCopyEnabled)
        }
    }

    public private(set) var history: [ClipboardItem] = []
    public private(set) var lastCopiedItemId: String? = nil

    @ObservationIgnored private var lastChangeCount: Int = 0
    @ObservationIgnored private var lastSentContent: String? = nil
    @ObservationIgnored private var lastReceivedContent: String? = nil
    @ObservationIgnored private var monitorTimer: Timer?

    public weak var networkManager: NetworkManager?

    public init() {
        self.isBroadcastingEnabled = UserDefaults.standard.object(forKey: kBroadcastEnabled) as? Bool ?? true
        self.isAutoCopyEnabled = UserDefaults.standard.object(forKey: kAutoCopyEnabled) as? Bool ?? false
        self.lastChangeCount = NSPasteboard.general.changeCount

        if isBroadcastingEnabled {
            startMonitoring()
        }
    }

    // MARK: - Monitoring

    public func startMonitoring() {
        monitorTimer?.invalidate()
        lastChangeCount = NSPasteboard.general.changeCount

        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForPasteboardChanges()
            }
        }
    }

    public func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    private func checkForPasteboardChanges() {
        guard isBroadcastingEnabled else { return }

        let currentChangeCount = NSPasteboard.general.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        guard let text = NSPasteboard.general.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Prevent echo loops: don't re-broadcast what we just received or just sent
        guard text != lastReceivedContent && text != lastSentContent else { return }
        lastSentContent = text

        // Add local entry to history
        let localItem = ClipboardItem(
            senderName: "You (Local)",
            content: text,
            timestamp: Date()
        )
        addHistoryItem(localItem)

        // Broadcast to all active peers
        broadcastClipboard(text: text)
    }

    // MARK: - Network Dispatch

    public func broadcastClipboard(text: String) {
        guard let networkManager else { return }

        let activePeers = networkManager.peers
        guard !activePeers.isEmpty else { return }

        for peer in activePeers {
            networkManager.transferManager.sendClipboardSync(
                text: text,
                to: peer.endpoint,
                peerName: peer.name,
                localSenderName: networkManager.userProfile.username
            )
        }
    }

    // MARK: - Incoming Clips Handling

    public func handleIncomingClipboard(senderName: String, content: String, timestamp: Date) {
        guard !content.isEmpty else { return }

        // Ignore if it's identical to what we sent or already received
        guard content != lastSentContent else { return }

        lastReceivedContent = content

        let item = ClipboardItem(
            senderName: senderName,
            content: content,
            timestamp: timestamp
        )
        addHistoryItem(item)

        // Auto-copy to local system pasteboard if option is enabled
        if isAutoCopyEnabled {
            copyToSystemPasteboard(content: content)
        }

        NSSound(named: "Tink")?.play()
    }

    // MARK: - User Action: Copy to System Pasteboard

    public func copyItem(_ item: ClipboardItem) {
        copyToSystemPasteboard(content: item.content)
        self.lastCopiedItemId = item.id

        // Clear feedback after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            if self?.lastCopiedItemId == item.id {
                self?.lastCopiedItemId = nil
            }
        }
    }

    private func copyToSystemPasteboard(content: String) {
        lastReceivedContent = content
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }

    private func addHistoryItem(_ item: ClipboardItem) {
        // Prevent duplicate adjacent entries
        if let first = history.first, first.content == item.content {
            return
        }
        history.insert(item, at: 0)
        if history.count > 40 {
            history.removeLast()
        }
    }

    public func clearHistory() {
        history.removeAll()
    }
}
