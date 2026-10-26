import SwiftUI

public enum MainTab: String, CaseIterable, Identifiable {
    case peers = "Peers"
    case clipboard = "Clipboard"
    case activity = "Activity"

    public var id: String { rawValue }
}

public struct ContentView: View {
    public let networkManager: NetworkManager
    @Binding public var isPinned: Bool
    public let onClose: () -> Void

    @State private var selectedTab: MainTab = .peers

    public init(
        networkManager: NetworkManager,
        isPinned: Binding<Bool> = .constant(true),
        onClose: @escaping () -> Void = {}
    ) {
        self.networkManager = networkManager
        self._isPinned = isPinned
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Top User Profile Header
            HeaderView(
                userProfile: networkManager.userProfile,
                networkManager: networkManager,
                isPinned: $isPinned,
                onClose: onClose
            )
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 6)

            // 2. Segmented Navigation Tabs
            Picker("", selection: $selectedTab) {
                Text("Peers").tag(MainTab.peers)

                if !ClipboardSyncManager.shared.history.isEmpty {
                    Text("Clipboard (\(ClipboardSyncManager.shared.history.count))")
                        .tag(MainTab.clipboard)
                } else {
                    Text("Clipboard").tag(MainTab.clipboard)
                }

                Text("Transfers").tag(MainTab.activity)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()
                .opacity(0.4)

            // 3. Main Content Feed
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    switch selectedTab {
                    case .peers:
                        PeerListView(networkManager: networkManager)
                    case .clipboard:
                        ClipboardFeedView()
                    case .activity:
                        TransferActivityView(transferManager: networkManager.transferManager)
                    }
                }
                .padding(12)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 380)

            Divider()
                .opacity(0.4)

            // 4. Clean Bottom Utility Footer
            HStack(spacing: 8) {
                // Connection status dot & peer count
                HStack(spacing: 5) {
                    Circle()
                        .fill(networkManager.isAdvertising ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)

                    Text(networkManager.peers.isEmpty ? "Listening for peers..." : "\(networkManager.peers.count) online")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Subnet Chat Button
                Button {
                    ChatRoomManager.shared.openChatWindow()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 11, weight: .medium))
                        if ChatRoomManager.shared.unreadCount > 0 {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 5, height: 5)
                        }
                    }
                    .foregroundColor(.secondary)
                    .padding(5)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Subnet Chat Room")

                // Shared Canvas Button
                Button {
                    if let firstPeer = networkManager.peers.first {
                        SharedCanvasManager.shared.openCanvas(with: firstPeer, localUserName: networkManager.userProfile.username)
                    } else {
                        SharedCanvasManager.shared.openLocalCanvas(localUserName: networkManager.userProfile.username)
                    }
                } label: {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Collaborative Canvas")

                // Quit Button
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Quit LocalPing")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
        }
        .frame(width: 350)
        .background(.ultraThinMaterial)
        .onExitCommand {
            onClose()
        }
    }
}
