import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("打开…") { Self.openPanel() }
                .keyboardShortcut("o")
            Divider()
            Button("保存") { Self.save(asNew: false) }
                .keyboardShortcut("s")
            Button("另存为…") { Self.save(asNew: true) }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            Divider()
            Menu("导出") {
                Button("HTML…") { Self.export(.html) }
                Button("PDF…") { Self.export(.pdf) }
            }
        }
        CommandGroup(after: .sidebar) {
            Button(OpenCoordinator.shared.showOutline ? "隐藏大纲" : "显示大纲") {
                OpenCoordinator.shared.showOutline.toggle()
            }
            .keyboardShortcut("\\")
        }
    }

    static func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.markdown]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        Task { @MainActor in
            for url in urls {
                OpenCoordinator.shared.requestOpen(url)
            }
        }
    }

    static func save(asNew: Bool) {
        guard let store = OpenCoordinator.shared.activeStore() else { return }
        Task { @MainActor in
            if asNew {
                await store.saveAs()
            } else {
                await store.save()
            }
        }
    }

    static func export(_ format: ExportFormat) {
        guard let store = OpenCoordinator.shared.activeStore() else { return }
        Task { @MainActor in
            await ExportService.export(store: store, format: format)
        }
    }
}
