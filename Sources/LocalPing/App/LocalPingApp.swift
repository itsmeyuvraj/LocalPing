import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuController: MenuController?
    private var networkManager: NetworkManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent Dock icon from ever appearing even if Info.plist is omitted during dev builds
        NSApp.setActivationPolicy(.accessory)
        closeExtraneousWindows()

        let profile = UserProfile()
        let transfers = TransferManager()
        let network = NetworkManager(userProfile: profile, transferManager: transfers)

        self.networkManager = network
        self.menuController = MenuController(networkManager: network)

        network.start()

        if CommandLine.arguments.contains("--open-chat") {
            ChatRoomManager.shared.openChatWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        networkManager?.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        ChatRoomManager.shared.openChatWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func closeExtraneousWindows() {
        for window in NSApp.windows {
            if window.className != "_NSPopoverWindow" && window.className != "NSPopoverWindow" {
                window.orderOut(nil)
                window.close()
            }
        }
    }

    // Suppress any accidental attempts by SwiftUI or macOS to show preferences or settings
    @objc func showSettingsWindow(_ sender: Any?) {}
    @objc func showPreferencesWindow(_ sender: Any?) {}
}

@main
struct LocalPingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
