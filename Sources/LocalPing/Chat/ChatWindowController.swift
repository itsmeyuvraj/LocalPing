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
            existing.title = "LocalPing Subnet Chat (\(peerCount) online)"
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 120, y: 120, width: 760, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.identifier = NSUserInterfaceItemIdentifier("LocalPingChatWindow")
        window.title = "LocalPing Subnet Chat"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        window.minSize = NSSize(width: 520, height: 420)
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
