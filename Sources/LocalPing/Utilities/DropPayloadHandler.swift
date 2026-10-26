import SwiftUI
import UniformTypeIdentifiers
import AppKit

@MainActor
public enum DropPayloadHandler {
    public static func handleDrop(
        providers: [NSItemProvider],
        onPeer peer: Peer,
        networkManager: NetworkManager
    ) -> Bool {
        for provider in providers {
            // Check for file URL
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    var targetURL: URL?
                    if let url = item as? URL {
                        targetURL = url
                    } else if let nsURL = item as? NSURL {
                        targetURL = nsURL as URL
                    } else if let data = item as? Data {
                        if let url = URL(dataRepresentation: data, relativeTo: nil) {
                            targetURL = url
                        } else if let urlString = String(data: data, encoding: .utf8), let url = URL(string: urlString) {
                            targetURL = url
                        }
                    } else if let urlString = item as? String, let url = URL(string: urlString) {
                        targetURL = url
                    }

                    if let targetURL {
                        Task { @MainActor in
                            networkManager.transferManager.sendFile(
                                url: targetURL,
                                to: peer.endpoint,
                                peerName: peer.name,
                                localSenderName: networkManager.userProfile.username
                            )
                        }
                    }
                }
                return true
            }

            // Check for plain text
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                    var textContent: String?
                    if let str = item as? String {
                        textContent = str
                    } else if let data = item as? Data, let str = String(data: data, encoding: .utf8) {
                        textContent = str
                    }

                    if let textContent {
                        Task { @MainActor in
                            networkManager.transferManager.sendText(
                                text: textContent,
                                to: peer.endpoint,
                                peerName: peer.name,
                                localSenderName: networkManager.userProfile.username
                            )
                        }
                    }
                }
                return true
            }
        }
        return false
    }

    public static func presentFilePicker(forPeer peer: Peer, networkManager: NetworkManager) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Send to \(peer.name)"

        if panel.runModal() == .OK, let url = panel.url {
            networkManager.transferManager.sendFile(
                url: url,
                to: peer.endpoint,
                peerName: peer.name,
                localSenderName: networkManager.userProfile.username
            )
        }
    }

    public static func sendClipboard(toPeer peer: Peer, networkManager: NetworkManager) {
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string), !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            networkManager.transferManager.sendText(
                text: string,
                to: peer.endpoint,
                peerName: peer.name,
                localSenderName: networkManager.userProfile.username
            )
        }
    }
}
