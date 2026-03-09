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

    // MARK: Show / Hide

    func toggle() {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
        } else {
            showPanel()
        }
    }

    func show() {
        if panel == nil { buildPanel() }
        positionPanel()
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
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
        hostingView.frame = NSRect(x: 0, y: 0, width: 400, height: 520)

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView,
                        .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        p.title = ""
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.level = .floating
        p.isReleasedWhenClosed = false
        p.hidesOnDeactivate = false
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

    private func showPanel() {
        if panel == nil { buildPanel() }
        positionPanel()
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
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
