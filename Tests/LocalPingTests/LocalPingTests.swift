import Testing
import Foundation
@testable import LocalPing

@Suite("LocalPing Protocol and Model Tests")
struct LocalPingTests {
    @Test("TransferHeader encodes and decodes JSON correctly")
    func testHeaderSerialization() throws {
        let header = TransferHeader(
            transferId: "test-uuid-1234",
            senderName: "Alice",
            payloadType: .file,
            fileName: "TestDoc.pdf",
            fileSize: 1048576,
            mimeType: "application/pdf"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(header)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TransferHeader.self, from: data)

        #expect(decoded.transferId == "test-uuid-1234")
        #expect(decoded.senderName == "Alice")
        #expect(decoded.payloadType == .file)
        #expect(decoded.fileName == "TestDoc.pdf")
        #expect(decoded.fileSize == 1048576)
    }

    @Test("TransferTask progress calculation")
    func testTaskProgress() {
        var task = TransferTask(
            id: "task-1",
            peerName: "Bob",
            direction: .outgoing,
            type: .file,
            fileName: "video.mov",
            fileSize: 1000,
            bytesTransferred: 500,
            state: .transferring(progress: 0.5)
        )

        #expect(task.progress == 0.5)
        task.bytesTransferred = 1000
        #expect(task.progress == 1.0)
    }

    @Test("AudioStream header encodes and decodes sampleRate and channels correctly")
    func testAudioStreamHeader() throws {
        let header = TransferHeader(
            transferId: "audio-stream-1",
            senderName: "Charlie",
            payloadType: .audioStream,
            fileName: "VoiceStream",
            fileSize: 0,
            mimeType: "audio/pcm",
            sampleRate: 16000.0,
            channels: 1
        )

        let data = try JSONEncoder().encode(header)
        let decoded = try JSONDecoder().decode(TransferHeader.self, from: data)

        #expect(decoded.payloadType == .audioStream)
        #expect(decoded.sampleRate == 16000.0)
        #expect(decoded.channels == 1)
    }

    @Test("ClipboardItem serializes and deserializes properly")
    func testClipboardItemSerialization() throws {
        let item = ClipboardItem(
            id: "clip-123",
            senderName: "Dana",
            content: "https://github.com/swiftlang/swift",
            timestamp: Date()
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(ClipboardItem.self, from: data)

        #expect(decoded.id == "clip-123")
        #expect(decoded.senderName == "Dana")
        #expect(decoded.content == "https://github.com/swiftlang/swift")
        #expect(decoded.preview == "https://github.com/swiftlang/swift")
    }

    @Test("CanvasStroke and CanvasAction serialize and deserialize correctly")
    func testCanvasActionSerialization() throws {
        let points = [
            CanvasPoint(x: 10.0, y: 20.0),
            CanvasPoint(x: 15.5, y: 25.5),
            CanvasPoint(x: 30.0, y: 50.0)
        ]
        let stroke = CanvasStroke(
            points: points,
            colorHex: "#00F0FF",
            lineWidth: 4.0,
            isEraser: false,
            authorName: "Alice"
        )
        let note = CanvasNote(
            x: 100.0,
            y: 150.0,
            text: "Brainstorming notes",
            colorHex: "#FFD60A",
            authorName: "Bob"
        )

        let strokeAction = CanvasAction.strokeAdded(stroke)
        let strokeData = try JSONEncoder().encode(strokeAction)
        let decodedStrokeAction = try JSONDecoder().decode(CanvasAction.self, from: strokeData)

        if case .strokeAdded(let decodedStroke) = decodedStrokeAction {
            #expect(decodedStroke.points.count == 3)
            #expect(decodedStroke.colorHex == "#00F0FF")
            #expect(decodedStroke.lineWidth == 4.0)
            #expect(decodedStroke.authorName == "Alice")
        } else {
            Issue.record("Expected .strokeAdded action")
        }

        let fullSyncAction = CanvasAction.fullSync(strokes: [stroke], notes: [note])
        let fullSyncData = try JSONEncoder().encode(fullSyncAction)
        let decodedFullSync = try JSONDecoder().decode(CanvasAction.self, from: fullSyncData)

        if case .fullSync(let decodedStrokes, let decodedNotes) = decodedFullSync {
            #expect(decodedStrokes.count == 1)
            #expect(decodedNotes.count == 1)
            #expect(decodedNotes.first?.text == "Brainstorming notes")
        } else {
            Issue.record("Expected .fullSync action")
        }
    }

    @Test("ChatMessage serializes correctly and parses code segments")
    func testChatMessageSerializationAndParsing() throws {
        let rawMessage = """
        Hey everyone, look at this Swift code:
        ```swift
        let ping = "LocalPing"
        print(ping)
        ```
        Let me know what you think!
        """

        let message = ChatMessage(
            senderId: "user-42",
            senderName: "Alice Walker",
            content: rawMessage,
            timestamp: Date(),
            isSnippet: false
        )

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)

        #expect(decoded.senderName == "Alice Walker")
        #expect(decoded.avatarInitials == "AW")
        #expect(decoded.avatarColorHex.hasPrefix("#"))

        let segments = decoded.parsedSegments
        #expect(segments.count == 3)

        if case .text(_, let text1) = segments[0] {
            #expect(text1.contains("Hey everyone"))
        } else {
            Issue.record("First segment should be text")
        }

        if case .code(_, let code, let lang) = segments[1] {
            #expect(lang == "swift")
            #expect(code.contains("let ping = \"LocalPing\""))
        } else {
            Issue.record("Second segment should be code")
        }

        if case .text(_, let text2) = segments[2] {
            #expect(text2.contains("Let me know"))
        } else {
            Issue.record("Third segment should be text")
        }
    }

    @Test("Syntax highlighting correctly classifies tokens")
    func testSyntaxHighlighting() {
        let highlighter = SimpleSyntaxHighlighter.shared
        let swiftLine = "import SwiftUI // Framework"
        let swiftTokens = highlighter.highlightLine(swiftLine, language: .swift)

        #expect(swiftTokens.contains { $0.text == "import" && $0.type == .keyword })
        #expect(swiftTokens.contains { $0.text == "SwiftUI" && $0.type == .type })
        #expect(swiftTokens.contains { $0.type == .comment })

        let pythonLine = "def calculate_sum(val = 42):"
        let pythonTokens = highlighter.highlightLine(pythonLine, language: .python)
        #expect(pythonTokens.contains { $0.text == "def" && $0.type == .keyword })
        #expect(pythonTokens.contains { $0.text == "42" && $0.type == .number })
    }

    @Test("ChatMessage consecutive grouping and date calculation")
    func testChatMessageClusteringAndDates() {
        let now = Date()
        let msg1 = ChatMessage(
            senderId: "user-1",
            senderName: "Alice",
            content: "First message",
            timestamp: now
        )

        let msg2 = ChatMessage(
            senderId: "user-1",
            senderName: "Alice",
            content: "Second message",
            timestamp: now.addingTimeInterval(30) // 30s later
        )

        let msg3 = ChatMessage(
            senderId: "user-2",
            senderName: "Bob",
            content: "Reply from Bob",
            timestamp: now.addingTimeInterval(45)
        )

        let msg4 = ChatMessage(
            senderId: "user-1",
            senderName: "Alice",
            content: "Later message",
            timestamp: now.addingTimeInterval(300) // 5 mins later
        )

        #expect(msg2.isConsecutive(after: msg1))
        #expect(!msg3.isConsecutive(after: msg2)) // Different sender
        #expect(!msg4.isConsecutive(after: msg1)) // > 3 mins

        #expect(msg1.relativeDateHeader == "Today")
        #expect(msg1.isSameDay(as: msg2.timestamp))
    }
}

