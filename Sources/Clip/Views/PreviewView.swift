import SwiftUI
import AppKit

struct PreviewOverlay: View {
    let item: ClipItem

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    ClipStore.shared.previewItemID = nil
                }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(item.title.isEmpty ? item.kind.title : item.title)
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text(RelativeTime.string(from: item.createdAt))
                        .foregroundStyle(.secondary)
                    Button {
                        ClipStore.shared.previewItemID = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Group {
                    switch item.kind {
                    case .image:
                        if let image = item.displayImage {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 420)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    case .color:
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(item.swiftColor ?? item.kind.accent)
                            .frame(height: 180)
                            .overlay {
                                Text(item.colorHex.uppercased())
                                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                            }
                    default:
                        ScrollView {
                            Text(item.text.isEmpty ? item.previewText : item.text)
                                .font(item.kind == .code ? .system(size: 13, design: .monospaced) : .system(size: 14))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                }

                if !item.ocrText.isEmpty {
                    Text(item.ocrText)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                }

                HStack {
                    Text(item.footer)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !item.sourceApp.isEmpty {
                        Text(item.sourceApp)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 12))
            }
            .padding(20)
            .frame(maxWidth: 720, maxHeight: 520)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
            .padding(32)
        }
    }
}

struct NewBoardOverlay: View {
    @State private var name = ""
    @State private var color = "7C5CFC"
    private let colors = ["7C5CFC", "3D8BFF", "2FCB7A", "F5A524", "F05252", "F062C0", "2EC4B6", "9AA4B2"]

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .onTapGesture { ClipStore.shared.creatingBoard = false }
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.newPinboard)
                    .font(.system(size: 16, weight: .semibold))
                TextField(L10n.pinboardName, text: $name)
                    .textFieldStyle(.roundedBorder)
                HStack(spacing: 8) {
                    ForEach(colors, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex) ?? .purple)
                            .frame(width: 22, height: 22)
                            .overlay {
                                if color == hex {
                                    Circle().strokeBorder(.white, lineWidth: 2)
                                }
                            }
                            .onTapGesture { color = hex }
                    }
                }
                HStack {
                    Spacer()
                    Button(L10n.cancel) { ClipStore.shared.creatingBoard = false }
                    Button(L10n.create) {
                        ClipStore.shared.createBoard(name: name, colorHex: color)
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(width: 360)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

struct RenameOverlay: View {
    @ObservedObject private var store = ClipStore.shared
    @State private var name = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .onTapGesture { store.renamingItem = nil }
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.rename)
                    .font(.system(size: 16, weight: .semibold))
                TextField(L10n.rename, text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onAppear { name = store.renamingItem?.title ?? "" }
                HStack {
                    Spacer()
                    Button(L10n.cancel) { store.renamingItem = nil }
                    Button(L10n.save) {
                        guard var item = store.renamingItem else { return }
                        item.title = name
                        store.update(item)
                        store.renamingItem = nil
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(width: 360)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

struct EditClipView: View {
    @Environment(\.dismiss) private var dismiss
    @State var item: ClipItem
    @State private var text: String

    init(item: ClipItem) {
        self.item = item
        _text = State(initialValue: item.text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.edit)
                .font(.headline)
            TextField(L10n.rename, text: $item.title)
                .textFieldStyle(.roundedBorder)
            TextEditor(text: $text)
                .font(item.kind == .code ? .system(size: 13, design: .monospaced) : .body)
                .frame(minHeight: 180)
                .overlay {
                    RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.25))
                }
            HStack {
                Spacer()
                Button(L10n.cancel) { dismiss() }
                Button(L10n.save) {
                    var updated = item
                    updated.text = text
                    if updated.kind == .link {
                        updated.url = ClipCapture.detectURL(text) ?? updated.url
                    }
                    if updated.kind == .color {
                        updated.colorHex = ClipCapture.detectColor(text) ?? updated.colorHex
                    }
                    ClipStore.shared.update(updated)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460, height: 320)
    }
}
