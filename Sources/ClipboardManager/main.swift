import AppKit

// Entry point — must be before NSApplication.shared is accessed.
let app      = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
