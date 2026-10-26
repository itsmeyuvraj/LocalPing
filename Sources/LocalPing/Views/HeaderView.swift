import SwiftUI

struct HeaderView: View {
    @Bindable var userProfile: UserProfile
    let networkManager: NetworkManager
    @Binding var isPinned: Bool
    let onClose: () -> Void

    @FocusState private var isNameFocused: Bool
    @State private var isEditingName = false
    @State private var isSpinning = false

    init(
        userProfile: UserProfile,
        networkManager: NetworkManager,
        isPinned: Binding<Bool> = .constant(true),
        onClose: @escaping () -> Void = {}
    ) {
        self.userProfile = userProfile
        self.networkManager = networkManager
        self._isPinned = isPinned
        self.onClose = onClose
    }

    var body: some View {
        HStack(spacing: 10) {
            // User Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Text(avatarInitials)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Circle()
                    .fill(networkManager.isAdvertising ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color(NSColor.windowBackgroundColor), lineWidth: 1.5))
                    .offset(x: 11, y: 11)
            }

            // Name & Status
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if isEditingName {
                        TextField("Your Name", text: $userProfile.username)
                            .font(.system(size: 13, weight: .semibold))
                            .textFieldStyle(.plain)
                            .focused($isNameFocused)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08))
                            )
                            .onSubmit {
                                commitNameChange()
                            }
                    } else {
                        Text(userProfile.username.isEmpty ? "LocalPing User" : userProfile.username)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .onTapGesture {
                                startEditingName()
                            }
                    }

                    Button {
                        if isEditingName {
                            commitNameChange()
                        } else {
                            startEditingName()
                        }
                    } label: {
                        Image(systemName: isEditingName ? "checkmark.circle.fill" : "pencil")
                            .font(.system(size: isEditingName ? 12 : 10))
                            .foregroundColor(isEditingName ? .accentColor : .secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help(isEditingName ? "Save Name" : "Edit Name")
                }
                .onChange(of: isNameFocused) { _, focused in
                    if !focused && isEditingName {
                        commitNameChange()
                    }
                }

                // Compact native Status Menu
                Menu {
                    ForEach(UserProfile.statusPresets, id: \.self) { preset in
                        Button {
                            userProfile.status = preset
                            networkManager.updatePresence()
                        } label: {
                            HStack {
                                Text(preset)
                                if userProfile.status == preset {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 5, height: 5)

                        Text(userProfile.status)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }

            Spacer()

            // Header Utility Buttons
            HStack(spacing: 4) {
                // Rescan button
                Button {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        isSpinning = true
                    }
                    networkManager.restart()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        isSpinning = false
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isSpinning ? 360 : 0))
                        .padding(5)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Rescan network")

                // Pin Window Button
                Button {
                    isPinned.toggle()
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isPinned ? .accentColor : .secondary)
                        .padding(5)
                        .background(isPinned ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(isPinned ? "Pinned: Window stays open" : "Pin window open")

                // Close Button
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Close popover (Esc)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        .cornerRadius(10)
    }

    private func startEditingName() {
        isEditingName = true
        isNameFocused = true
    }

    private func commitNameChange() {
        isEditingName = false
        isNameFocused = false
        networkManager.updatePresence()
    }

    private var statusColor: Color {
        switch userProfile.status.lowercased() {
        case "available": return .green
        case "busy", "in a flow": return .orange
        case "away": return .gray
        default: return .green
        }
    }

    private var avatarInitials: String {
        let trimmed = userProfile.username.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "ME" }
        let components = trimmed.split(separator: " ")
        if components.count >= 2, let first = components.first?.first, let second = components[1].first {
            return "\(first)\(second)".uppercased()
        }
        return String(trimmed.prefix(2)).uppercased()
    }
}
