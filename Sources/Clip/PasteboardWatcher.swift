import AppKit
import Foundation
import Vision

enum ClipCapture {
    static func classify(text: String) -> ClipKind {
        if detectColor(text) != nil { return .color }
        if detectURL(text) != nil { return .link }
        if looksLikeCode(text) { return .code }
        return .text
    }

    static func title(for text: String, kind: ClipKind) -> String {
        switch kind {
        case .link:
            return URL(string: detectURL(text) ?? text)?.host ?? L10n.link
        case .color:
            return (detectColor(text) ?? text).uppercased()
        case .code:
            return firstLine(text)
        default:
            return firstLine(text)
        }
    }

    static func firstLine(_ text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.count <= 48 { return trimmed }
        return String(trimmed.prefix(48)) + "…"
    }

    static func detectURL(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()) {
            return trimmed
        }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        if let match = detector.firstMatch(in: trimmed, range: range),
           match.range.length == (trimmed as NSString).length,
           let url = match.url {
            return url.absoluteString
        }
        return nil
    }

    static func detectColor(_ text: String) -> String? {
        var raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("#") { raw.removeFirst() }
        if raw.count == 3 || raw.count == 6 || raw.count == 8,
           raw.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains($0) }) {
            if raw.count == 3 {
                let chars = Array(raw)
                raw = "\(chars[0])\(chars[0])\(chars[1])\(chars[1])\(chars[2])\(chars[2])"
            }
            return "#\(raw.uppercased())"
        }
        return nil
    }

    static func looksLikeCode(_ text: String) -> Bool {
        let lines = text.split(whereSeparator: \.isNewline)
        guard lines.count >= 2 else { return false }
        let markers = ["func ", "class ", "import ", "def ", "const ", "let ", "var ", "fn ", "<?php", "#!/", "{", "=>"]
        return markers.contains { text.contains($0) }
    }
}

@MainActor
final class PasteboardWatcher {
    private var changeCount = NSPasteboard.general.changeCount
    private var timer: Timer?
    private var ignoring = false

    func start() {
        changeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func ignoreInternalWrite(_ work: () -> Void) {
        ignoring = true
        work()
        changeCount = NSPasteboard.general.changeCount
        ignoring = false
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount
        guard !ignoring else { return }
        guard !AppSettings.shared.isPaused else { return }

        let source = NSWorkspace.shared.frontmostApplication
        var bundleID = source?.bundleIdentifier ?? ""
        if bundleID == "app.local.clip" {
            bundleID = ""
        }
        if !bundleID.isEmpty, AppSettings.shared.ignoredBundleIDs.contains(bundleID) { return }

        let appName: String
        if bundleID.isEmpty {
            appName = ""
        } else {
            appName = source?.localizedName ?? ""
        }

        guard let item = capture(from: pasteboard, app: source, appName: appName, bundleID: bundleID) else { return }
        ClipStore.shared.add(item)
        if item.kind == .image, !item.imagePath.isEmpty {
            recognizeText(in: item)
        }
    }

    private func capture(from pasteboard: NSPasteboard, app: NSRunningApplication?, appName: String, bundleID: String) -> ClipItem? {
        let id = UUID().uuidString
        let folder = Paths.clipFolder(id)

        if let image = firstImage(from: pasteboard), let paths = ClipImageStore.persist(image, in: folder) {
            return makeImageItem(
                id: id,
                appName: appName,
                bundleID: bundleID,
                imagePath: paths.imagePath,
                thumbnailPath: paths.thumbnailPath
            )
        }

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty,
           urls.allSatisfy(\.isFileURL) {
            if urls.allSatisfy({ ClipImageStore.isImageFile($0.path) }),
               let first = urls.first,
               let image = NSImage(contentsOf: first),
               let paths = ClipImageStore.persist(image, in: folder) {
                return makeImageItem(
                    id: id,
                    appName: appName,
                    bundleID: bundleID,
                    imagePath: paths.imagePath,
                    thumbnailPath: paths.thumbnailPath,
                    filePaths: urls.map(\.path)
                )
            }
            let names = urls.map(\.lastPathComponent).joined(separator: ", ")
            return ClipItem(
                id: id,
                createdAt: Date(),
                kind: .file,
                title: names,
                text: urls.map(\.path).joined(separator: "\n"),
                html: "",
                url: urls.first?.absoluteString ?? "",
                colorHex: "",
                imagePath: "",
                thumbnailPath: "",
                filePaths: urls.map(\.path),
                sourceApp: appName,
                sourceBundle: bundleID,
                ocrText: "",
                inHistory: true,
                pinboardIDs: []
            )
        }

        let html = pasteboard.string(forType: .html) ?? ""
        let text = pasteboard.string(forType: .string)
            ?? pasteboard.string(forType: .rtf).flatMap { rtf in
                NSAttributedString(rtf: Data(rtf.utf8), documentAttributes: nil)?.string
            }
            ?? ""
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let kind = ClipCapture.classify(text: trimmed)
        return ClipItem(
            id: id,
            createdAt: Date(),
            kind: kind,
            title: ClipCapture.title(for: trimmed, kind: kind),
            text: text,
            html: html,
            url: ClipCapture.detectURL(trimmed) ?? "",
            colorHex: ClipCapture.detectColor(trimmed) ?? "",
            imagePath: "",
            thumbnailPath: "",
            filePaths: [],
            sourceApp: appName,
            sourceBundle: bundleID,
            ocrText: "",
            inHistory: true,
            pinboardIDs: []
        )
    }

    private func makeImageItem(
        id: String,
        appName: String,
        bundleID: String,
        imagePath: String,
        thumbnailPath: String,
        filePaths: [String] = []
    ) -> ClipItem {
        ClipItem(
            id: id,
            createdAt: Date(),
            kind: .image,
            title: appName.isEmpty ? L10n.image : appName,
            text: "",
            html: "",
            url: "",
            colorHex: "",
            imagePath: imagePath,
            thumbnailPath: thumbnailPath,
            filePaths: filePaths,
            sourceApp: appName,
            sourceBundle: bundleID,
            ocrText: "",
            inHistory: true,
            pinboardIDs: []
        )
    }

    private func firstImage(from pasteboard: NSPasteboard) -> NSImage? {
        let types: [NSPasteboard.PasteboardType] = [
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.jpeg-2000"),
            NSPasteboard.PasteboardType("public.gif"),
            NSPasteboard.PasteboardType("public.heic"),
            NSPasteboard.PasteboardType("public.heif"),
        ]
        for type in types {
            if let data = pasteboard.data(forType: type),
               let image = NSImage(data: data),
               isSubstantial(image) {
                return image
            }
        }
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first,
           isSubstantial(image) {
            return image
        }
        return nil
    }

    private func isSubstantial(_ image: NSImage) -> Bool {
        var rect = NSRect(origin: .zero, size: image.size)
        if let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            return cg.width >= 32 && cg.height >= 32
        }
        return image.size.width >= 32 && image.size.height >= 32
    }

    private func recognizeText(in item: ClipItem) {
        let path = item.imagePath
        let id = item.id
        DispatchQueue.global(qos: .utility).async {
            guard let image = NSImage(contentsOfFile: path),
                  let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            try? handler.perform([request])
            let text = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
            guard !text.isEmpty else { return }
            DispatchQueue.main.async {
                ClipStore.shared.updateOCR(id: id, text: text)
            }
        }
    }
}
