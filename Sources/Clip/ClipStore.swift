import Foundation
import Combine

enum Selection: Hashable {
    case history
    case board(String)
}

@MainActor
final class ClipStore: ObservableObject {
    static let shared = ClipStore()

    @Published private(set) var items: [ClipItem] = []
    @Published private(set) var boards: [Pinboard] = []
    @Published var selection: Selection = .history
    @Published var selectedIDs: Set<String> = []
    @Published var query = ""
    @Published var filter: FilterKind = .all
    @Published var previewItemID: String?
    @Published var editingItem: ClipItem?
    @Published var renamingItem: ClipItem?
    @Published var creatingBoard = false

    private let db = Database(url: Paths.database)

    private init() {
        reload()
        if boards.isEmpty {
            let snippets = Pinboard(
                id: UUID().uuidString,
                name: L10n.snippets,
                colorHex: "7C5CFC",
                sortOrder: 0
            )
            db.insertBoard(snippets)
            boards = [snippets]
        }
        if items.isEmpty {
            seedWelcomeClips()
        }
    }

    var selectedItem: ClipItem? {
        if let id = selectedIDs.first {
            return visibleItems.first { $0.id == id }
        }
        return visibleItems.first
    }

    var visibleItems: [ClipItem] {
        var result: [ClipItem]
        switch selection {
        case .history:
            result = items.filter(\.inHistory)
        case .board(let id):
            result = items.filter { $0.pinboardIDs.contains(id) }
        }

        switch filter {
        case .all: break
        case .kind(let kind):
            result = result.filter { $0.kind == kind }
        }

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            let ids = Set(db.search(q))
            result = result.filter { item in
                ids.contains(item.id)
                    || item.previewText.localizedCaseInsensitiveContains(q)
                    || item.title.localizedCaseInsensitiveContains(q)
            }
        }
        return result
    }

    var currentBoard: Pinboard? {
        if case .board(let id) = selection {
            return boards.first { $0.id == id }
        }
        return nil
    }

    func reload() {
        items = db.allClips()
        boards = db.allBoards()
        if selectedIDs.isEmpty, let first = visibleItems.first {
            selectedIDs = [first.id]
        }
    }

    func add(_ item: ClipItem) {
        if let last = items.first, last.inHistory, isDuplicate(last, item) {
            return
        }
        db.insert(item)
        items.insert(item, at: 0)
        if case .history = selection {
            selectedIDs = [item.id]
        }
        prune()
    }

    func update(_ item: ClipItem) {
        db.update(item)
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        }
    }

    func deleteSelected() {
        let ids = selectedIDs
        for id in ids {
            db.delete(id: id)
        }
        items.removeAll { ids.contains($0.id) }
        selectedIDs = Set(visibleItems.prefix(1).map(\.id))
    }

    func pinSelected(to boardID: String) {
        for id in selectedIDs {
            db.pin(id, to: boardID)
            if let index = items.firstIndex(where: { $0.id == id }), !items[index].pinboardIDs.contains(boardID) {
                items[index].pinboardIDs.append(boardID)
            }
        }
    }

    func unpinSelected(from boardID: String) {
        for id in selectedIDs {
            db.unpin(id, from: boardID)
            if let index = items.firstIndex(where: { $0.id == id }) {
                items[index].pinboardIDs.removeAll { $0 == boardID }
            }
        }
        if case .board(let current) = selection, current == boardID {
            selectedIDs = Set(visibleItems.prefix(1).map(\.id))
        }
    }

    func createBoard(name: String, colorHex: String) {
        let board = Pinboard(
            id: UUID().uuidString,
            name: name.isEmpty ? L10n.newPinboard : name,
            colorHex: colorHex,
            sortOrder: (boards.map(\.sortOrder).max() ?? -1) + 1
        )
        db.insertBoard(board)
        boards.append(board)
        selection = .board(board.id)
        creatingBoard = false
    }

    func renameBoard(_ board: Pinboard, to name: String) {
        var updated = board
        updated.name = name
        db.insertBoard(updated)
        if let index = boards.firstIndex(where: { $0.id == board.id }) {
            boards[index] = updated
        }
    }

    func deleteBoard(_ board: Pinboard) {
        db.deleteBoard(id: board.id)
        boards.removeAll { $0.id == board.id }
        for i in items.indices {
            items[i].pinboardIDs.removeAll { $0 == board.id }
        }
        selection = .history
    }

    func selectNext() {
        moveSelection(by: 1)
    }

    func selectPrevious() {
        moveSelection(by: -1)
    }

    func selectIndex(_ index: Int) {
        let visible = visibleItems
        guard visible.indices.contains(index) else { return }
        selectedIDs = [visible[index].id]
    }

    func extendSelection(by offset: Int) {
        let visible = visibleItems
        guard let current = selectedItem, let index = visible.firstIndex(of: current) else { return }
        let next = max(0, min(visible.count - 1, index + offset))
        selectedIDs.insert(visible[next].id)
    }

    func createTextItem(text: String) {
        let item = ClipItem(
            id: UUID().uuidString,
            createdAt: Date(),
            kind: ClipCapture.classify(text: text),
            title: ClipCapture.title(for: text, kind: ClipCapture.classify(text: text)),
            text: text,
            html: "",
            url: ClipCapture.detectURL(text) ?? "",
            colorHex: ClipCapture.detectColor(text) ?? "",
            imagePath: "",
            thumbnailPath: "",
            filePaths: [],
            sourceApp: L10n.appName,
            sourceBundle: "app.local.clip",
            ocrText: "",
            inHistory: true,
            pinboardIDs: []
        )
        add(item)
        editingItem = item
    }

    func clearHistory() {
        db.clearHistory()
        reload()
    }

    func updateOCR(id: String, text: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].ocrText = text
        db.update(items[index])
    }

    func prune() {
        guard let interval = AppSettings.shared.retention.interval else { return }
        db.expireHistory(olderThan: Date().addingTimeInterval(-interval))
        reload()
    }

    func selectBoard(offset: Int) {
        var list: [Selection] = [.history]
        list.append(contentsOf: boards.map { .board($0.id) })
        guard let index = list.firstIndex(of: selection) else { return }
        let next = (index + offset + list.count) % list.count
        selection = list[next]
        selectedIDs = Set(visibleItems.prefix(1).map(\.id))
    }

    private func moveSelection(by offset: Int) {
        let visible = visibleItems
        guard !visible.isEmpty else { return }
        let current = selectedItem.flatMap { visible.firstIndex(of: $0) } ?? 0
        let next = max(0, min(visible.count - 1, current + offset))
        selectedIDs = [visible[next].id]
    }

    private func seedWelcomeClips() {
        let samples: [(ClipKind, String, String)] = [
            (.text, L10n.appName, L10n.welcomeBody),
            (.link, "pasteapp.io", "https://pasteapp.io/"),
            (.color, "#7C5CFC", "#7C5CFC"),
            (.code, "greet.swift", "func greet(_ name: String) {\n    print(\"Hello, \\(name)\")\n}\n"),
        ]
        for (offset, sample) in samples.enumerated() {
            let item = ClipItem(
                id: UUID().uuidString,
                createdAt: Date().addingTimeInterval(TimeInterval(-offset)),
                kind: sample.0,
                title: ClipCapture.title(for: sample.2, kind: sample.0),
                text: sample.2,
                html: "",
                url: sample.0 == .link ? sample.2 : "",
                colorHex: sample.0 == .color ? sample.2 : "",
                imagePath: "",
                thumbnailPath: "",
                filePaths: [],
                sourceApp: L10n.appName,
                sourceBundle: "app.local.clip",
                ocrText: "",
                inHistory: true,
                pinboardIDs: []
            )
            db.insert(item)
            items.append(item)
        }
        items.sort { $0.createdAt > $1.createdAt }
        selectedIDs = Set(items.prefix(1).map(\.id))
    }

    private func isDuplicate(_ a: ClipItem, _ b: ClipItem) -> Bool {
        a.kind == b.kind
            && a.text == b.text
            && a.url == b.url
            && a.colorHex == b.colorHex
            && a.imagePath.isEmpty == b.imagePath.isEmpty
            && a.filePaths == b.filePaths
            && (a.kind != .image || sameFile(a.imagePath, b.imagePath))
    }

    private func sameFile(_ a: String, _ b: String) -> Bool {
        guard !a.isEmpty, !b.isEmpty else { return a == b }
        guard let x = try? Data(contentsOf: URL(fileURLWithPath: a)),
              let y = try? Data(contentsOf: URL(fileURLWithPath: b)) else { return false }
        return x == y
    }
}
