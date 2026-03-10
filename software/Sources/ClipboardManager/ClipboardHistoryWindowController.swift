import AppKit
import SwiftUI

// MARK: - ClipboardHistoryWindowController
//
// Manages the floating HUD panel that shows clipboard history.
// Toggled by Cmd+Shift+V (or the status bar menu).

final class ClipboardHistoryWindowController {
    private var panel: NSPanel?
    private let monitor: ClipboardMonitor
    private var snipTool: SnipTool?

    init(monitor: ClipboardMonitor) {
        self.monitor = monitor
    }

    // MARK: Show / Hide / Toggle

    func toggle() {
        if let panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        if panel == nil { buildPanel() }
        positionPanel()

        // Activate the app so the panel can become key.
        // On macOS, an .accessory app cannot have key windows unless it
        // explicitly activates itself first.
        NSApp.activate(ignoringOtherApps: true)

        panel?.makeKeyAndOrderFront(nil)

        // Belt-and-suspenders: sometimes makeKeyAndOrderFront alone isn't
        // enough if the app was deeply in the background. Ordering front
        // explicitly after a microtask ensures visibility.
        DispatchQueue.main.async { [weak self] in
            self?.panel?.orderFrontRegardless()
        }
    }

    func hide() {
        panel?.orderOut(nil)
    }

    // MARK: Private – Panel construction

    private func buildPanel() {
        let hostingView = NSHostingView(
            rootView: ClipboardHistoryView(
                monitor: monitor,
                onSnip:    { [weak self] in self?.beginSnip() },
                onDismiss: { [weak self] in self?.hide() }
            )
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 400, height: 540)

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 540),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.title = ""
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.appearance = NSAppearance(named: .aqua)   // force light mode
        p.backgroundColor = NSColor(red: 245/255, green: 244/255, blue: 240/255, alpha: 1)

        // Floating level ensures the panel sits above normal windows
        p.level = .floating

        p.isReleasedWhenClosed = false

        // Do NOT hide on deactivate — the user may click another window
        // and then immediately hit Cmd+Shift+V to bring it back; if the
        // panel hides on deactivate the toggle logic gets confused about
        // whether the panel is "visible".
        p.hidesOnDeactivate = false

        p.hasShadow = true

        // Allow the panel to appear on all Spaces and over full-screen apps.
        // Without this, switching to a full-screen Space hides the panel and
        // Cmd+Shift+V appears to do nothing.
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        // Ensure the panel can receive key events (for search field, Esc, etc.)
        p.isMovableByWindowBackground = true
        p.becomesKeyOnlyIfNeeded = false

        p.contentView = hostingView
        panel = p
    }

    private func positionPanel() {
        guard let panel,
              let screen = NSScreen.main else { return }
        let sv = screen.visibleFrame
        let pw = panel.frame.size
        // Top-right, just under the menu bar
        let x = sv.maxX - pw.width - 16
        let y = sv.maxY - pw.height - 8
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: Private – Snip

    private func beginSnip() {
        hide()
        // Small delay so the panel is fully gone before the overlay appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }
            let tool = SnipTool()
            self.snipTool = tool
            tool.start { [weak self] image in
                guard let self else { return }
                let item = ClipboardItem(content: .image(image))
                self.monitor.addItem(item)
                self.monitor.copyToClipboard(item)
                // Re-show history after capture
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.show()
                }
            }
        }
    }
}