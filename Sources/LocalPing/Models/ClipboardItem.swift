import Foundation

public struct ClipboardItem: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let senderName: String
    public let content: String
    public let timestamp: Date

    public init(
        id: String = UUID().uuidString,
        senderName: String,
        content: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.senderName = senderName
        self.content = content
        self.timestamp = timestamp
    }

    public var preview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 120 {
            return String(trimmed.prefix(120)) + "..."
        }
        return trimmed
    }

    public var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}
