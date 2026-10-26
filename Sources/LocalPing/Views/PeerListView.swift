import SwiftUI

struct PeerListView: View {
    let networkManager: NetworkManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack {
                Text("DISCOVERED PEERS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(networkManager.peers.isEmpty ? Color.orange : Color.green)
                        .frame(width: 6, height: 6)

                    Text("\(networkManager.peers.count) online")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)

            if networkManager.peers.isEmpty {
                // Static, calm empty state (no moving animations)
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
                            .frame(width: 64, height: 64)

                        Circle()
                            .fill(Color.accentColor.opacity(0.08))
                            .frame(width: 48, height: 48)

                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                    .frame(height: 68)

                    VStack(spacing: 4) {
                        Text("Looking for peers...")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("Open LocalPing on another Mac on the same Wi-Fi subnet to instantly share files.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.primary.opacity(0.02))
                .cornerRadius(12)
            } else {
                // List of peers
                VStack(spacing: 8) {
                    ForEach(networkManager.peers) { peer in
                        PeerRowView(peer: peer, networkManager: networkManager)
                    }
                }
            }
        }
    }
}
