import Foundation
import AppKit

// MARK: - ClipboardContent

enum ClipboardContent {
    case text(String)
    case image(NSImage)

    var previewText: String {
        switch self {
        case .text(let s):
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return String(trimmed.prefix(300))
        case .image:
            return "[Screenshot]"
        }
    }

    var isImage: Bool {
        if case .image = self { return true }
        return false
    }
}

// MARK: - ClipboardItem

final class ClipboardItem: Identifiable, ObservableObject {
    let id = UUID()
    let content: ClipboardContent
    let timestamp: Date

    init(content: ClipboardContent) {
        self.content = content
        self.timestamp = Date()
    }

    var thumbnail: NSImage? {
        if case .image(let img) = content { return img }
        return nil
    }

    var isImage: Bool { content.isImage }

    var timeAgoString: String {
        let interval = Date().timeIntervalSince(timestamp)
        switch interval {
        case ..<60:    return "Just now"
        case ..<3600:  return "\(Int(interval / 60))m ago"
        case ..<86400: return "\(Int(interval / 3600))h ago"
        default:       return "\(Int(interval / 86400))d ago"
        }
    }
}
