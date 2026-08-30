import SwiftUI
import AppKit

struct ClipCard: View {
    let item: ClipItem
    let selected: Bool
    let compact: Bool
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if !compact {
                footer
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(selected ? 0.12 : 0.07))
        )
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(item.kind.accent)
                .frame(height: 3)
                .padding(.horizontal, 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(selected ? item.kind.accent.opacity(0.9) : Color.white.opacity(0.08), lineWidth: selected ? 2 : 1)
        }
        .shadow(color: .black.opacity(selected ? 0.28 : 0.12), radius: selected ? 12 : 6, y: 4)
        .contextMenu { contextMenu }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(nsImage: AppIconCache.icon(bundleID: item.sourceBundle, fallbackName: item.sourceApp))
                .resizable()
                .interpolation(.high)
                .frame(width: compact ? 14 : 16, height: compact ? 14 : 16)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            Text(item.title.isEmpty ? item.kind.title : item.title)
                .font(.system(size: compact ? 11 : 12, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(.white.opacity(0.92))
            Spacer(minLength: 4)
            if index < 9 {
                Text("⌘\(index + 1)")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.38))
            }
            Text(RelativeTime.string(from: item.createdAt))
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.42))
        }
        .padding(.horizontal, 12)
        .padding(.top, compact ? 10 : 12)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .image:
            if let image = item.thumbnail {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }
        case .color:
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(item.swiftColor ?? item.kind.accent)
                Text(item.colorHex.uppercased())
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(contrastingForeground(item.swiftColor))
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        case .file:
            VStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(item.kind.accent)
                Text(item.footer)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.86))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(10)
        case .link:
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(item.kind.accent)
                Text(item.url.isEmpty ? item.text : item.url)
                    .font(.system(size: compact ? 12 : 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(compact ? 3 : 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        case .code:
            Text(item.text)
                .font(.system(size: compact ? 10.5 : 11.5, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        case .text:
            Text(item.text)
                .font(.system(size: compact ? 12 : 13))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
    }

    private var footer: some View {
        HStack {
            Image(systemName: item.kind.symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(item.kind.accent)
            Text(item.footer)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.48))
                .lineLimit(1)
            Spacer()
            if !item.pinboardIDs.isEmpty {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button(L10n.paste) {
            ClipStore.shared.selectedIDs = [item.id]
            NotificationCenter.default.post(name: .clipPasteRequested, object: nil)
        }
        Button(L10n.pastePlain) {
            ClipStore.shared.selectedIDs = [item.id]
            NotificationCenter.default.post(name: .clipPastePlainRequested, object: nil)
        }
        Button(L10n.copy) {
            ClipStore.shared.selectedIDs = [item.id]
            NotificationCenter.default.post(name: .clipCopyRequested, object: nil)
        }
        Divider()
        Button(L10n.edit) { ClipStore.shared.editingItem = item }
        Button(L10n.rename) { ClipStore.shared.renamingItem = item }
        if item.kind == .link, let url = URL(string: item.url) {
            Button(L10n.openLink) { NSWorkspace.shared.open(url) }
        }
        Divider()
        Menu(L10n.pin) {
            ForEach(ClipStore.shared.boards) { board in
                Button(board.name) {
                    ClipStore.shared.selectedIDs = [item.id]
                    ClipStore.shared.pinSelected(to: board.id)
                }
            }
        }
        if !item.pinboardIDs.isEmpty {
            Menu(L10n.unpin) {
                ForEach(ClipStore.shared.boards.filter { item.pinboardIDs.contains($0.id) }) { board in
                    Button(board.name) {
                        ClipStore.shared.selectedIDs = [item.id]
                        ClipStore.shared.unpinSelected(from: board.id)
                    }
                }
            }
        }
        Divider()
        Button(L10n.delete, role: .destructive) {
            ClipStore.shared.selectedIDs = [item.id]
            ClipStore.shared.deleteSelected()
        }
    }

    private func contrastingForeground(_ color: Color?) -> Color {
        .white
    }
}

extension Notification.Name {
    static let clipPastePlainRequested = Notification.Name("clipPastePlainRequested")
    static let clipCopyRequested = Notification.Name("clipCopyRequested")
}
