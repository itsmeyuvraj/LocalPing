import Foundation

@MainActor
@Observable
public final class UserProfile {
    private let kPeerID = "localping.user.peerId"
    private let kUsername = "localping.user.username"
    private let kStatus = "localping.user.status"

    public var peerID: String {
        didSet { UserDefaults.standard.set(peerID, forKey: kPeerID) }
    }

    public var username: String {
        didSet { UserDefaults.standard.set(username, forKey: kUsername) }
    }

    public var status: String {
        didSet { UserDefaults.standard.set(status, forKey: kStatus) }
    }

    public static let statusPresets: [String] = [
        "🟢 Available",
        "🚀 In the Zone",
        "📦 Open for Drops",
        "☕️ AFK / Coffee",
        "🎧 Focus Mode"
    ]

    public init() {
        if let savedID = UserDefaults.standard.string(forKey: kPeerID), !savedID.isEmpty {
            self.peerID = savedID
        } else {
            let newID = UUID().uuidString
            UserDefaults.standard.set(newID, forKey: kPeerID)
            self.peerID = newID
        }

        if let savedName = UserDefaults.standard.string(forKey: kUsername), !savedName.isEmpty {
            self.username = savedName
        } else {
            let defaultName = NSFullUserName().isEmpty ? (Host.current().localizedName ?? "LocalPing User") : NSFullUserName()
            self.username = defaultName
            UserDefaults.standard.set(defaultName, forKey: kUsername)
        }

        if let savedStatus = UserDefaults.standard.string(forKey: kStatus), !savedStatus.isEmpty {
            self.status = savedStatus
        } else {
            let defaultStatus = "🟢 Available"
            self.status = defaultStatus
            UserDefaults.standard.set(defaultStatus, forKey: kStatus)
        }
    }
}
