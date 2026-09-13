import SwiftUI
import BeaconKit
import UniformTypeIdentifiers
import QuickLookThumbnailing
import QuickLook

struct CalendarPersonalMedia: View {
    var store: CalendarMediaStore
    let noteKey: String
    @State private var importing = false
    @State private var error: String?
    @State private var previewURL: URL?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(store.files(for: noteKey), id: \.self) { url in
                        CalendarMediaThumbnail(url: url) { previewURL = url }
                            .overlay(alignment: .topLeading) {
                                Button {
                                    NSWorkspace.shared.recycle([url]) { _, failure in
                                        Task { @MainActor in
                                            error = failure?.localizedDescription
                                            store.refresh()
                                        }
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 16, height: 16)
                                        .background(.black.opacity(0.65), in: Circle())
                                        .frame(width: 24, height: 24)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(BeaconControlButtonStyle())
                                .help("Remove attachment · moves Beacon’s copy to Trash")
                                .accessibilityLabel("Remove attachment: \(String(url.lastPathComponent.dropFirst(37)))")
                            }
                            .transaction { $0.animation = nil }
                            .transition(reduceMotion ? .opacity : .offset(y: 6).combined(with: .opacity))
                    }
                    Button(action: chooseFiles) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Palette.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            if importing { ProgressView().controlSize(.small) }
                            else { Image(systemName: "plus").font(.system(size: 16, weight: .light)) }
                        }
                        .foregroundStyle(Palette.secondary)
                        .frame(width: 56, height: 56)
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(BeaconControlButtonStyle()).disabled(importing)
                    .accessibilityLabel("Add photos or videos to personal note")
                    .help("Add photos or videos · stored only on this Mac")
                }.padding(.vertical, 2)
                    .animation(reduceMotion ? nil : BeaconMotion.list, value: store.files(for: noteKey))
            }.scrollIndicators(.hidden)
            if let error { Text(error).font(.system(size: 11)).foregroundStyle(Palette.secondary) }
        }
        .quickLookPreview($previewURL)
    }

    private func chooseFiles() {
        let hostWindow = NSApp.keyWindow ?? NSApp.windows.first { $0.isVisible && $0.canBecomeMain }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .movie]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.prompt = "Add media"
        panel.message = "Saved with your personal note on this Mac."
        let finished: (NSApplication.ModalResponse) -> Void = { response in
            hostWindow?.makeKeyAndOrderFront(nil)
            guard response == .OK else { return }
            let urls = panel.urls
            importing = true
            error = nil
            Task { @MainActor in
                var failures: [String] = []
                for url in urls {
                    do { try await store.add(url, for: noteKey) }
                    catch { failures.append("\(url.lastPathComponent): \(error.localizedDescription)") }
                }
                error = failures.isEmpty ? nil : failures.joined(separator: "\n")
                importing = false
            }
        }
        if let window = hostWindow { panel.beginSheetModal(for: window, completionHandler: finished) }
        else { panel.begin(completionHandler: finished) }
    }
}

private struct CalendarMediaThumbnail: View {
    let url: URL
    let preview: () -> Void
    @State private var thumbnail: NSImage?
    private var name: String { String(url.lastPathComponent.dropFirst(37)) }
    var body: some View {
        Button(action: preview) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Palette.band)
                if let thumbnail {
                    Image(nsImage: thumbnail).resizable().scaledToFill()
                } else {
                    Image(systemName: "photo.on.rectangle").foregroundStyle(Palette.secondary)
                }
            }
            .frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(BeaconControlButtonStyle()).help(name).accessibilityLabel("Preview attachment: \(name)")
        .task(id: url) {
            let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 128, height: 128), scale: 2, representationTypes: .thumbnail)
            thumbnail = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage
        }
    }
}
