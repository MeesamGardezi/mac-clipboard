import SwiftUI
import AppKit

// MARK: - Brand colors (matches landing page)

private extension Color {
    static let mcBg       = Color(red: 245/255, green: 244/255, blue: 240/255)
    static let mcSurface  = Color.white
    static let mcSurface2 = Color(red: 237/255, green: 236/255, blue: 232/255)
    static let mcAccent   = Color(red: 1.0,     green: 92/255,  blue: 0)
    static let mcText     = Color(red: 17/255,  green: 17/255,  blue: 17/255)
    static let mcText2    = Color(red: 90/255,  green: 90/255,  blue: 90/255)
    static let mcText3    = Color(red: 154/255, green: 154/255, blue: 154/255)
    static let mcBorder   = Color.black.opacity(0.07)
    static let mcBorder2  = Color.black.opacity(0.12)
}

// MARK: - Tab

enum AppTab { case history, saved }

// MARK: - ClipboardHistoryView

struct ClipboardHistoryView: View {
    @ObservedObject var monitor: ClipboardMonitor
    let onSnip: () -> Void
    let onDismiss: () -> Void

    @State private var searchText = ""
    @State private var hoveredID: UUID?
    @State private var activeTab: AppTab = .history
    @State private var showCopied = false

    private var filteredHistory: [ClipboardItem] {
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
            rule
            tabBar
            rule
            if activeTab == .history {
                searchBar
                rule
            }
            itemList
            rule
            footer
        }
        .frame(width: 400, height: 540)
        .background(Color.mcBg)
        .overlay(alignment: .bottom) {
            if showCopied {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Copied!")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Color.mcAccent, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                .padding(.bottom, 48)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: showCopied)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.mcAccent)
                    .frame(width: 24, height: 24)
                Image(systemName: "clipboard.fill")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white)
            }
            Text("maClip")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.mcText)
            Spacer()
            Button(action: onSnip) {
                HStack(spacing: 4) {
                    Image(systemName: "scissors")
                        .font(.system(size: 10.5))
                    Text("Snip")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Color.mcText2)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.mcSurface)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.mcBorder2, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Capture a screen region")
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(Color.mcText3)
                    .frame(width: 20, height: 20)
                    .background(Color.mcSurface2)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.mcSurface)
    }

    // MARK: Tab bar

    private var tabBar: some View {
        HStack(spacing: 4) {
            tabButton("History", tab: .history, badge: monitor.history.count)
            tabButton("Saved",   tab: .saved,   badge: monitor.savedItems.count)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.mcSurface)
    }

    private func tabButton(_ label: String, tab: AppTab, badge: Int) -> some View {
        let active = activeTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.14)) { activeTab = tab }
            if tab != .history { searchText = "" }
        } label: {
            HStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(active ? Color.mcAccent : Color.mcText3)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(active ? Color.mcAccent.opacity(0.1) : Color.mcSurface2)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .foregroundStyle(active ? Color.mcAccent : Color.mcText2)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(active ? Color.mcAccent.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(active ? Color.mcAccent.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Search bar

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11.5))
                .foregroundStyle(Color.mcText3)
            TextField("Search clipboard…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(Color.mcText)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.mcText3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.mcBg)
    }

    // MARK: Item list

    @ViewBuilder
    private var itemList: some View {
        let items: [ClipboardItem] = activeTab == .history ? filteredHistory : monitor.savedItems
        if items.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        ClipboardItemRow(
                            item: item,
                            isHovered: hoveredID == item.id,
                            onHover:      { hoveredID = $0 ? item.id : nil },
                            onSelect:     {
                                monitor.copyToClipboard(item)
                                withAnimation { showCopied = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                                    withAnimation { showCopied = false }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onDismiss() }
                                }
                            },
                            onToggleSave: { item.isSaved ? monitor.unsave(item) : monitor.save(item) }
                        )
                        rule.padding(.leading, 58)
                    }
                }
                .padding(.vertical, 4)
            }
            .background(Color.mcBg)
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: activeTab == .history
                  ? (monitor.history.isEmpty ? "clipboard" : "magnifyingglass")
                  : "bookmark")
                .font(.system(size: 30))
                .foregroundStyle(Color.mcText3)
            Text(activeTab == .history
                 ? (monitor.history.isEmpty ? "Nothing copied yet" : "No matching items")
                 : "No saved items yet")
                .font(.system(size: 13))
                .foregroundStyle(Color.mcText2)
            if activeTab == .saved {
                Text("Hover any item in History and tap the bookmark to save it forever.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.mcText3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 220)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.mcBg)
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            let count = activeTab == .history ? monitor.history.count : monitor.savedItems.count
            Text(activeTab == .history
                 ? "\(count) item\(count == 1 ? "" : "s")"
                 : "\(count) saved")
                .font(.system(size: 11))
                .foregroundStyle(Color.mcText3)
            Spacer()
            if activeTab == .history && !monitor.history.isEmpty {
                Button("Clear History") { monitor.clearHistory() }
                    .font(.system(size: 11))
                    .foregroundStyle(Color.red.opacity(0.65))
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.mcSurface)
    }

    private var rule: some View {
        Rectangle()
            .fill(Color.mcBorder)
            .frame(height: 1)
    }
}

// MARK: - ClipboardItemRow

struct ClipboardItemRow: View {
    @ObservedObject var item: ClipboardItem
    let isHovered: Bool
    let onHover: (Bool) -> Void
    let onSelect: () -> Void
    let onToggleSave: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 10) {
                    itemIcon
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.content.previewText)
                            .lineLimit(item.isImage ? 1 : 2)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color.mcText)
                        Text(item.timeAgoString)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Color.mcText3)
                    }
                    Spacer(minLength: isHovered ? 28 : 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Single bookmark icon — appears only on hover
            if isHovered {
                Button(action: onToggleSave) {
                    Image(systemName: item.isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(
                            item.isSaved
                                ? Color.mcAccent
                                : Color.mcText3
                        )
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                .help(item.isSaved ? "Remove from Saved" : "Save forever")
                .transition(.opacity.animation(.easeInOut(duration: 0.1)))
            }
        }
        .background(
            isHovered
                ? (item.isSaved
                    ? Color.mcAccent.opacity(0.05)
                    : Color.black.opacity(0.04))
                : Color.clear
        )
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
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.mcSurface2)
                    .frame(width: 44, height: 36)
                Image(systemName: "doc.text")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.mcText2)
            }
        }
    }
}
