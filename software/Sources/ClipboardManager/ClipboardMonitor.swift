import AppKit
import Combine

// MARK: - ClipboardMonitor

/// Polls NSPasteboard every 0.5 s and records new items into `history`.
final class ClipboardMonitor: ObservableObject {
    @Published var history: [ClipboardItem] = []
    @Published var savedItems: [ClipboardItem] = []

    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var timer: Timer?
    /// Set to true before writing to the pasteboard internally so the write
    /// is not re-captured as a new history item.
    var suppressNextCapture = false

    // MARK: Lifecycle

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: Polling

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        if suppressNextCapture {
            suppressNextCapture = false
            return
        }

        if let string = pb.string(forType: .string), !string.isEmpty {
            addItem(ClipboardItem(content: .text(string)))
        } else if let image = image(from: pb) {
            addItem(ClipboardItem(content: .image(image)))
        }
    }

    private func image(from pb: NSPasteboard) -> NSImage? {
        for type in [NSPasteboard.PasteboardType.tiff, .png] {
            if let data = pb.data(forType: type), let img = NSImage(data: data) {
                return img
            }
        }
        return nil
    }

    // MARK: Public API

    func addItem(_ item: ClipboardItem) {
        DispatchQueue.main.async {
            // Deduplicate consecutive identical text
            if case .text(let newText) = item.content,
               let first = self.history.first,
               case .text(let existingText) = first.content,
               newText == existingText { return }

            self.history.insert(item, at: 0)
            if self.history.count > 50 {
                self.history = Array(self.history.prefix(50))
            }
        }
    }

    func save(_ item: ClipboardItem) {
        DispatchQueue.main.async {
            guard !self.savedItems.contains(where: { $0.id == item.id }) else { return }
            item.isSaved = true
            self.savedItems.insert(item, at: 0)
        }
    }

    func unsave(_ item: ClipboardItem) {
        DispatchQueue.main.async {
            item.isSaved = false
            self.savedItems.removeAll { $0.id == item.id }
        }
    }

    func copyToClipboard(_ item: ClipboardItem) {
        suppressNextCapture = true
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.content {
        case .text(let s):
            pb.setString(s, forType: .string)
        case .image(let img):
            if let tiff = img.tiffRepresentation {
                pb.setData(tiff, forType: .tiff)
            }
        }
        lastChangeCount = pb.changeCount
    }

    func clearHistory() {
        DispatchQueue.main.async { self.history.removeAll() }
    }
}
