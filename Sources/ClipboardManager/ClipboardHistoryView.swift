import SwiftUI
import AppKit

// MARK: - ClipboardHistoryView

struct ClipboardHistoryView: View {
    @ObservedObject var monitor: ClipboardMonitor
    let onSnip: () -> Void
    let onDismiss: () -> Void

    @State private var searchText = ""
    @State private var hoveredID: UUID?

    private var filteredItems: [ClipboardItem] {
        guard !searchText.isEmpty else { return monitor.history }
        return monitor.history.filter {
            if case .text(let s) = $0.content {
                return s.localizedCaseInsensitiveContains(searchText)
            }
            return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchBar
            Divider()
            itemList
            Divider()
            footer
        }
        .frame(width: 400, height: 520)
        .background(.ultraThinMaterial)
    }

    // MARK: Sub-views

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard.fill")
                .foregroundStyle(.secondary)
            Text("Clipboard History")
                .font(.headline)
            Spacer()
            Button(action: onSnip) {
                Label("Snip", systemImage: "scissors")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Capture a screen region (Snipping Tool)")

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
            TextField("Search clipboard…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(NSColor.textBackgroundColor).opacity(0.4))
    }

    @ViewBuilder
    private var itemList: some View {
        if filteredItems.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredItems) { item in
                        ClipboardItemRow(
                            item: item,
                            isHovered: hoveredID == item.id,
                            onHover: { hoveredID = $0 ? item.id : nil },
                            onSelect: {
                                monitor.copyToClipboard(item)
                                onDismiss()
                            }
                        )
                        Divider().padding(.leading, 58)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: monitor.history.isEmpty ? "clipboard" : "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(monitor.history.isEmpty ? "Nothing copied yet" : "No matching items")
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Text("\(monitor.history.count) item\(monitor.history.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            if !monitor.history.isEmpty {
                Button("Clear All") { monitor.clearHistory() }
                    .font(.caption)
                    .foregroundStyle(.red)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }
}

// MARK: - ClipboardItemRow

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isHovered: Bool
    let onHover: (Bool) -> Void
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 10) {
                itemIcon
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.content.previewText)
                        .lineLimit(item.isImage ? 1 : 2)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.primary)
                    Text(item.timeAgoString)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovered
            ? Color(NSColor.selectedContentBackgroundColor).opacity(0.15)
            : Color.clear)
        .onHover(perform: onHover)
    }

    @ViewBuilder
    private var itemIcon: some View {
        if item.isImage, let thumb = item.thumbnail {
            Image(nsImage: thumb)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(width: 44, height: 36)
                Image(systemName: "doc.text")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
