import AppKit
import SwiftUI

@MainActor
public final class ChatWindowController: NSWindowController, NSWindowDelegate {
    public static let shared = ChatWindowController()

    private var chatWindow: NSWindow?

    public init() {
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func showWindow(peerCount: Int) {
        if let existing = chatWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 140, y: 140, width: 800, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.identifier = NSUserInterfaceItemIdentifier("LocalPingChatWindow")
        window.title = "Subnet Chat"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 560, height: 460)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        let rootView = ChatRoomView()
        window.contentView = NSHostingView(rootView: rootView)

        self.chatWindow = window
        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        ChatRoomManager.shared.chatWindowDidClose()
    }
}
