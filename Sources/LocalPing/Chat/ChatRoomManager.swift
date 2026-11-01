import Foundation
import SwiftUI
import AppKit
import Network
import Observation

@MainActor
@Observable
public final class ChatRoomManager: @unchecked Sendable {
    public static let shared = ChatRoomManager()

    // MARK: - Observable State
    public private(set) var messages: [ChatMessage] = []
    public private(set) var unreadCount: Int = 0
    public private(set) var isWindowVisible: Bool = false

    @ObservationIgnored
    public weak var networkManager: NetworkManager?

    @ObservationIgnored
    private let historyFileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("LocalPing", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent("chat_history.json")
    }()

    private init() {
        loadHistory()
    }

    // MARK: - Window Management

    public func openChatWindow() {
        self.isWindowVisible = true
        self.unreadCount = 0
        ChatWindowController.shared.showWindow(peerCount: networkManager?.peers.count ?? 0)
    }

    public func chatWindowDidClose() {
        self.isWindowVisible = false
    }

    // MARK: - Sending Messages (Broadcast)

    public func sendMessage(
        content: String,
        isSnippet: Bool = false,
        snippetLanguage: String? = nil
    ) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let localProfile = networkManager?.userProfile
        let senderId = localProfile?.peerID ?? UUID().uuidString
        let senderName = localProfile?.username ?? "You"

        let message = ChatMessage(
            senderId: senderId,
            senderName: senderName,
            content: trimmed,
            timestamp: Date(),
            isSnippet: isSnippet,
            snippetLanguage: snippetLanguage
        )

        messages.append(message)
        saveHistory()

        // Broadcast to all active peers on the subnet simultaneously
        if let peers = networkManager?.peers, !peers.isEmpty {
            networkManager?.transferManager.broadcastChatMessage(message, to: peers)
        }
    }

    // MARK: - Incoming Messages

    public func handleIncomingMessage(_ message: ChatMessage) {
        // Prevent duplicate messages if already present
        guard !messages.contains(where: { $0.id == message.id }) else { return }

        messages.append(message)
        saveHistory()

        if !isWindowVisible {
            unreadCount += 1
        }

        NSSound(named: "Pop")?.play()
    }

    // MARK: - Actions

    public func deleteMessage(id: UUID) {
        messages.removeAll { $0.id == id }
        saveHistory()
    }

    public func clearHistory() {
        messages.removeAll()
        saveHistory()
    }

    public func exportChatHistory() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        var md = "# LocalPing Subnet Chat History\n"
        md += "**Exported:** \(formatter.string(from: Date()))\n"
        md += "**Total Messages:** \(messages.count)\n\n---\n\n"

        for msg in messages {
            md += "### \(msg.senderName) (\(msg.formattedTime))\n"
            if msg.isSnippet {
                let lang = msg.snippetLanguage ?? ""
                md += "```\(lang)\n\(msg.content)\n```\n\n"
            } else {
                md += "\(msg.content)\n\n"
            }
        }

        return md
    }

    // MARK: - Persistence

    private func saveHistory() {
        let msgs = self.messages
        let url = self.historyFileURL

        Task.detached(priority: .background) {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(msgs)
                try data.write(to: url, options: .atomic)
            } catch {
                print("Failed to save chat history: \(error.localizedDescription)")
            }
        }
    }

    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: historyFileURL)
            let loaded = try JSONDecoder().decode([ChatMessage].self, from: data)
            self.messages = loaded
        } catch {
            print("Failed to load chat history: \(error.localizedDescription)")
        }
    }
}
