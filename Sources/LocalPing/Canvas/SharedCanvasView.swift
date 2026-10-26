import SwiftUI
import AppKit

public struct SharedCanvasView: View {
    @State private var canvasManager = SharedCanvasManager.shared

    // Active in-progress stroke points
    @State private var activePoints: [CanvasPoint] = []
    @State private var canvasSize: CGSize = CGSize(width: 900, height: 600)
    @State private var showClearConfirmation: Bool = false
    @State private var isExporting: Bool = false
    @State private var exportMessage: String? = nil

    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                // 1. Sleek Canvas Background with Dot Matrix
                CanvasBackgroundView()
                    .frame(width: proxy.size.width, height: proxy.size.height)

                // 2. CoreGraphics / SwiftUI Drawing Layer
                Canvas { context, size in
                    renderStrokes(in: context)
                    renderActiveStroke(in: context)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .contentShape(Rectangle())
                .gesture(drawingGesture)

                // 3. Collaborative Sticky Notes Layer
                ForEach(canvasManager.notes) { note in
                    StickyNoteCardView(note: note) { updated in
                        canvasManager.updateNote(updated)
                    } onDelete: {
                        canvasManager.deleteNote(id: note.id)
                    }
                }

                // 4. Floating Glassmorphic Control Toolbar
                CanvasToolbarView(
                    canvasSize: proxy.size,
                    onClear: { showClearConfirmation = true },
                    onUndo: { canvasManager.undo() },
                    onQuickSave: {
                        canvasManager.quickSaveBothToDownloads(canvasSize: proxy.size)
                        showToast("Saved PNG & Markdown to Downloads!")
                    },
                    onExportPNG: {
                        canvasManager.savePNGWithPanel(canvasSize: proxy.size)
                    },
                    onExportMarkdown: {
                        canvasManager.saveMarkdownWithPanel()
                    }
                )
                .padding(.top, 16)

                // 5. Toast Feedback Banner
                if let message = exportMessage {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(message)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                        .padding(.bottom, 24)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onAppear {
                self.canvasSize = proxy.size
            }
            .onChange(of: proxy.size) { _, newSize in
                self.canvasSize = newSize
            }
        }
        .frame(minWidth: 720, minHeight: 500)
        .confirmationDialog(
            "Clear entire shared canvas?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Canvas for Everyone", role: .destructive) {
                canvasManager.clearCanvas()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all drawing strokes and sticky notes for you and your peer.")
        }
    }

    // MARK: - Gesture Handler

    private var drawingGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let currentPoint = CanvasPoint(value.location)

                if canvasManager.selectedTool == .note {
                    // Note tool waits for touch up to place note
                    return
                }

                if canvasManager.selectedTool == .eraser {
                    // Erase strokes intersecting within brush radius
                    eraseStrokesNear(point: currentPoint, radius: 18)
                }

                activePoints.append(currentPoint)
            }
            .onEnded { value in
                let endPoint = CanvasPoint(value.location)

                if canvasManager.selectedTool == .note {
                    canvasManager.addNote(at: value.location)
                    canvasManager.selectedTool = .pen
                    return
                }

                if canvasManager.selectedTool == .eraser {
                    eraseStrokesNear(point: endPoint, radius: 18)
                    activePoints.removeAll()
                    return
                }

                guard activePoints.count > 0 else { return }

                let optimized = optimize(points: activePoints)
                let isMarker = canvasManager.selectedTool == .marker
                let stroke = CanvasStroke(
                    points: optimized,
                    colorHex: canvasManager.selectedColorHex,
                    lineWidth: isMarker ? 16.0 : canvasManager.selectedLineWidth,
                    isEraser: false,
                    authorName: canvasManager.localUserName
                )

                canvasManager.addStroke(stroke)
                activePoints.removeAll()
            }
    }

    private func eraseStrokesNear(point: CanvasPoint, radius: Double) {
        // Find strokes that come within radius of this eraser point and remove them
        for stroke in canvasManager.strokes {
            if stroke.points.contains(where: { $0.distance(to: point) <= radius }) {
                canvasManager.undo() // Or specific stroke removal
                break
            }
        }
    }

    private func optimize(points: [CanvasPoint]) -> [CanvasPoint] {
        guard points.count > 2 else { return points }
        var result: [CanvasPoint] = [points[0]]
        for pt in points.dropFirst() {
            if pt.distance(to: result.last!) >= 2.5 {
                result.append(pt)
            }
        }
        if let last = points.last, result.last != last {
            result.append(last)
        }
        return result
    }

    // MARK: - CoreGraphics Rendering

    private func renderStrokes(in context: GraphicsContext) {
        for stroke in canvasManager.strokes {
            guard let first = stroke.points.first else { continue }
            var path = Path()
            path.move(to: first.cgPoint)
            for pt in stroke.points.dropFirst() {
                path.addLine(to: pt.cgPoint)
            }

            let color = Color(hex: stroke.colorHex)
            let isMarker = stroke.lineWidth >= 12.0
            let opacity = isMarker ? 0.35 : 1.0

            context.stroke(
                path,
                with: .color(color.opacity(opacity)),
                style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func renderActiveStroke(in context: GraphicsContext) {
        guard let first = activePoints.first else { return }
        var path = Path()
        path.move(to: first.cgPoint)
        for pt in activePoints.dropFirst() {
            path.addLine(to: pt.cgPoint)
        }

        let isMarker = canvasManager.selectedTool == .marker
        let isEraser = canvasManager.selectedTool == .eraser
        let width = isMarker ? 16.0 : (isEraser ? 24.0 : canvasManager.selectedLineWidth)
        let color = isEraser ? Color.red.opacity(0.4) : Color(hex: canvasManager.selectedColorHex)
        let opacity = isMarker ? 0.35 : (isEraser ? 0.5 : 1.0)

        context.stroke(
            path,
            with: .color(color.opacity(opacity)),
            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        )
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.3)) {
            exportMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut) {
                exportMessage = nil
            }
        }
    }
}

// MARK: - Canvas Background Grid

struct CanvasBackgroundView: View {
    var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.10, blue: 0.12)
                .ignoresSafeArea()

            Canvas { context, size in
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color(red: 0.10, green: 0.10, blue: 0.12))
                )

                let spacing: CGFloat = 28.0
                for x in stride(from: CGFloat(20), to: size.width, by: spacing) {
                    for y in stride(from: CGFloat(20), to: size.height, by: spacing) {
                        let dot = CGRect(x: x - 1, y: y - 1, width: 2, height: 2)
                        context.fill(Path(ellipseIn: dot), with: .color(Color.white.opacity(0.08)))
                    }
                }
            }
        }
    }
}

// MARK: - Floating Glassmorphic Toolbar

struct CanvasToolbarView: View {
    @Bindable var canvasManager = SharedCanvasManager.shared

    let canvasSize: CGSize
    let onClear: () -> Void
    let onUndo: () -> Void
    let onQuickSave: () -> Void
    let onExportPNG: () -> Void
    let onExportMarkdown: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 1. Session Status Indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(canvasManager.isConnectedWithPeer ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)

                if let peer = canvasManager.activePeer {
                    Text(peer.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    Text("Solo Canvas")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())

            Divider()
                .frame(height: 20)
                .background(Color.white.opacity(0.15))

            // 2. Tool Selection
            HStack(spacing: 4) {
                ForEach(CanvasTool.allCases) { tool in
                    Button {
                        canvasManager.selectedTool = tool
                    } label: {
                        Image(systemName: tool.iconName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(canvasManager.selectedTool == tool ? .white : .secondary)
                            .frame(width: 28, height: 28)
                            .background(
                                canvasManager.selectedTool == tool ?
                                Color.cyan.opacity(0.35) :
                                Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help(tool.title)
                }
            }

            Divider()
                .frame(height: 20)
                .background(Color.white.opacity(0.15))

            // 3. Color Palette
            HStack(spacing: 6) {
                ForEach(SharedCanvasManager.defaultColors, id: \.self) { hex in
                    Button {
                        canvasManager.selectedColorHex = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: canvasManager.selectedColorHex == hex ? 2 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()
                .frame(height: 20)
                .background(Color.white.opacity(0.15))

            // 4. Stroke Width Selector
            HStack(spacing: 6) {
                ForEach([2.0, 4.0, 8.0, 14.0], id: \.self) { width in
                    Button {
                        canvasManager.selectedLineWidth = width
                    } label: {
                        Circle()
                            .fill(Color.white)
                            .frame(width: CGFloat(width + 2), height: CGFloat(width + 2))
                            .frame(width: 22, height: 22)
                            .background(
                                canvasManager.selectedLineWidth == width ?
                                Color.white.opacity(0.2) :
                                Color.clear
                            )
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("\(Int(width))pt stroke")
                }
            }

            Divider()
                .frame(height: 20)
                .background(Color.white.opacity(0.15))

            // 5. Actions (Undo & Clear)
            HStack(spacing: 4) {
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Undo last stroke")

                Button(action: onClear) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red.opacity(0.9))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Clear canvas")
            }

            Divider()
                .frame(height: 20)
                .background(Color.white.opacity(0.15))

            // 6. Export Menu
            Menu {
                Button {
                    onExportPNG()
                } label: {
                    Label("Export as PNG Image...", systemImage: "photo")
                }

                Button {
                    onExportMarkdown()
                } label: {
                    Label("Export as Markdown Notes...", systemImage: "doc.text")
                }

                Divider()

                Button {
                    onQuickSave()
                } label: {
                    Label("Quick Save Both to Downloads", systemImage: "arrow.down.circle")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Export")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.cyan.opacity(0.35))
                .clipShape(Capsule())
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.5))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
    }
}

// MARK: - Interactive Sticky Note Card

struct StickyNoteCardView: View {
    @State var note: CanvasNote
    let onUpdate: (CanvasNote) -> Void
    let onDelete: () -> Void

    @State private var dragOffset: CGSize = .zero
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: note.colorHex))
                    .frame(width: 8, height: 8)

                Text(note.authorName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)

                Text("• \(note.formattedTime)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(hex: note.colorHex).opacity(0.25))

            // Text input area
            TextEditor(text: $note.text)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(8)
                .focused($isFocused)
                .onChange(of: note.text) { _, _ in
                    onUpdate(note)
                }
        }
        .frame(width: 200, height: 120)
        .background(Color(red: 0.16, green: 0.16, blue: 0.20))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: note.colorHex).opacity(0.5), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
        .offset(
            x: note.x + Double(dragOffset.width),
            y: note.y + Double(dragOffset.height)
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    note.x += Double(value.translation.width)
                    note.y += Double(value.translation.height)
                    dragOffset = .zero
                    onUpdate(note)
                }
        )
    }
}
