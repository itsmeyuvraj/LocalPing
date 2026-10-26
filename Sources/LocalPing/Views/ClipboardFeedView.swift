import SwiftUI

struct ClipboardFeedView: View {
    @Bindable var clipboardManager = ClipboardSyncManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Controls
            HStack {
                Text("CLIPBOARD SYNC")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)

                Spacer()

                // Sync toggle switch
                Toggle("", isOn: $clipboardManager.isBroadcastingEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .help(clipboardManager.isBroadcastingEnabled ? "Clipboard syncing active" : "Clipboard syncing paused")

                Text(clipboardManager.isBroadcastingEnabled ? "Active" : "Paused")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(clipboardManager.isBroadcastingEnabled ? .green : .secondary)

                if !clipboardManager.history.isEmpty {
                    Button {
                        clipboardManager.clearHistory()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear clipboard history")
                }
            }
            .padding(.horizontal, 4)

            // Settings Bar
            HStack(spacing: 8) {
                Toggle(isOn: $clipboardManager.isAutoCopyEnabled) {
                    Text("Auto-apply to system clipboard")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .toggleStyle(.checkbox)
                .controlSize(.small)

                Spacer()
            }
            .padding(.horizontal, 4)

            // Feed Content
            if clipboardManager.history.isEmpty {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.08))
                            .frame(width: 44, height: 44)

                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)
                    }

                    VStack(spacing: 3) {
                        Text("No clips shared yet")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("Copy text anywhere on your Mac to sync with peers, or receive clips copied by nearby devices.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.primary.opacity(0.02))
                .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(clipboardManager.history) { item in
                        clipboardCard(item: item)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func clipboardCard(item: ClipboardItem) -> some View {
        let isJustCopied = clipboardManager.lastCopiedItemId == item.id

        VStack(alignment: .leading, spacing: 6) {
            // Header: Sender & Timestamp & Copy Button
            HStack(spacing: 6) {
                // Sender Pill
                Text(item.senderName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(item.senderName.contains("You") ? .secondary : .accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        item.senderName.contains("You") ?
                        Color.primary.opacity(0.06) :
                        Color.accentColor.opacity(0.12)
                    )
                    .cornerRadius(4)

                Text("• \(item.relativeTime)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)

                Spacer()

                // 1-Click Copy Button
                Button {
                    clipboardManager.copyItem(item)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: isJustCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .medium))
                        Text(isJustCopied ? "Copied" : "Copy")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(isJustCopied ? .green : .accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(isJustCopied ? Color.green.opacity(0.12) : Color.primary.opacity(0.06))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Copy to system clipboard")
            }

            // Text Preview
            Text(item.preview)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(3)
                .textSelection(.enabled)
        }
        .padding(10)
        .background(Color.primary.opacity(0.035))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isJustCopied ? Color.green.opacity(0.5) : Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
