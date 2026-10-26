import SwiftUI
import UniformTypeIdentifiers

struct PeerRowView: View {
    let peer: Peer
    let networkManager: NetworkManager

    @State private var isTargeted = false
    @State private var isHovered = false

    private var isTransmittingToThisPeer: Bool {
        AudioStreamManager.shared.isTransmitting && AudioStreamManager.shared.transmittingToPeerId == peer.id
    }

    private var isReceivingFromThisPeer: Bool {
        AudioStreamManager.shared.isReceiving && AudioStreamManager.shared.receivingFromPeerName == peer.name
    }

    var body: some View {
        HStack(spacing: 10) {
            peerAvatar
            peerInfo
            Spacer()
            actionArea
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(rowBackground)
        .overlay(rowBorder)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onDrop(of: [.item, .fileURL, .text, .utf8PlainText], isTargeted: $isTargeted) { providers in
            DropPayloadHandler.handleDrop(providers: providers, onPeer: peer, networkManager: networkManager)
        }
        .help(tooltipText)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var peerAvatar: some View {
        ZStack {
            Circle()
                .fill(avatarColor.gradient)
                .frame(width: 34, height: 34)

            Text(initials)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }

    @ViewBuilder
    private var peerInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(peer.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                statusBadge
            }

            Text(peer.status)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isTargeted {
            Text("Drop to Send")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.cyan)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.cyan.opacity(0.15))
                .cornerRadius(4)
        } else if isReceivingFromThisPeer {
            HStack(spacing: 3) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 8))
                Text("Speaking")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(.green)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color.green.opacity(0.12))
            .cornerRadius(4)
        } else if isTransmittingToThisPeer {
            HStack(spacing: 3) {
                Image(systemName: "waveform")
                    .font(.system(size: 8))
                Text("Live")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(.red)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color.red.opacity(0.12))
            .cornerRadius(4)
        }
    }

    @ViewBuilder
    private var actionArea: some View {
        HStack(spacing: 4) {
            if isTransmittingToThisPeer {
                Button {
                    AudioStreamManager.shared.stopPushToTalk()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "waveform")
                            .font(.system(size: 9, weight: .bold))
                        Text("Stop")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.red)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Stop streaming audio")
            } else if isHovered || isTargeted {
                Button {
                    DropPayloadHandler.presentFilePicker(forPeer: peer, networkManager: networkManager)
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Send file to \(peer.name)")

                moreActionsMenu
            }
        }
    }

    @ViewBuilder
    private var moreActionsMenu: some View {
        Menu {
            Button {
                DropPayloadHandler.presentFilePicker(forPeer: peer, networkManager: networkManager)
            } label: {
                Label("Send File...", systemImage: "paperclip")
            }

            Button {
                DropPayloadHandler.sendClipboard(toPeer: peer, networkManager: networkManager)
            } label: {
                Label("Send Clipboard", systemImage: "doc.on.clipboard")
            }

            Divider()

            Button {
                ChatRoomManager.shared.openChatWindow()
            } label: {
                Label("Open Chat Room", systemImage: "bubble.left.and.bubble.right")
            }

            Button {
                SharedCanvasManager.shared.openCanvas(with: peer, localUserName: networkManager.userProfile.username)
            } label: {
                Label("Shared Canvas", systemImage: "pencil.and.outline")
            }

            Divider()

            Button {
                AudioStreamManager.shared.startPushToTalk(to: peer, localUserName: networkManager.userProfile.username)
            } label: {
                Label("Push-to-Talk (Mic)", systemImage: "mic.fill")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .padding(5)
                .background(Color.primary.opacity(0.06))
                .clipShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("Actions for \(peer.name)")
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(
                isTargeted ?
                Color.cyan.opacity(0.12) :
                (isHovered ? Color.primary.opacity(0.04) : Color.primary.opacity(0.015))
            )
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(
                isTargeted ? Color.cyan.opacity(0.6) : Color.clear,
                lineWidth: 1.5
            )
    }

    private var tooltipText: String {
        if let address = peer.resolvedAddress {
            return "\(peer.name) (\(address))"
        }
        return peer.name
    }

    private var initials: String {
        let trimmed = peer.name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "?" }
        let components = trimmed.split(separator: " ")
        if components.count >= 2, let first = components.first?.first, let second = components[1].first {
            return "\(first)\(second)".uppercased()
        }
        return String(trimmed.prefix(2)).uppercased()
    }

    private var avatarColor: Color {
        let colors: [Color] = [.cyan, .purple, .pink, .orange, .green, .indigo, .mint]
        var hash = 0
        for byte in peer.id.utf8 {
            hash = (hash &* 31) &+ Int(byte)
        }
        let index = abs(hash) % colors.count
        return colors[index]
    }
}
