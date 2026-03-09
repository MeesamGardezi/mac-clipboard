# Clipboard Manager for macOS

A lightweight native macOS menu bar app that keeps a clipboard history and includes a built-in screen-region snipping tool.

## Features

| Feature | Detail |
|---|---|
| **Clipboard history** | Tracks the last 50 copied items (text + images) |
| **Global shortcut** | `Cmd + Shift + V` opens/closes the history panel from any app |
| **Search** | Filter text history in real time |
| **Snip tool** | Click **Snip** to draw a selection on screen — the capture is added to clipboard history and copied automatically |
| **Menu bar** | Runs silently in the background; no Dock icon |
| **Multi-display** | Snip overlay appears on every connected screen |

---

## Requirements

- macOS 13 Ventura or later
- Xcode 15+ **or** Swift 5.9 command-line tools (`xcode-select --install`)

---

## Build & Run

```bash
# Clone / open the repo, then:
make app      # builds with swift build -c release and assembles ClipboardManager.app
make run      # builds + opens the .app
```

The first time you run it you will be prompted for two permissions:

1. **Accessibility** — required for the global `Cmd+Shift+V` hotkey
   *System Settings → Privacy & Security → Accessibility → enable ClipboardManager*

2. **Screen Recording** — required for the Snip tool
   *System Settings → Privacy & Security → Screen Recording → enable ClipboardManager*

---

## Project Structure

```
Sources/ClipboardManager/
├── main.swift                         Entry point
├── AppDelegate.swift                  App lifecycle, status bar menu
├── ClipboardItem.swift                Data model (text / image)
├── ClipboardMonitor.swift             Polls NSPasteboard every 0.5 s
├── HotkeyManager.swift                CGEventTap — global Cmd+Shift+V
├── ClipboardHistoryWindowController   Floating HUD panel management
├── ClipboardHistoryView.swift         SwiftUI list + search UI
├── SnipTool.swift                     Full-screen overlay + CGWindowListCreateImage
└── Resources/
    ├── Info.plist                     Bundle metadata & privacy strings
    └── ClipboardManager.entitlements  Non-sandboxed (required for CGEventTap)
```

---

## How it works

### Global hotkey
`HotkeyManager` installs a **CGEventTap** on the session event stream.
When `Cmd+Shift+V` is detected the event is consumed (not forwarded) and the history panel is toggled.

### Clipboard monitoring
`ClipboardMonitor` polls `NSPasteboard.general.changeCount` every 0.5 s.
New text or image content is prepended to `history` (max 50 items, with consecutive duplicate suppression).
Internal pastes (when you click an item) set `suppressNextCapture = true` to avoid re-recording the item.

### Snip tool
1. The history panel is hidden.
2. A borderless `NSPanel` at screensaver-level covers every screen with a 45 % dark tint.
3. The user drags to select a region; a live **W × H** readout and corner brackets are drawn.
4. On mouse-up the overlay is dismissed, a 150 ms delay elapses, then
   `CGWindowListCreateImage` captures the selected rectangle.
5. The resulting `NSImage` is added to history and copied to the clipboard.

---

## Permissions note

`CGEventTap` and `CGWindowListCreateImage` both require running **outside the App Sandbox**.
The app therefore cannot be distributed via the Mac App Store without significant rearchitecting.
For personal or enterprise distribution, sign with an Apple Developer ID and notarize with Hardened Runtime.
