import SwiftUI
import AppKit

public struct ChatRoomView: View {
    @State private var chatManager = ChatRoomManager.shared
    @State private var inputText: String = ""
    @State private var isSnippetMode: Bool = false
    @State private var selectedLanguage: SyntaxLanguage = .swift
    @State private var showClearConfirmation: Bool = false
    @State private var searchQuery: String = ""
    @State private var isSearchActive: Bool = false
    @State private var showPeersPopover: Bool = false
    @FocusState private var isInputFocused: Bool
    @FocusState private var isSearchFocused: Bool

    public init() {}

    private var filteredMessages: [ChatMessage] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return chatManager.messages }
        return chatManager.messages.filter { msg in
            msg.content.lowercased().contains(query) ||
            msg.senderName.lowercased().contains(query) ||
            (msg.snippetLanguage?.lowercased().contains(query) == true)
        }
    }

    public var body: some View {
        ZStack {
            // 1. Ambient Liquid Glass Refraction Sheen
            LinearGradient(
                colors: [
                    Color.cyan.opacity(0.12),
                    Color.clear,
                    Color.purple.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // 2. Main Chat Interface
            VStack(spacing: 0) {
                // Header Toolbar
                chatHeaderView

                // Optional Search Bar
                if isSearchActive {
                    searchBarView
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Messages Feed
                messagesFeedView

                // Floating Liquid Glass Composer
                chatComposerView
            }
        }
        .frame(minWidth: 560, minHeight: 460)
        .confirmationDialog(
            "Clear entire chat history?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All Messages", role: .destructive) {
                chatManager.clearHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the chat history from your local session. This cannot be undone.")
        }
    }

    // MARK: - Header Bar

    private var chatHeaderView: some View {
        HStack(spacing: 12) {
            // Room Title and Presence Indicator
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 30, height: 30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                        )
                        .shadow(color: Color.accentColor.opacity(0.35), radius: 6, y: 1)

                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("Subnet Chat")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)

                        // Online peers status pill
                        let peerCount = chatManager.networkManager?.peers.count ?? 0
                        Button {
                            showPeersPopover.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(peerCount > 0 ? Color.green : Color.orange)
                                    .frame(width: 6, height: 6)

                                Text(peerCount > 0 ? "\(peerCount) online" : "Listening...")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showPeersPopover, arrowEdge: .bottom) {
                            peersPopoverView
                        }
                    }

                    Text("Zero-cloud P2P broadcast channel")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            Spacer()

            // Header Toolbar Actions
            HStack(spacing: 6) {
                // Search Toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSearchActive.toggle()
                        if !isSearchActive {
                            searchQuery = ""
                        } else {
                            isSearchFocused = true
                        }
                    }
                } label: {
                    Image(systemName: isSearchActive ? "magnifyingglass.circle.fill" : "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSearchActive ? .cyan : .white.opacity(0.8))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(isSearchActive ? 0.15 : 0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .help("Search messages (⌘F)")

                // Export Markdown
                Button {
                    exportChat()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .help("Export chat log as Markdown")

                // Clear History
                Button {
                    showClearConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .help("Clear chat history")
            }
        }
        .padding(.leading, 78) // Clear standard macOS window traffic lights
        .padding(.trailing, 16)
        .padding(.vertical, 10)
        .frame(height: 52)
        .background(Color.white.opacity(0.04))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.white.opacity(0.15)),
            alignment: .bottom
        )
    }

    // MARK: - Search Bar View

    private var searchBarView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))

            TextField("Filter messages by text, sender, or language...", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .focused($isSearchFocused)

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)

                Text("\(filteredMessages.count) found")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }

            Button("Done") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSearchActive = false
                    searchQuery = ""
                }
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.cyan)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.25))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.white.opacity(0.12)),
            alignment: .bottom
        )
    }

    // MARK: - Online Peers Popover View

    private var peersPopoverView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Discovered Peers")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Text("\(chatManager.networkManager?.peers.count ?? 0) active")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 2)

            Divider()

            let peers = chatManager.networkManager?.peers ?? []
            if peers.isEmpty {
                Text("No peers detected on local subnet yet.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 220, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(peers) { peer in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(peer.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                Text(peer.status)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                    }
                }
                .frame(width: 220)
            }
        }
        .padding(12)
    }

    // MARK: - Messages Feed

    private var messagesFeedView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if filteredMessages.isEmpty {
                    if !searchQuery.isEmpty {
                        searchEmptyStateView
                    } else {
                        emptyStateView
                    }
                } else {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(filteredMessages.enumerated()), id: \.element.id) { index, message in
                            let isLocal = isLocalMessage(message)
                            let previousMessage = index > 0 ? filteredMessages[index - 1] : nil
                            let showDateDivider = previousMessage == nil || !message.isSameDay(as: previousMessage!.timestamp)
                            let isConsecutive = previousMessage != nil && message.isConsecutive(after: previousMessage!)

                            VStack(spacing: 4) {
                                if showDateDivider {
                                    dateDividerView(dateString: message.relativeDateHeader)
                                        .padding(.top, index == 0 ? 8 : 16)
                                        .padding(.bottom, 6)
                                }

                                ChatMessageRow(
                                    message: message,
                                    isLocal: isLocal,
                                    isConsecutive: isConsecutive && !showDateDivider,
                                    onDelete: {
                                        chatManager.deleteMessage(id: message.id)
                                    }
                                )
                                .id(message.id)
                                .padding(.top, isConsecutive && !showDateDivider ? 1 : 10)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .onChange(of: chatManager.messages.count) { _, _ in
                if let last = chatManager.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let last = chatManager.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Date Divider

    private func dateDividerView(dateString: String) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 0.5)

            Text(dateString)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.22), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 3, y: 1)

            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 0.5)
        }
    }

    // MARK: - Empty States

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.25), Color.cyan.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 68, height: 68)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.25), lineWidth: 0.75)
                    )
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 2)

                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 4)

            Text("Subnet Chat Room")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Text("Broadcast messages and formatted code snippets directly to all discovered local devices over zero-cloud Bonjour.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
                .lineSpacing(2)

            // Quick suggestion chips
            HStack(spacing: 8) {
                quickPromptChip(label: "👋 Say Hello", prompt: "Hello everyone! 👋")
                quickPromptChip(label: "💻 Share Snippet", snippetMode: true)
                quickPasteClipboardChip()
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding()
    }

    private var searchEmptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30))
                .foregroundColor(.white.opacity(0.5))
                .padding(.bottom, 4)

            Text("No Messages Match \"\(searchQuery)\"")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            Button("Clear Search") {
                searchQuery = ""
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private func quickPromptChip(label: String, prompt: String = "", snippetMode: Bool = false) -> some View {
        Button {
            if snippetMode {
                isSnippetMode = true
                isInputFocused = true
            } else {
                inputText = prompt
                isInputFocused = true
            }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func quickPasteClipboardChip() -> some View {
        Button {
            if let string = NSPasteboard.general.string(forType: .string), !string.isEmpty {
                inputText = string
                if string.contains("\n") || string.contains("{") || string.contains("import") {
                    isSnippetMode = true
                }
                isInputFocused = true
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 10))
                Text("Paste Clipboard")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Composer Floating Liquid Glass Bar

    private var chatComposerView: some View {
        VStack(spacing: 0) {
            // Snippet Mode Header Toolbar
            if isSnippetMode {
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "curlybraces")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(selectedLanguage.badgeColor)

                        Text("Snippet Language:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))

                        Picker("", selection: $selectedLanguage) {
                            ForEach(SyntaxLanguage.allCases, id: \.self) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                    }

                    Spacer()

                    Text("Press ⌘Return to send")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))

                    Button {
                        isSnippetMode = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Exit Snippet Mode")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.35))
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 12, style: .continuous))
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color.white.opacity(0.18)),
                    alignment: .bottom
                )
            }

            // Input card
            HStack(alignment: .bottom, spacing: 8) {
                // Snippet Mode Toggle Button
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isSnippetMode.toggle()
                    }
                } label: {
                    Image(systemName: isSnippetMode ? "curlybraces.square.fill" : "curlybraces")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSnippetMode ? .cyan : .white.opacity(0.75))
                        .frame(width: 28, height: 28)
                        .background(isSnippetMode ? Color.cyan.opacity(0.2) : Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .help(isSnippetMode ? "Exit snippet mode" : "Format message as code snippet")

                // Expanding Text Field
                ZStack(alignment: .topLeading) {
                    if inputText.isEmpty {
                        Text(isSnippetMode ? "Paste or write code... (⌘Return to send)" : "Message subnet... (Return to send, ⇧Return for newline)")
                            .font(isSnippetMode ? .system(size: 12, design: .monospaced) : .system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 6)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $inputText)
                        .font(isSnippetMode ? .system(size: 12, design: .monospaced) : .system(size: 13))
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: isSnippetMode ? 72 : 32, maxHeight: 130)
                        .focused($isInputFocused)
                        .onKeyPress(.return, phases: .down) { press in
                            if isSnippetMode {
                                if press.modifiers.contains(.command) {
                                    sendMessage()
                                    return .handled
                                }
                                return .ignored
                            } else {
                                if press.modifiers.contains(.shift) || press.modifiers.contains(.option) {
                                    return .ignored
                                } else {
                                    sendMessage()
                                    return .handled
                                }
                            }
                        }
                }

                // Send Button
                Button {
                    sendMessage()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                canSend ?
                                LinearGradient(
                                    colors: [Color.cyan, Color.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.white.opacity(0.12), Color.white.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle().stroke(Color.white.opacity(canSend ? 0.45 : 0.15), lineWidth: 0.5)
                            )
                            .shadow(color: canSend ? Color.cyan.opacity(0.4) : Color.clear, radius: 6, y: 1)

                        Image(systemName: "arrow.up")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(canSend ? .black : .white.opacity(0.4))
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .help("Send broadcast message")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.35))
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: isSnippetMode ? 0 : 12,
                    bottomLeadingRadius: 12,
                    bottomTrailingRadius: 12,
                    topTrailingRadius: isSnippetMode ? 0 : 12,
                    style: .continuous
                )
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.40), Color.white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Helpers

    private func isLocalMessage(_ message: ChatMessage) -> Bool {
        let localId = chatManager.networkManager?.userProfile.peerID
        return message.senderId == localId || message.senderName == chatManager.networkManager?.userProfile.username
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        chatManager.sendMessage(
            content: text,
            isSnippet: isSnippetMode,
            snippetLanguage: isSnippetMode ? selectedLanguage.rawValue : nil
        )

        NSSound(named: "Tink")?.play()

        inputText = ""
        isSnippetMode = false
    }

    private func exportChat() {
        let markdown = chatManager.exportChatHistory()
        guard let data = markdown.data(using: .utf8) else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "LocalPing-Chat-\(Int(Date().timeIntervalSince1970)).md"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? data.write(to: url)
                NSSound(named: "Glass")?.play()
            }
        }
    }
}

// MARK: - Liquid Glass Message Row

struct ChatMessageRow: View {
    let message: ChatMessage
    let isLocal: Bool
    let isConsecutive: Bool
    let onDelete: () -> Void

    @State private var isHovered: Bool = false
    @State private var hasCopied: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isLocal {
                Spacer(minLength: 48)

                if isHovered {
                    hoverActionButtons
                        .transition(.opacity)
                }
            } else {
                if !isConsecutive {
                    Circle()
                        .fill(avatarGradient)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(message.avatarInitials)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                        )
                        .shadow(color: Color(hex: message.avatarColorHex).opacity(0.3), radius: 4, y: 1)
                } else {
                    Color.clear
                        .frame(width: 28, height: 28)
                }
            }

            VStack(alignment: isLocal ? .trailing : .leading, spacing: 3) {
                if !isConsecutive {
                    HStack(spacing: 6) {
                        if !isLocal {
                            Text(message.senderName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: message.avatarColorHex))
                        }

                        Text(message.formattedTime)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 2)
                }

                // Message Content (parsed segments into text bubbles and code snippet cards)
                VStack(alignment: isLocal ? .trailing : .leading, spacing: 4) {
                    ForEach(message.parsedSegments) { segment in
                        switch segment {
                        case .text(_, let text):
                            Text(LocalizedStringKey(text))
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                                .textSelection(.enabled)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(bubbleBackground)
                                .clipShape(bubbleShape)
                                .overlay(bubbleBorder)
                                .shadow(
                                    color: isLocal ? Color.cyan.opacity(0.25) : Color.black.opacity(0.25),
                                    radius: isLocal ? 6 : 4,
                                    y: 2
                                )

                        case .code(_, let code, let language):
                            CodeSnippetView(code: code, language: language)
                        }
                    }
                }
            }
            .contextMenu {
                Button {
                    copyMessageContent()
                } label: {
                    Label("Copy Message Text", systemImage: "doc.on.doc")
                }

                if message.isSnippet || message.parsedSegments.contains(where: { if case .code = $0 { return true } else { return false } }) {
                    Button {
                        copyOnlyCode()
                    } label: {
                        Label("Copy Code", systemImage: "curlybraces")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Message", systemImage: "trash")
                }
            }

            if !isLocal {
                if isHovered {
                    hoverActionButtons
                        .transition(.opacity)
                }

                Spacer(minLength: 48)
            }
        }
        .onHover { isHovered = $0 }
    }

    // MARK: - Liquid Glass Bubble Styling

    @ViewBuilder
    private var bubbleBackground: some View {
        if isLocal {
            // Translucent radiant cyan/blue liquid glass bubble
            LinearGradient(
                colors: [Color.cyan.opacity(0.85), Color.blue.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // Smoked frosted glass incoming bubble
            Color.white.opacity(0.08)
        }
    }

    private var bubbleShape: some Shape {
        UnevenRoundedRectangle(
            topLeadingRadius: 14,
            bottomLeadingRadius: isLocal ? 14 : (isConsecutive ? 6 : 3),
            bottomTrailingRadius: isLocal ? (isConsecutive ? 6 : 3) : 14,
            topTrailingRadius: 14,
            style: .continuous
        )
    }

    @ViewBuilder
    private var bubbleBorder: some View {
        bubbleShape
            .stroke(
                LinearGradient(
                    colors: isLocal ?
                        [Color.white.opacity(0.45), Color.white.opacity(0.15)] :
                        [Color.white.opacity(0.30), Color.white.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.5
            )
    }

    private var avatarGradient: LinearGradient {
        let base = Color(hex: message.avatarColorHex)
        return LinearGradient(
            colors: [base, base.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Hover Actions

    private var hoverActionButtons: some View {
        HStack(spacing: 4) {
            Button {
                copyMessageContent()
            } label: {
                Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(hasCopied ? .green : .white.opacity(0.8))
                    .frame(width: 22, height: 22)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .help("Copy text")

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 22, height: 22)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .help("Delete message")
        }
        .padding(.top, 2)
    }

    private func copyMessageContent() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
        withAnimation(.spring(response: 0.25)) {
            hasCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut) {
                hasCopied = false
            }
        }
    }

    private func copyOnlyCode() {
        var codeStrings: [String] = []
        for segment in message.parsedSegments {
            if case .code(_, let code, _) = segment {
                codeStrings.append(code)
            }
        }
        let joined = codeStrings.joined(separator: "\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(joined, forType: .string)
    }
}

// MARK: - Smoked Glass Syntax Code Snippet Card

struct CodeSnippetView: View {
    let code: String
    let language: String?

    @State private var hasCopied: Bool = false

    private var syntaxLanguage: SyntaxLanguage {
        SyntaxLanguage.match(language)
    }

    private var lines: [String] {
        code.components(separatedBy: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Snippet Glass Header Bar
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(syntaxLanguage.badgeColor)
                        .frame(width: 7, height: 7)

                    Text(syntaxLanguage.displayName.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }

                Text("•")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))

                Text("\(lines.count) \(lines.count == 1 ? "line" : "lines")")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                Spacer()

                // Copy Action Pill
                Button {
                    copyCode()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .medium))
                        Text(hasCopied ? "Copied" : "Copy")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(hasCopied ? .green : .white.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.40))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color.white.opacity(0.15)),
                alignment: .bottom
            )

            // Syntax-highlighted code editor body with line numbers
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.40))
                                .frame(minWidth: 20, alignment: .trailing)

                            highlightedLine(line, language: syntaxLanguage)
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(Color.black.opacity(0.30))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.30), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 8, y: 3)
        .frame(minWidth: 320, maxWidth: 520)
    }

    private func highlightedLine(_ line: String, language: SyntaxLanguage) -> Text {
        let tokens = SimpleSyntaxHighlighter.shared.highlightLine(line, language: language)
        guard !tokens.isEmpty else { return Text(line) }

        var result = Text("")
        for token in tokens {
            switch token.type {
            case .keyword:
                result = result + Text(token.text).foregroundColor(Color(red: 0.88, green: 0.45, blue: 0.88)).bold()
            case .type:
                result = result + Text(token.text).foregroundColor(Color(red: 0.45, green: 0.85, blue: 0.95)).bold()
            case .string:
                result = result + Text(token.text).foregroundColor(Color(red: 0.98, green: 0.55, blue: 0.40))
            case .number:
                result = result + Text(token.text).foregroundColor(Color(red: 0.95, green: 0.78, blue: 0.25))
            case .comment:
                result = result + Text(token.text).foregroundColor(Color.white.opacity(0.5)).italic()
            case .boolean:
                result = result + Text(token.text).foregroundColor(Color(red: 0.40, green: 0.70, blue: 1.0)).bold()
            case .plain:
                result = result + Text(token.text).foregroundColor(.white)
            }
        }
        return result
    }

    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        withAnimation(.spring(response: 0.25)) {
            hasCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut) {
                hasCopied = false
            }
        }
    }
}
