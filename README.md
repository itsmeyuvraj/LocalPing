# LocalPing (macOS)

LocalPing is a lightweight, zero-cloud peer-to-peer macOS menu bar utility built with **Swift 6**, **SwiftUI**, **AppKit**, and Apple's **Network.framework**.

It enables frictionless local device discovery and direct TCP file & text drops across the same Wi-Fi subnet with zero cloud dependencies.

---

## Architecture Overview

```
LocalPing/
├── Package.swift                             # Swift Package Manager manifest (macOS 14+)
├── Resources/
│   ├── Info.plist                            # LSUIElement = true, Bonjour service keys, local network description
│   └── LocalPing.entitlements                # App sandbox network server/client & file access entitlements
├── Sources/
│   └── LocalPing/
│       ├── App/
│       │   ├── LocalPingApp.swift            # @main App & NSApplicationDelegate lifecycle
│       │   └── MenuController.swift          # NSStatusItem, NSPopover anchor & dynamic icon manager
│       ├── Models/
│       │   ├── Peer.swift                    # Sendable model for Bonjour discovered peers
│       │   ├── TransferPayload.swift         # LPNG framing, TransferHeader & TransferTask models
│       │   └── UserProfile.swift             # Observable local profile with persistent status
│       ├── Audio/
│       │   └── AudioStreamManager.swift      # AVFoundation capture, conversion, live streaming & playback
│       ├── Canvas/
│       │   ├── CanvasModels.swift            # Strokes, points, sticky notes, and action payload models
│       │   ├── CanvasWindowController.swift  # Standalone NSWindow controller with lifecycle management
│       │   ├── SharedCanvasManager.swift     # Real-time stroke dispatch, peer sync, and PNG/Markdown exports
│       │   └── SharedCanvasView.swift        # SwiftUI drawing canvas, floating toolbar, and note cards
│       ├── Chat/
│       │   ├── ChatMessage.swift             # Chat message models with markdown code block parsing
│       │   ├── ChatRoomManager.swift         # Subnet broadcast dispatcher, incoming handler & JSON persistence
│       │   ├── ChatRoomView.swift            # Scrollable chat UI, syntax code cards, and snippet input bar
│       │   └── ChatWindowController.swift    # Resizable standalone NSWindow controller with peer counters
│       ├── Clipboard/
│       │   └── ClipboardSyncManager.swift    # Background NSPasteboard observer & multi-peer broadcast dispatcher
│       ├── Networking/
│       │   ├── NetworkManager.swift          # Bonjour discovery (NWBrowser) and service advertising (NWListener)
│       │   └── TransferManager.swift         # Safe TCP chunked streaming, file I/O & conflict resolution
│       ├── Views/
│       │   ├── ContentView.swift             # Root popover view with segmented tabs (Peers, Clipboard, Transfers)
│       │   ├── ClipboardFeedView.swift       # Live incoming clipboard sync feed with 1-click copy & sync controls
│       │   ├── HeaderView.swift              # User profile avatar, inline name edit & status picker pills
│       │   ├── PeerListView.swift            # Discovered peer cards and static empty state
│       │   ├── PeerRowView.swift             # Peer card with .onDrop target, action buttons, Canvas & Push-to-Talk
│       │   ├── TransferActivityView.swift    # Live transfer progress bars & recent transfer history
│       └── Utilities/
│           └── DropPayloadHandler.swift      # Drag-and-drop UTType unpacker (files & text snippets)
└── Tests/
    └── LocalPingTests/
        └── LocalPingTests.swift              # Swift Testing suite for headers, framing, and progress math
```

---

## Key Features

1. **Menu Bar Agent (`LSUIElement`)**: Runs purely in the status bar with zero Dock clutter.
2. **Multi-Peer Local Subnet Chat & Snippet Room**:
   - Zero-cloud concurrent broadcast of messages and code snippets to all discovered subnet peers simultaneously.
   - Independent resizable `NSWindow` chat room with user avatars, message bubbles, and live online peer counters.
   - Automatic markdown parsing and dedicated syntax-styled code snippet cards with language badges and 1-click copy.
   - Snippet composing mode supporting multiple programming languages (Swift, Python, JSON, Bash, Markdown, etc.).
   - Local session persistence in `~/Library/Application Support/LocalPing/chat_history.json` and Markdown export.
3. **Peer-to-Peer Collaborative Canvas**:
   - Standalone resizable drawing & noting window with dark slate dot-matrix grid.
   - CoreGraphics & SwiftUI `Canvas` rendering for buttery-smooth freehand drawing.
   - Pen, Marker (semi-transparent highlighter), Eraser, and interactive draggable Sticky Notes.
   - Real-time stroke & note serialization over `Network.framework` local TCP streams.
   - Automatic state synchronization on session join, undo stack, and full clear coordination.
   - PNG Image export (retina CoreGraphics bitmap) & structured Markdown summary export with 1-click save to `~/Downloads/LocalPing/`.
4. **Real-Time Clipboard Synchronization**:
   - Background polling of `NSPasteboard.general` change count with zero impact on battery.
   - Echo-loop prevention ensuring received clips do not get re-broadcasted across the local subnet.
   - Live broadcasting to all active peers via `Network.framework` TCP streaming.
   - Dedicated "Clipboard" feed tab with sender attribution, relative timestamps, preview cards, and 1-click copy to system pasteboard.
   - Configurable auto-apply to local pasteboard and broadcasting switch.
4. **Push-to-Talk Live Audio Streaming (`AVFoundation`)**:
   - Captures microphone input via `AVAudioEngine` and downsamples via `AVAudioConverter` to 16 kHz Float32 mono PCM.
   - Low-latency real-time transmission over dedicated TCP stream with `.noDelay = true`.
   - Automatic speaker playback on receiver using `AVAudioPlayerNode` with zero manual configuration.
   - One-click Walkie-Talkie button with live mic meter and speaking indicators.
4. **Dynamic Menu Bar Icon**: Dynamically adapts its icon to show:
   - `antenna.radiowaves.left.and.right` (idle)
   - Badge with count of active peers (` 2`)
   - `arrow.up.and.down.circle.fill` while transfers are active
5. **Zero-Config Bonjour Discovery (`_localping._tcp`)**:
   - Uses `NWListener` and `NWBrowser`.
   - Embeds peer IDs, usernames, and customizable status messages directly into `NWTXTRecord` dictionaries.
   - Automatically detects status updates and presence changes without requiring manual refresh.
6. **Binary TCP Streaming Protocol (`LPNG`)**:
   - 4-byte Magic Number (`0x4C504E47` -> `"LPNG"`).
   - 4-byte JSON Header Length (Big-Endian `UInt32`).
   - JSON-encoded `TransferHeader` metadata (supporting files, snippets, audio streams, and clipboard sync).
   - Streamed binary payload in 64 KB chunks directly to `FileHandle` to prevent memory spikes on large files.
7. **Conflict-Free File Downloads**: Saves incoming files into `~/Downloads/LocalPing/` with automatic name collision resolution (`file (1).png`).
8. **Drag-and-Drop Interaction**:
   - Drag files or highlighted text snippets directly onto any peer card.
   - Highlights with cyan glow and animated scaling when hovered with a payload.
   - Also includes quick action buttons for file picker dialogs and clipboard sharing.

---

## How to Build & Run

### Method 1: Using Xcode
1. Open the folder in Xcode:
   ```bash
   open Package.swift
   ```
2. Select the **LocalPing** executable scheme and your Mac as the destination.
3. Press **Cmd + R** to run.
4. You will see the LocalPing icon appear in your macOS menu bar.

### Method 2: Swift CLI
```bash
# Build the executable
swift build

# Run unit tests
swift test

# Launch the app
.build/debug/LocalPing
```
