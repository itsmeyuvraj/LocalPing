import Foundation

public enum ChatContentSegment: Identifiable, Equatable {
    case text(id: String, content: String)
    case code(id: String, code: String, language: String?)

    public var id: String {
        switch self {
        case .text(let id, _): return id
        case .code(let id, _, _): return id
        }
    }
}

public struct ChatMessage: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let senderId: String
    public let senderName: String
    public let content: String
    public let timestamp: Date
    public let isSnippet: Bool
    public let snippetLanguage: String?

    public init(
        id: UUID = UUID(),
        senderId: String,
        senderName: String,
        content: String,
        timestamp: Date = Date(),
        isSnippet: Bool = false,
        snippetLanguage: String? = nil
    ) {
        self.id = id
        self.senderId = senderId
        self.senderName = senderName
        self.content = content
        self.timestamp = timestamp
        self.isSnippet = isSnippet
        self.snippetLanguage = snippetLanguage
    }

    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    public var formattedFullDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: timestamp)
    }

    public var relativeDateHeader: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(timestamp) {
            return "Today"
        } else if calendar.isDateInYesterday(timestamp) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMMM d"
            return formatter.string(from: timestamp)
        }
    }

    public func isSameDay(as date: Date) -> Bool {
        Calendar.current.isDate(timestamp, inSameDayAs: date)
    }

    public func isConsecutive(after previous: ChatMessage) -> Bool {
        guard senderId == previous.senderId && senderName == previous.senderName else {
            return false
        }
        // Group if sent within 3 minutes (180 seconds)
        let diff = abs(timestamp.timeIntervalSince(previous.timestamp))
        return diff < 180 && isSameDay(as: previous.timestamp)
    }

    public var avatarInitials: String {
        let trimmed = senderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        } else if let first = parts.first, !first.isEmpty {
            return String(first.prefix(2)).uppercased()
        }
        return "LP"
    }

    public var avatarColorHex: String {
        let palette = [
            "#007AFF", // System Blue
            "#5856D6", // System Indigo
            "#AF52DE", // System Purple
            "#FF2D55", // System Pink
            "#FF9500", // System Orange
            "#34C759", // System Green
            "#00C7BE", // System Teal
            "#32ADE6"  // System Sky
        ]
        var hash = 0
        for byte in senderName.utf8 {
            hash = (hash &* 31) &+ Int(byte)
        }
        let index = abs(hash) % palette.count
        return palette[index]
    }

    /// Parses the message text into alternating text and fenced code block segments
    public var parsedSegments: [ChatContentSegment] {
        if isSnippet {
            return [.code(id: "\(id.uuidString)-0", code: content, language: snippetLanguage)]
        }

        var segments: [ChatContentSegment] = []
        let raw = content

        // Regex pattern to extract ```[lang]?\n[code]```
        let pattern = "```([a-zA-Z0-9_+-]*)\\n?([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [.text(id: "\(id.uuidString)-0", content: content)]
        }

        let nsString = raw as NSString
        let matches = regex.matches(in: raw, options: [], range: NSRange(location: 0, length: nsString.length))

        var currentIndex = 0
        var segmentCounter = 0

        for match in matches {
            // Text before the code block
            let textRange = NSRange(location: currentIndex, length: match.range.location - currentIndex)
            if textRange.length > 0 {
                let textPart = nsString.substring(with: textRange).trimmingCharacters(in: .whitespacesAndNewlines)
                if !textPart.isEmpty {
                    segments.append(.text(id: "\(id.uuidString)-\(segmentCounter)", content: textPart))
                    segmentCounter += 1
                }
            }

            // Code block content & optional language
            let langRange = match.range(at: 1)
            var language: String? = nil
            if langRange.location != NSNotFound && langRange.length > 0 {
                language = nsString.substring(with: langRange).trimmingCharacters(in: .whitespacesAndNewlines)
                if language?.isEmpty == true { language = nil }
            }

            let codeRange = match.range(at: 2)
            let codeContent = nsString.substring(with: codeRange).trimmingCharacters(in: .whitespacesAndNewlines)

            segments.append(.code(
                id: "\(id.uuidString)-\(segmentCounter)",
                code: codeContent,
                language: language ?? snippetLanguage
            ))
            segmentCounter += 1

            currentIndex = match.range.location + match.range.length
        }

        // Remaining text after last code block
        if currentIndex < nsString.length {
            let remaining = nsString.substring(from: currentIndex).trimmingCharacters(in: .whitespacesAndNewlines)
            if !remaining.isEmpty {
                segments.append(.text(id: "\(id.uuidString)-\(segmentCounter)", content: remaining))
            }
        }

        if segments.isEmpty {
            return [.text(id: "\(id.uuidString)-0", content: content)]
        }

        return segments
    }
}
