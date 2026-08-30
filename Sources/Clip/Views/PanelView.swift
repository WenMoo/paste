import SwiftUI
import AppKit

struct PanelRootView: View {
    @ObservedObject private var store = ClipStore.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            HandleBar()
            ToolbarView()
            CardStrip()
        }
        .padding(.bottom, 10)
        .background(PanelBackground())
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .sheet(item: $store.editingItem) { item in
            EditClipView(item: item)
        }
        .overlay {
            if store.creatingBoard {
                NewBoardOverlay()
            }
        }
        .overlay {
            if store.renamingItem != nil {
                RenameOverlay()
            }
        }
        .overlay {
            if let id = store.previewItemID, let item = store.visibleItems.first(where: { $0.id == id }) {
                PreviewOverlay(item: item)
            }
        }
        .overlay(alignment: .topTrailing) {
            if settings.isPaused {
                Text(L10n.paused)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.9), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(.top, 34)
                    .padding(.trailing, 24)
            }
        }
    }
}

struct PanelBackground: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.22))
        }
    }
}

struct HandleBar: View {
    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.28))
            .frame(width: 36, height: 4)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }
}

struct ToolbarView: View {
    @ObservedObject private var store = ClipStore.shared
    @FocusState private var searchFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    BoardTab(
                        title: L10n.history,
                        color: Color(red: 0.33, green: 0.55, blue: 0.98),
                        selected: store.selection == .history
                    ) {
                        store.selection = .history
                        store.selectedIDs = Set(store.visibleItems.prefix(1).map(\.id))
                    }
                    ForEach(store.boards) { board in
                        BoardTab(title: board.name, color: board.color, selected: store.selection == .board(board.id)) {
                            store.selection = .board(board.id)
                            store.selectedIDs = Set(store.visibleItems.prefix(1).map(\.id))
                        }
                        .contextMenu {
                            Button(L10n.deleteBoard, role: .destructive) {
                                store.deleteBoard(board)
                            }
                        }
                    }
                    Button {
                        store.creatingBoard = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help(L10n.newPinboard)
                }
            }

            FilterChips()

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(L10n.searchPlaceholder, text: $store.query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .frame(minWidth: 120)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .frame(maxWidth: 240)

            Button {
                SettingsWindow.shared.show()
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help(L10n.settings)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .onAppear { searchFocused = true }
    }
}

struct BoardTab: View {
    let title: String
    let color: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(.system(size: 12, weight: selected ? .semibold : .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? Color.white.opacity(0.14) : Color.white.opacity(0.05))
            )
            .foregroundStyle(.white.opacity(selected ? 1 : 0.75))
        }
        .buttonStyle(.plain)
    }
}

struct FilterChips: View {
    @ObservedObject private var store = ClipStore.shared

    var body: some View {
        HStack(spacing: 4) {
            chip(.all)
            ForEach(ClipKind.allCases, id: \.self) { kind in
                chip(.kind(kind))
            }
        }
    }

    private func chip(_ filter: FilterKind) -> some View {
        Button {
            store.filter = filter
        } label: {
            Text(filter.title)
                .font(.system(size: 11, weight: store.filter == filter ? .semibold : .regular))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(store.filter == filter ? Color.white.opacity(0.16) : Color.clear)
                )
                .foregroundStyle(.white.opacity(store.filter == filter ? 1 : 0.55))
        }
        .buttonStyle(.plain)
    }
}

struct CardStrip: View {
    @ObservedObject private var store = ClipStore.shared

    var body: some View {
        let items = store.visibleItems
        if items.isEmpty {
            emptyState
        } else {
            GeometryReader { geo in
                let compact = geo.size.height < 210
                let cardHeight = geo.size.height
                let cardWidth = compact ? max(168, cardHeight * 1.15) : max(200, cardHeight * 0.82)
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                Button {
                                    store.selectedIDs = [item.id]
                                    NotificationCenter.default.post(name: .clipPasteRequested, object: nil)
                                } label: {
                                    ClipCard(
                                        item: item,
                                        selected: store.selectedIDs.contains(item.id),
                                        compact: compact,
                                        index: index
                                    )
                                }
                                .buttonStyle(.plain)
                                .frame(width: cardWidth, height: cardHeight)
                                .contentShape(Rectangle())
                                .id(item.id)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .onChange(of: store.selectedIDs) { _, ids in
                        if let id = ids.first {
                            withAnimation(.easeOut(duration: 0.18)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: store.query.isEmpty ? "clipboard" : "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white.opacity(0.45))
            Text(emptyText)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyText: String {
        if !store.query.isEmpty { return L10n.emptySearch }
        if case .board = store.selection { return L10n.emptyBoard }
        return L10n.emptyHistory
    }
}

extension Notification.Name {
    static let clipPasteRequested = Notification.Name("clipPasteRequested")
}
