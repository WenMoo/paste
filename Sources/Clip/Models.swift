import AppKit
import SwiftUI

enum ClipKind: String, CaseIterable, Codable, Hashable {
    case text
    case link
    case image
    case color
    case file
    case code

    var title: String {
        switch self {
        case .text: L10n.text
        case .link: L10n.link
        case .image: L10n.image
        case .color: L10n.color
        case .file: L10n.file
        case .code: L10n.code
        }
    }

    var symbol: String {
        switch self {
        case .text: "text.alignleft"
        case .link: "link"
        case .image: "photo"
        case .color: "drop.fill"
        case .file: "doc"
        case .code: "chevron.left.forwardslash.chevron.right"
        }
    }

    var accent: Color {
        switch self {
        case .text: Color(red: 0.33, green: 0.55, blue: 0.98)
        case .link: Color(red: 0.64, green: 0.42, blue: 0.98)
        case .image: Color(red: 0.98, green: 0.52, blue: 0.32)
        case .color: Color(red: 0.98, green: 0.36, blue: 0.48)
        case .file: Color(red: 0.32, green: 0.76, blue: 0.52)
        case .code: Color(red: 0.18, green: 0.78, blue: 0.76)
        }
    }
}

struct ClipItem: Identifiable, Hashable {
    var id: String
    var createdAt: Date
    var kind: ClipKind
    var title: String
    var text: String
    var html: String
    var url: String
    var colorHex: String
    var imagePath: String
    var thumbnailPath: String
    var filePaths: [String]
    var sourceApp: String
    var sourceBundle: String
    var ocrText: String
    var inHistory: Bool
    var pinboardIDs: [String]

    var previewText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if !url.isEmpty { return url }
        if !colorHex.isEmpty { return colorHex }
        if !filePaths.isEmpty { return filePaths.map { ($0 as NSString).lastPathComponent }.joined(separator: ", ") }
        return title
    }

    var footer: String {
        switch kind {
        case .text, .code:
            let count = text.count
            return "\(count) \(L10n.characters)"
        case .link:
            return URL(string: url)?.host ?? url
        case .image:
            return sourceApp.isEmpty ? L10n.image : sourceApp
        case .color:
            return colorHex.uppercased()
        case .file:
            if filePaths.count == 1 {
                return (filePaths[0] as NSString).lastPathComponent
            }
            return "\(filePaths.count) \(L10n.file)"
        }
    }

    var swiftColor: Color? {
        Color(hex: colorHex)
    }

    var thumbnail: NSImage? {
        if !thumbnailPath.isEmpty, let image = NSImage(contentsOfFile: thumbnailPath) {
            return image
        }
        if !imagePath.isEmpty {
            return NSImage(contentsOfFile: imagePath)
        }
        return nil
    }
}

struct Pinboard: Identifiable, Hashable {
    var id: String
    var name: String
    var colorHex: String
    var sortOrder: Int

    var color: Color {
        Color(hex: colorHex) ?? ClipKind.link.accent
    }
}

enum HistoryRetention: String, CaseIterable, Identifiable {
    case days7
    case days30
    case days90
    case forever

    var id: String { rawValue }

    var title: String {
        switch self {
        case .days7: L10n.days7
        case .days30: L10n.days30
        case .days90: L10n.days90
        case .forever: L10n.forever
        }
    }

    var interval: TimeInterval? {
        switch self {
        case .days7: 7 * 24 * 3600
        case .days30: 30 * 24 * 3600
        case .days90: 90 * 24 * 3600
        case .forever: nil
        }
    }
}

enum FilterKind: Hashable {
    case all
    case kind(ClipKind)

    var title: String {
        switch self {
        case .all: L10n.all
        case .kind(let kind): kind.title
        }
    }
}

extension Color {
    init?(hex: String) {
        var raw = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if raw.hasPrefix("#") { raw.removeFirst() }
        guard raw.count == 6 || raw.count == 8 else { return nil }
        var value: UInt64 = 0
        guard Scanner(string: raw).scanHexInt64(&value) else { return nil }
        let r, g, b, a: Double
        if raw.count == 8 {
            a = Double((value & 0xFF000000) >> 24) / 255
            r = Double((value & 0x00FF0000) >> 16) / 255
            g = Double((value & 0x0000FF00) >> 8) / 255
            b = Double(value & 0x000000FF) / 255
        } else {
            a = 1
            r = Double((value & 0xFF0000) >> 16) / 255
            g = Double((value & 0x00FF00) >> 8) / 255
            b = Double(value & 0x0000FF) / 255
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

enum Paths {
    static var support: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Clip", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var clips: URL {
        let url = support.appendingPathComponent("Clips", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var database: URL {
        support.appendingPathComponent("clip.sqlite")
    }

    static func clipFolder(_ id: String) -> URL {
        let url = clips.appendingPathComponent(id, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

enum RelativeTime {
    static func string(from date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 45 { return L10n.justNow }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

@MainActor
enum AppIconCache {
    private static var cache: [String: NSImage] = [:]

    static func icon(bundleID: String, fallbackName: String) -> NSImage {
        if let cached = cache[bundleID] { return cached }
        if !bundleID.isEmpty,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            cache[bundleID] = icon
            return icon
        }
        if !fallbackName.isEmpty {
            let icon = NSImage(size: NSSize(width: 32, height: 32))
            cache[bundleID] = icon
            return icon
        }
        let fallback = NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
        return fallback
    }
}
