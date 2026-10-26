import AppKit
import SwiftUI

@MainActor
public final class CanvasWindowController: NSWindowController, NSWindowDelegate {
    public static let shared = CanvasWindowController()

    private var canvasWindow: NSWindow?

    public init() {
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func showWindow(peerName: String) {
        if let existing = canvasWindow {
            existing.title = "LocalPing Shared Canvas — \(peerName)"
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 920, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.identifier = NSUserInterfaceItemIdentifier("LocalPingCanvasWindow")
        window.title = "LocalPing Shared Canvas — \(peerName)"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        window.minSize = NSSize(width: 720, height: 500)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        let rootView = SharedCanvasView()
        window.contentView = NSHostingView(rootView: rootView)

        self.canvasWindow = window
        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        SharedCanvasManager.shared.canvasWindowDidClose()
    }
}
