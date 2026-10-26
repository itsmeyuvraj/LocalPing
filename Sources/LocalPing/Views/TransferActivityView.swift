import SwiftUI

struct TransferActivityView: View {
    let transferManager: TransferManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("TRANSFERS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    transferManager.openDownloadsFolder()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                        Text("Downloads")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Open received files in Finder")
            }
            .padding(.horizontal, 4)

            // Active Transfers
            if !transferManager.activeTransfers.isEmpty {
                VStack(spacing: 8) {
                    ForEach(transferManager.activeTransfers) { task in
                        activeTransferCard(task: task)
                    }
                }
            }

            // Completed Transfers (Recent)
            if !transferManager.completedTransfers.isEmpty {
                VStack(spacing: 6) {
                    ForEach(transferManager.completedTransfers.prefix(3)) { task in
                        completedTransferRow(task: task)
                    }
                }
            }

            if transferManager.activeTransfers.isEmpty && transferManager.completedTransfers.isEmpty {
                HStack {
                    Spacer()
                    Text("No recent transfers")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.8))
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private func activeTransferCard(task: TransferTask) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: task.direction == .outgoing ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundColor(task.direction == .outgoing ? .blue : .green)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.fileName ?? "Text Snippet")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)

                    Text(task.direction == .outgoing ? "Sending to \(task.peerName)" : "Receiving from \(task.peerName)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(Int(task.progress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // Progress Bar
            ProgressView(value: task.progress)
                .progressViewStyle(.linear)
                .tint(task.direction == .outgoing ? Color.blue : Color.green)

            HStack {
                Text("\(task.formattedTransferred) / \(task.formattedSize)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(10)
    }

    @ViewBuilder
    private func completedTransferRow(task: TransferTask) -> some View {
        HStack(spacing: 8) {
            switch task.state {
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 12))
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 12))
            default:
                Image(systemName: "circle")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(task.fileName ?? (task.textContent.map { "\"\($0.prefix(20))...\"" } ?? "Transfer"))
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)

                Text(task.direction == .outgoing ? "To \(task.peerName)" : "From \(task.peerName)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let url = task.localURL {
                Button {
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Show in Finder")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.02))
        .cornerRadius(6)
    }
}
