import Foundation
import Network

public struct Peer: Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var status: String
    public var endpoint: NWEndpoint
    public var lastSeen: Date
    public var resolvedAddress: String?

    public init(
        id: String,
        name: String,
        status: String = "Available",
        endpoint: NWEndpoint,
        lastSeen: Date = Date(),
        resolvedAddress: String? = nil
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.endpoint = endpoint
        self.lastSeen = lastSeen
        self.resolvedAddress = resolvedAddress
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Peer, rhs: Peer) -> Bool {
        lhs.id == rhs.id
    }
}
