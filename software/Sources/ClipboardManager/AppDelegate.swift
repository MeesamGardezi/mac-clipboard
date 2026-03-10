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

        // Build the window controller (avoids creating the window before the
        // run loop is ready)
        windowController = ClipboardHistoryWindowController(monitor: monitor)

        // Register the global hotkey — note: HotkeyManager internally delays
        // tap creation by 0.3 s to let the run loop settle.
        hotkey.register { [weak self] in
            self?.windowController?.toggle()
        }

        // Show the clipboard history panel on launch.
        // Delay slightly so the status bar, monitor, and event tap are all
        // initialised before the panel appears. This also ensures the panel
        // positions correctly relative to the menu bar.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.windowController?.show()
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
        menu.addItem(withTitle: "Quit maClip",
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