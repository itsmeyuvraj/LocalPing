import SwiftUI
import AppKit

public struct ChatRoomView: View {
    @State private var chatManager = ChatRoomManager.shared
    @State private var inputText: String = ""
    @State private var isSnippetMode: Bool = false
    @State private var selectedLanguage: String = "swift"
    @State private var showClearConfirmation: Bool = false
    @FocusState private var isInputFocused: Bool

    private let supportedLanguages = ["swift", "json", "python", "bash", "markdown", "javascript", "html", "sql"]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Header Toolbar
            chatHeaderView

            Divider()
                .background(Color.white.opacity(0.1))

            // 2. Scrollable Messages Feed
            messagesFeedView

            Divider()
                .background(Color.white.opacity(0.1))

            // 3. Bottom Input Bar with Snippet formatting controls
            chatInputBarView
        }
        .frame(minWidth: 520, minHeight: 420)
        .background(Color(red: 0.11, green: 0.11, blue: 0.13))
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
            Text("This will permanently remove the local chat history from your session.")
        }
    }

    // MARK: - Header View

    private var chatHeaderView: some View {
        HStack(spacing: 12) {
            // Icon & Room Name
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.cyan)

                Text("Local Subnet Chat")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }

            // Online peers count badge
            let peerCount = chatManager.networkManager?.peers.count ?? 0
            HStack(spacing: 5) {
                Circle()
                    .fill(peerCount > 0 ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)

                Text(peerCount > 0 ? "\(peerCount) online" : "Listening...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())

            Spacer()

            // Export to Markdown button
            Button {
                exportChat()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Export chat log as Markdown")

            // Clear history button
            Button {
                showClearConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Clear chat history")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.13, green: 0.13, blue: 0.16))
    }

    // MARK: - Messages Feed

    private var messagesFeedView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if chatManager.messages.isEmpty {
                    emptyStateView
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(chatManager.messages) { message in
                            ChatMessageRow(
                                message: message,
                                isLocal: isLocalMessage(message)
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .onChange(of: chatManager.messages.count) { _, _ in
                if let last = chatManager.messages.last {
                    withAnimation(.easeOut(duration: 0.25)) {
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

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "message.and.waveform")
                .font(.system(size: 38))
                .foregroundColor(.cyan.opacity(0.6))
                .padding(.bottom, 4)

            Text("No Messages Yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            Text("Messages and code snippets sent here will broadcast to all LocalPing peers on your local network simultaneously.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .padding()
    }

    // MARK: - Input Bar

    private var chatInputBarView: some View {
        VStack(spacing: 8) {
            // Optional snippet language selector bar
            if isSnippetMode {
                HStack(spacing: 8) {
                    Image(systemName: "curlybraces")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.cyan)

                    Text("Code Snippet Mode:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)

                    Picker("", selection: $selectedLanguage) {
                        ForEach(supportedLanguages, id: \.self) { lang in
                            Text(lang.uppercased()).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 110)

                    Spacer()

                    Button {
                        isSnippetMode = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.cyan.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Input field and send button
            HStack(alignment: .bottom, spacing: 8) {
                // Snippet Mode Toggle Button
                Button {
                    isSnippetMode.toggle()
                } label: {
                    Image(systemName: isSnippetMode ? "curlybraces.square.fill" : "curlybraces")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSnippetMode ? .cyan : .secondary)
                        .padding(7)
                        .background(Color.white.opacity(isSnippetMode ? 0.12 : 0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .help(isSnippetMode ? "Exit snippet mode" : "Format as code snippet")

                // Multiline / dynamic text field
                TextEditor(text: $inputText)
                    .font(isSnippetMode ? .system(size: 12, design: .monospaced) : .system(size: 13))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(minHeight: isSnippetMode ? 70 : 36, maxHeight: 120)
                    .focused($isInputFocused)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if inputText.isEmpty {
                            Text(isSnippetMode ? "Paste or write code snippet..." : "Type a message... (Return to send, Shift+Return for newline)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 9)
                                .allowsHitTesting(false)
                        }
                    }
                    .onKeyPress(.return, phases: .down) { press in
                        if press.modifiers.contains(.shift) {
                            return .ignored
                        } else {
                            sendMessage()
                            return .handled
                        }
                    }

                // Send Button
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary.opacity(0.4) : .cyan)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Send message to subnet")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.13, green: 0.13, blue: 0.16))
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
            snippetLanguage: isSnippetMode ? selectedLanguage : nil
        )

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

// MARK: - Message Row

struct ChatMessageRow: View {
    let message: ChatMessage
    let isLocal: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isLocal {
                Spacer(minLength: 40)
            } else {
                // Peer Avatar
                Circle()
                    .fill(Color(hex: message.avatarColorHex))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text(message.avatarInitials)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                    )
            }

            VStack(alignment: isLocal ? .trailing : .leading, spacing: 4) {
                // Sender name and timestamp
                HStack(spacing: 6) {
                    if !isLocal {
                        Text(message.senderName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: message.avatarColorHex))
                    }

                    Text(message.formattedTime)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                // Message bubble containing text and/or code snippets
                VStack(alignment: isLocal ? .trailing : .leading, spacing: 6) {
                    ForEach(message.parsedSegments) { segment in
                        switch segment {
                        case .text(_, let text):
                            Text(LocalizedStringKey(text))
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                                .textSelection(.enabled)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    isLocal ?
                                    Color.cyan.opacity(0.85) :
                                    Color(red: 0.18, green: 0.18, blue: 0.22)
                                )
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 14)
                                )

                        case .code(_, let code, let language):
                            CodeSnippetView(code: code, language: language)
                        }
                    }
                }
            }

            if !isLocal {
                Spacer(minLength: 40)
            }
        }
    }
}

// MARK: - Syntax Code Snippet Card

struct CodeSnippetView: View {
    let code: String
    let language: String?

    @State private var hasCopied: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Snippet header bar
            HStack(spacing: 8) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.cyan)

                Text((language ?? "CODE").uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    copyCode()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .medium))
                        Text(hasCopied ? "Copied" : "Copy")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(hasCopied ? .green : .secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(red: 0.14, green: 0.14, blue: 0.17))

            // Monospaced code text
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(red: 0.90, green: 0.92, blue: 0.95))
                    .padding(10)
                    .textSelection(.enabled)
            }
        }
        .background(Color(red: 0.10, green: 0.10, blue: 0.13))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .frame(maxWidth: 420)
    }

    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        withAnimation(.spring(response: 0.3)) {
            hasCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut) {
                hasCopied = false
            }
        }
    }
}
