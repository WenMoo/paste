import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class Database {
    private var db: OpaquePointer?

    init(url: URL) {
        if sqlite3_open_v2(
            url.path,
            &db,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        ) != SQLITE_OK {
            fatalError("Unable to open Clip database")
        }
        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA foreign_keys=ON;", nil, nil, nil)
        migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    private func migrate() {
        exec("""
        CREATE TABLE IF NOT EXISTS clips (
            id TEXT PRIMARY KEY,
            created_at REAL NOT NULL,
            kind TEXT NOT NULL,
            title TEXT NOT NULL DEFAULT '',
            text_content TEXT NOT NULL DEFAULT '',
            html_content TEXT NOT NULL DEFAULT '',
            url TEXT NOT NULL DEFAULT '',
            color_hex TEXT NOT NULL DEFAULT '',
            image_path TEXT NOT NULL DEFAULT '',
            thumbnail_path TEXT NOT NULL DEFAULT '',
            file_paths TEXT NOT NULL DEFAULT '[]',
            source_app TEXT NOT NULL DEFAULT '',
            source_bundle TEXT NOT NULL DEFAULT '',
            ocr_text TEXT NOT NULL DEFAULT '',
            in_history INTEGER NOT NULL DEFAULT 1
        );
        CREATE TABLE IF NOT EXISTS pinboards (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            color_hex TEXT NOT NULL,
            sort_order INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS clip_pinboards (
            clip_id TEXT NOT NULL,
            pinboard_id TEXT NOT NULL,
            PRIMARY KEY (clip_id, pinboard_id)
        );
        CREATE VIRTUAL TABLE IF NOT EXISTS clips_fts USING fts5(
            id UNINDEXED,
            title,
            text_content,
            url,
            ocr_text,
            source_app
        );
        CREATE INDEX IF NOT EXISTS clips_created_at ON clips(created_at DESC);
        """)
    }

    func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    func insert(_ item: ClipItem) {
        let sql = """
        INSERT OR REPLACE INTO clips
        (id, created_at, kind, title, text_content, html_content, url, color_hex, image_path, thumbnail_path, file_paths, source_app, source_bundle, ocr_text, in_history)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, item.id)
        sqlite3_bind_double(stmt, 2, item.createdAt.timeIntervalSince1970)
        bind(stmt, 3, item.kind.rawValue)
        bind(stmt, 4, item.title)
        bind(stmt, 5, item.text)
        bind(stmt, 6, item.html)
        bind(stmt, 7, item.url)
        bind(stmt, 8, item.colorHex)
        bind(stmt, 9, item.imagePath)
        bind(stmt, 10, item.thumbnailPath)
        bind(stmt, 11, (try? String(data: JSONEncoder().encode(item.filePaths), encoding: .utf8)) ?? "[]")
        bind(stmt, 12, item.sourceApp)
        bind(stmt, 13, item.sourceBundle)
        bind(stmt, 14, item.ocrText)
        sqlite3_bind_int(stmt, 15, item.inHistory ? 1 : 0)
        sqlite3_step(stmt)
        exec("DELETE FROM clips_fts WHERE id = '\(item.id)';")
        insertFTS(item)
        for boardID in item.pinboardIDs {
            pin(item.id, to: boardID)
        }
    }

    func update(_ item: ClipItem) {
        insert(item)
    }

    func delete(id: String) {
        exec("DELETE FROM clip_pinboards WHERE clip_id = '\(id)';")
        exec("DELETE FROM clips_fts WHERE id = '\(id)';")
        exec("DELETE FROM clips WHERE id = '\(id)';")
        try? FileManager.default.removeItem(at: Paths.clipFolder(id))
    }

    func pin(_ clipID: String, to boardID: String) {
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "INSERT OR IGNORE INTO clip_pinboards (clip_id, pinboard_id) VALUES (?, ?);", -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, clipID)
        bind(stmt, 2, boardID)
        sqlite3_step(stmt)
    }

    func unpin(_ clipID: String, from boardID: String) {
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "DELETE FROM clip_pinboards WHERE clip_id = ? AND pinboard_id = ?;", -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, clipID)
        bind(stmt, 2, boardID)
        sqlite3_step(stmt)
    }

    func insertBoard(_ board: Pinboard) {
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "INSERT OR REPLACE INTO pinboards (id, name, color_hex, sort_order) VALUES (?, ?, ?, ?);", -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, board.id)
        bind(stmt, 2, board.name)
        bind(stmt, 3, board.colorHex)
        sqlite3_bind_int(stmt, 4, Int32(board.sortOrder))
        sqlite3_step(stmt)
    }

    func deleteBoard(id: String) {
        exec("DELETE FROM clip_pinboards WHERE pinboard_id = '\(id)';")
        exec("DELETE FROM pinboards WHERE id = '\(id)';")
    }

    func expireHistory(olderThan date: Date) {
        let sql = "UPDATE clips SET in_history = 0 WHERE in_history = 1 AND created_at < ? AND id NOT IN (SELECT clip_id FROM clip_pinboards);"
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, date.timeIntervalSince1970)
        sqlite3_step(stmt)
        exec("DELETE FROM clips WHERE in_history = 0 AND id NOT IN (SELECT clip_id FROM clip_pinboards);")
    }

    func clearHistory() {
        let ids = query("SELECT id FROM clips WHERE in_history = 1 AND id NOT IN (SELECT clip_id FROM clip_pinboards);").compactMap { $0["id"] }
        exec("UPDATE clips SET in_history = 0 WHERE id NOT IN (SELECT clip_id FROM clip_pinboards);")
        for id in ids {
            exec("DELETE FROM clips_fts WHERE id = '\(id)';")
            exec("DELETE FROM clips WHERE id = '\(id)';")
            try? FileManager.default.removeItem(at: Paths.clipFolder(id))
        }
    }

    func allClips() -> [ClipItem] {
        let rows = query("""
        SELECT c.*, IFNULL(group_concat(cp.pinboard_id, ','), '') AS boards
        FROM clips c
        LEFT JOIN clip_pinboards cp ON c.id = cp.clip_id
        GROUP BY c.id
        ORDER BY c.created_at DESC
        """)
        return rows.compactMap(clip(from:))
    }

    func allBoards() -> [Pinboard] {
        query("SELECT * FROM pinboards ORDER BY sort_order ASC, name ASC").compactMap { row in
            guard let id = row["id"], let name = row["name"] else { return nil }
            return Pinboard(
                id: id,
                name: name,
                colorHex: row["color_hex"] ?? "#7C5CFC",
                sortOrder: Int(row["sort_order"] ?? "0") ?? 0
            )
        }
    }

    func search(_ text: String) -> [String] {
        let like = "%\(text)%"
        return query(
            "SELECT id FROM clips WHERE text_content LIKE ? OR title LIKE ? OR url LIKE ? OR ocr_text LIKE ? OR source_app LIKE ? ORDER BY created_at DESC",
            like, like, like, like, like
        ).compactMap { $0["id"] }
    }

    private func insertFTS(_ item: ClipItem) {
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(
            db,
            "INSERT INTO clips_fts (id, title, text_content, url, ocr_text, source_app) VALUES (?, ?, ?, ?, ?, ?);",
            -1,
            &stmt,
            nil
        )
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, item.id)
        bind(stmt, 2, item.title)
        bind(stmt, 3, item.text)
        bind(stmt, 4, item.url)
        bind(stmt, 5, item.ocrText)
        bind(stmt, 6, item.sourceApp)
        sqlite3_step(stmt)
    }

    private func clip(from row: [String: String]) -> ClipItem? {
        guard let id = row["id"] else { return nil }
        let paths = (try? JSONDecoder().decode([String].self, from: Data((row["file_paths"] ?? "[]").utf8))) ?? []
        let boards = (row["boards"] ?? "").split(separator: ",").map(String.init).filter { !$0.isEmpty }
        return ClipItem(
            id: id,
            createdAt: Date(timeIntervalSince1970: Double(row["created_at"] ?? "0") ?? 0),
            kind: ClipKind(rawValue: row["kind"] ?? "text") ?? .text,
            title: row["title"] ?? "",
            text: row["text_content"] ?? "",
            html: row["html_content"] ?? "",
            url: row["url"] ?? "",
            colorHex: row["color_hex"] ?? "",
            imagePath: row["image_path"] ?? "",
            thumbnailPath: row["thumbnail_path"] ?? "",
            filePaths: paths,
            sourceApp: row["source_app"] ?? "",
            sourceBundle: row["source_bundle"] ?? "",
            ocrText: row["ocr_text"] ?? "",
            inHistory: (row["in_history"] ?? "1") != "0",
            pinboardIDs: boards
        )
    }

    private func bind(_ stmt: OpaquePointer?, _ index: Int32, _ value: String) {
        sqlite3_bind_text(stmt, index, value, -1, SQLITE_TRANSIENT)
    }

    private func query(_ sql: String, _ args: String...) -> [[String: String]] {
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        for (i, arg) in args.enumerated() {
            bind(stmt, Int32(i + 1), arg)
        }
        var rows: [[String: String]] = []
        let count = sqlite3_column_count(stmt)
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: String] = [:]
            for i in 0..<count {
                let name = String(cString: sqlite3_column_name(stmt, i))
                if sqlite3_column_type(stmt, i) == SQLITE_NULL { continue }
                if let text = sqlite3_column_text(stmt, i) {
                    row[name] = String(cString: text)
                } else if sqlite3_column_type(stmt, i) == SQLITE_FLOAT {
                    row[name] = String(sqlite3_column_double(stmt, i))
                } else if sqlite3_column_type(stmt, i) == SQLITE_INTEGER {
                    row[name] = String(sqlite3_column_int64(stmt, i))
                }
            }
            rows.append(row)
        }
        return rows
    }
}
