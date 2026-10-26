import Foundation
import SwiftUI
import AppKit
import Network
import Observation

@MainActor
@Observable
public final class SharedCanvasManager: @unchecked Sendable {
    public static let shared = SharedCanvasManager()

    // MARK: - State
    public private(set) var strokes: [CanvasStroke] = []
    public private(set) var notes: [CanvasNote] = []

    public var selectedTool: CanvasTool = .pen
    public var selectedColorHex: String = "#00F0FF"
    public var selectedLineWidth: CGFloat = 3.0

    public private(set) var activePeer: Peer? = nil
    public var localUserName: String = "You"
    public private(set) var isConnectedWithPeer: Bool = false
    public private(set) var isWindowVisible: Bool = false

    @ObservationIgnored
    public weak var networkManager: NetworkManager?

    // Color choices for UI palette
    public static let defaultColors: [String] = [
        "#00F0FF", // Cyan
        "#BF5AF2", // Purple
        "#FF2D55", // Pink
        "#FFD60A", // Electric Yellow
        "#30D158", // Emerald Green
        "#FFFFFF", // White
        "#FF9F0A"  // Orange
    ]

    private init() {}

    // MARK: - Canvas Window Controls

    public func openCanvas(with peer: Peer, localUserName: String) {
        self.activePeer = peer
        self.localUserName = localUserName
        self.isConnectedWithPeer = true
        self.isWindowVisible = true

        CanvasWindowController.shared.showWindow(peerName: peer.name)

        // Request state synchronization from the peer
        sendActionToActivePeer(.syncRequest)
    }

    public func openLocalCanvas(localUserName: String) {
        self.localUserName = localUserName
        self.activePeer = nil
        self.isConnectedWithPeer = false
        self.isWindowVisible = true

        CanvasWindowController.shared.showWindow(peerName: "Local Workspace")
    }

    public func canvasWindowDidClose() {
        self.isWindowVisible = false
    }

    // MARK: - Local Drawing Actions

    public func addStroke(_ stroke: CanvasStroke) {
        strokes.append(stroke)
        sendActionToActivePeer(.strokeAdded(stroke))
    }

    public func addNote(at point: CGPoint) {
        let note = CanvasNote(
            x: Double(point.x),
            y: Double(point.y),
            text: "New Note",
            colorHex: selectedColorHex,
            authorName: localUserName
        )
        notes.append(note)
        sendActionToActivePeer(.noteAdded(note))
    }

    public func updateNote(_ note: CanvasNote) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
            sendActionToActivePeer(.noteUpdated(note))
        }
    }

    public func deleteNote(id: UUID) {
        notes.removeAll(where: { $0.id == id })
        sendActionToActivePeer(.noteDeleted(id: id))
    }

    public func undo() {
        // Remove the last stroke authored by the local user, or simply the last stroke
        if let lastLocalIndex = strokes.lastIndex(where: { $0.authorName == localUserName }) {
            strokes.remove(at: lastLocalIndex)
            // Broadcast full sync or clear+rebuild
            sendActionToActivePeer(.fullSync(strokes: strokes, notes: notes))
        } else if !strokes.isEmpty {
            strokes.removeLast()
            sendActionToActivePeer(.fullSync(strokes: strokes, notes: notes))
        }
    }

    public func clearCanvas() {
        strokes.removeAll()
        notes.removeAll()
        sendActionToActivePeer(.canvasCleared)
    }

    // MARK: - Network Dispatcher

    private func sendActionToActivePeer(_ action: CanvasAction) {
        guard let peer = activePeer, let network = networkManager else { return }

        network.transferManager.sendCanvasAction(
            action,
            to: peer.endpoint,
            peerName: peer.name,
            localSenderName: localUserName
        )
    }

    // MARK: - Incoming Network Action Handler

    public func handleIncomingAction(
        _ action: CanvasAction,
        fromPeer senderName: String,
        peerEndpoint: NWEndpoint?
    ) {
        // If window is not currently open, automatically open it to accept incoming collaboration
        if !isWindowVisible {
            let matchingPeer = networkManager?.peers.first(where: { $0.name == senderName })
            if let matched = matchingPeer {
                self.activePeer = matched
                self.isConnectedWithPeer = true
            } else if let endpoint = peerEndpoint {
                let tempPeer = Peer(id: UUID().uuidString, name: senderName, endpoint: endpoint)
                self.activePeer = tempPeer
                self.isConnectedWithPeer = true
            }
            self.isWindowVisible = true
            CanvasWindowController.shared.showWindow(peerName: senderName)
            NSSound(named: "Pop")?.play()
        }

        switch action {
        case .strokeAdded(let stroke):
            strokes.append(stroke)

        case .noteAdded(let note):
            notes.append(note)

        case .noteUpdated(let note):
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index] = note
            } else {
                notes.append(note)
            }

        case .noteDeleted(let id):
            notes.removeAll(where: { $0.id == id })

        case .canvasCleared:
            strokes.removeAll()
            notes.removeAll()

        case .syncRequest:
            // Peer asked for our current canvas state, reply with fullSync
            sendActionToActivePeer(.fullSync(strokes: strokes, notes: notes))

        case .fullSync(let remoteStrokes, let remoteNotes):
            // Replace with received canonical state
            self.strokes = remoteStrokes
            self.notes = remoteNotes
        }
    }

    // MARK: - Export Helpers

    public func renderToPNG(canvasSize: CGSize) -> Data? {
        let targetSize = CGSize(width: max(800, canvasSize.width), height: max(600, canvasSize.height))
        let image = NSImage(size: targetSize)
        image.lockFocus()
        defer { image.unlockFocus() }

        guard let context = NSGraphicsContext.current?.cgContext else { return nil }

        // 1. Draw rich dark slate background
        context.setFillColor(CGColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0))
        context.fill(CGRect(origin: .zero, size: targetSize))

        // 2. Draw subtle grid dots
        context.setFillColor(CGColor(gray: 0.35, alpha: 0.35))
        let dotSpacing: CGFloat = 28.0
        for x in stride(from: CGFloat(20), to: targetSize.width, by: dotSpacing) {
            for y in stride(from: CGFloat(20), to: targetSize.height, by: dotSpacing) {
                context.fillEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
            }
        }

        // 3. Render strokes
        for stroke in strokes {
            guard let first = stroke.points.first else { continue }
            let path = CGMutablePath()
            path.move(to: first.cgPoint)
            for point in stroke.points.dropFirst() {
                path.addLine(to: point.cgPoint)
            }

            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setLineWidth(stroke.lineWidth)

            if stroke.isEraser {
                context.setBlendMode(.clear)
                context.addPath(path)
                context.strokePath()
                context.setBlendMode(.normal)
            } else {
                let strokeColor = NSColor(hex: stroke.colorHex) ?? .white
                context.setStrokeColor(strokeColor.cgColor)
                context.addPath(path)
                context.strokePath()
            }
        }

        // 4. Render notes
        for note in notes {
            let noteRect = CGRect(x: note.x, y: note.y, width: 220, height: 130)
            let noteBgColor = CGColor(red: 0.16, green: 0.16, blue: 0.20, alpha: 0.96)
            context.setFillColor(noteBgColor)
            let roundedPath = CGPath(roundedRect: noteRect, cornerWidth: 10, cornerHeight: 10, transform: nil)
            context.addPath(roundedPath)
            context.fillPath()

            // Accent bar
            let accentColor = NSColor(hex: note.colorHex) ?? .systemYellow
            let accentRect = CGRect(x: note.x, y: note.y + 125, width: 220, height: 5)
            context.setFillColor(accentColor.cgColor)
            context.fill(accentRect)

            // Header text (Author + Time)
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let headerString = "\(note.authorName) • \(note.formattedTime)"
            (headerString as NSString).draw(at: CGPoint(x: note.x + 12, y: note.y + 105), withAttributes: headerAttrs)

            // Note body
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.white
            ]
            let bodyRect = CGRect(x: note.x + 12, y: note.y + 12, width: 196, height: 85)
            (note.text as NSString).draw(in: bodyRect, withAttributes: bodyAttrs)
        }

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            return nil
        }
        return png
    }

    public func generateMarkdownSummary() -> String {
        let peerDesc = activePeer?.name ?? "Solo Workspace"
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateString = formatter.string(from: Date())

        var md = """
        # LocalPing Collaborative Canvas Notes
        **Peer Collaboration:** \(peerDesc)  
        **Generated:** \(dateString)  
        **Total Notes:** \(notes.count)  
        **Total Drawing Strokes:** \(strokes.count)  

        ---

        ## Canvas Sticky Notes

        """

        if notes.isEmpty {
            md += "\n*No sticky notes created during this session.*\n"
        } else {
            for (idx, note) in notes.enumerated() {
                md += """
                ### \(idx + 1). Note by \(note.authorName) (\(note.formattedTime))
                > \(note.text.replacingOccurrences(of: "\n", with: "\n> "))

                """
            }
        }

        md += """

        ---
        ## Drawing Overview
        - Total freehand strokes: \(strokes.count)
        - Authors participating: \(Set(strokes.map(\.authorName)).joined(separator: ", "))

        *Exported from LocalPing Shared Canvas.*
        """

        return md
    }

    public func savePNGWithPanel(canvasSize: CGSize) {
        guard let data = renderToPNG(canvasSize: canvasSize) else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true
        let peerSuffix = (activePeer?.name ?? "Session").replacingOccurrences(of: " ", with: "-")
        savePanel.nameFieldStringValue = "Canvas-\(peerSuffix)-\(Int(Date().timeIntervalSince1970)).png"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? data.write(to: url)
                NSSound(named: "Glass")?.play()
            }
        }
    }

    public func saveMarkdownWithPanel() {
        let md = generateMarkdownSummary()
        guard let data = md.data(using: .utf8) else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.canCreateDirectories = true
        let peerSuffix = (activePeer?.name ?? "Session").replacingOccurrences(of: " ", with: "-")
        savePanel.nameFieldStringValue = "Canvas-Notes-\(peerSuffix)-\(Int(Date().timeIntervalSince1970)).md"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? data.write(to: url)
                NSSound(named: "Glass")?.play()
            }
        }
    }

    public func quickSaveBothToDownloads(canvasSize: CGSize) {
        let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            .appendingPathComponent("LocalPing")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let timestamp = Int(Date().timeIntervalSince1970)
        let peerSuffix = (activePeer?.name ?? "Session").replacingOccurrences(of: " ", with: "-")

        // 1. Save PNG
        if let pngData = renderToPNG(canvasSize: canvasSize) {
            let pngURL = folder.appendingPathComponent("Canvas-\(peerSuffix)-\(timestamp).png")
            try? pngData.write(to: pngURL)
        }

        // 2. Save Markdown
        let md = generateMarkdownSummary()
        if let mdData = md.data(using: .utf8) {
            let mdURL = folder.appendingPathComponent("Canvas-Notes-\(peerSuffix)-\(timestamp).md")
            try? mdData.write(to: mdURL)
        }

        NSSound(named: "Glass")?.play()
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }
}

// MARK: - Color Hex Extensions

extension NSColor {
    convenience init?(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanHex.hasPrefix("#") {
            cleanHex.removeFirst()
        }

        guard cleanHex.count == 6, let rgbValue = UInt64(cleanHex, radix: 16) else {
            return nil
        }

        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

extension Color {
    init(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanHex.hasPrefix("#") {
            cleanHex.removeFirst()
        }

        guard cleanHex.count == 6, let rgbValue = UInt64(cleanHex, radix: 16) else {
            self = .primary
            return
        }

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
