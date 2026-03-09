import AppKit

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let monitor = ClipboardMonitor()
    private let hotkey  = HotkeyManager()
    private var windowController: ClipboardHistoryWindowController?

    // MARK: NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock — runs as a menu bar accessory
        NSApp.setActivationPolicy(.accessory)

        setupStatusBar()
        monitor.start()

        // Lazy-init window controller (avoids creating the window before the
        // run loop is ready)
        windowController = ClipboardHistoryWindowController(monitor: monitor)

        hotkey.register { [weak self] in
            self?.windowController?.toggle()
        }
    }

    // MARK: Status bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let btn = statusItem?.button {
            // SF Symbol available on macOS 12+; falls back gracefully
            btn.image = NSImage(
                systemSymbolName: "clipboard",
                accessibilityDescription: "Clipboard Manager"
            )
            btn.action = #selector(statusBarClicked)
            btn.target = self
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Show Clipboard History",
                     action: #selector(showHistory),
                     keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Clear History",
                     action: #selector(clearHistory),
                     keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit ClipboardManager",
                     action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")
        statusItem?.menu = menu
    }

    // MARK: Actions

    @objc private func statusBarClicked() {
        windowController?.toggle()
    }

    @objc private func showHistory() {
        windowController?.show()
    }

    @objc private func clearHistory() {
        monitor.clearHistory()
    }
}
