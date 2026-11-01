import AppKit
import SwiftUI
import Observation

// Custom hosting controller that enables first-click mouse activation
final class FirstMouseHostingController<Content: View>: NSHostingController<Content> {
    override func loadView() {
        let hostingView = FirstMouseHostingView(rootView: rootView)
        self.view = hostingView
    }
}

final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

@MainActor
@Observable
public final class MenuController: NSObject {
    @ObservationIgnored private var statusItem: NSStatusItem!
    @ObservationIgnored private var popover: NSPopover!
    @ObservationIgnored public let networkManager: NetworkManager

    public var isPinned: Bool = true {
        didSet {
            updateEventMonitor()
        }
    }

    @ObservationIgnored private var globalEventMonitor: Any?

    public init(networkManager: NetworkManager) {
        self.networkManager = networkManager
        super.init()

        setupStatusItem()
        setupPopover()
        observeState()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        button.image = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: "LocalPing")
        button.action = #selector(togglePopover(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 480)
        // .applicationDefined keeps popover open while clicking Finder to drag files!
        popover.behavior = .applicationDefined
        popover.animates = false

        let isPinnedBinding = Binding<Bool>(
            get: { self.isPinned },
            set: { self.isPinned = $0 }
        )

        let rootView = ContentView(
            networkManager: networkManager,
            isPinned: isPinnedBinding,
            onClose: { [weak self] in
                self?.closePopover()
            }
        )
        popover.contentViewController = FirstMouseHostingController(rootView: rootView)
    }

    private func observeState() {
        withObservationTracking {
            let peerCount = networkManager.peers.count
            let hasTransfers = !networkManager.transferManager.activeTransfers.isEmpty
            updateStatusItem(peerCount: peerCount, hasTransfers: hasTransfers)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeState()
            }
        }
    }

    private func updateStatusItem(peerCount: Int, hasTransfers: Bool) {
        guard let button = statusItem.button else { return }

        let config: NSImage.SymbolConfiguration
        let symbolName: String

        if hasTransfers {
            symbolName = "arrow.up.and.down.circle.fill"
            config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            button.title = ""
        } else if peerCount > 0 {
            symbolName = "antenna.radiowaves.left.and.right"
            config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            button.title = " \(peerCount)"
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        } else {
            symbolName = "antenna.radiowaves.left.and.right"
            config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            button.title = ""
        }

        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "LocalPing")?
            .withSymbolConfiguration(config)
    }

    public func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // Float above Finder windows so user can easily drag files into it
        if let window = popover.contentViewController?.view.window {
            window.level = .floating
            window.makeKey()
        }

        updateEventMonitor()
    }

    public func closePopover() {
        popover.close()
        removeEventMonitor()
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func updateEventMonitor() {
        removeEventMonitor()
        guard popover.isShown, !isPinned else { return }

        // If not pinned, close on outside clicks
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.popover.isShown, !self.isPinned else { return }
            Task { @MainActor in
                self.closePopover()
            }
        }
    }

    private func removeEventMonitor() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
    }
}
