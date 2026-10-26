import Foundation
import CoreGraphics

public struct CanvasPoint: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public init(_ cgPoint: CGPoint) {
        self.x = Double(cgPoint.x)
        self.y = Double(cgPoint.y)
    }

    public var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }

    public func distance(to other: CanvasPoint) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return (dx * dx + dy * dy).squareRoot()
    }
}

public enum CanvasTool: String, CaseIterable, Identifiable, Codable, Sendable {
    case pen
    case marker
    case eraser
    case note

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .pen: return "Pen"
        case .marker: return "Marker"
        case .eraser: return "Eraser"
        case .note: return "Sticky Note"
        }
    }

    public var iconName: String {
        switch self {
        case .pen: return "pencil.tip"
        case .marker: return "highlighter"
        case .eraser: return "eraser.fill"
        case .note: return "note.text.badge.plus"
        }
    }
}

public struct CanvasStroke: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var points: [CanvasPoint]
    public var colorHex: String
    public var lineWidth: CGFloat
    public var isEraser: Bool
    public var authorName: String
    public var timestamp: Date

    public init(
        id: UUID = UUID(),
        points: [CanvasPoint],
        colorHex: String,
        lineWidth: CGFloat = 3.0,
        isEraser: Bool = false,
        authorName: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.points = points
        self.colorHex = colorHex
        self.lineWidth = lineWidth
        self.isEraser = isEraser
        self.authorName = authorName
        self.timestamp = timestamp
    }
}

public struct CanvasNote: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var x: Double
    public var y: Double
    public var text: String
    public var colorHex: String
    public var authorName: String
    public var timestamp: Date

    public init(
        id: UUID = UUID(),
        x: Double,
        y: Double,
        text: String = "",
        colorHex: String = "#FFD60A",
        authorName: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.x = x
        self.y = y
        self.text = text
        self.colorHex = colorHex
        self.authorName = authorName
        self.timestamp = timestamp
    }

    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

public enum CanvasAction: Codable, Sendable, Equatable {
    case strokeAdded(CanvasStroke)
    case noteAdded(CanvasNote)
    case noteUpdated(CanvasNote)
    case noteDeleted(id: UUID)
    case canvasCleared
    case syncRequest
    case fullSync(strokes: [CanvasStroke], notes: [CanvasNote])
}
