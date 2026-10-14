import AppKit
import Combine
import UniformTypeIdentifiers

extension UTType {
    static let markdown = UTType(importedAs: "net.daringfireball.markdown")
}

struct TextStats: Equatable {
    var characters = 0
    var words = 0
    var lines = 0
}

struct OutlineItem: Identifiable, Equatable {
    let id = UUID()
    let index: Int
    let level: Int
    let text: String
}

@MainActor
final class DocumentStore: ObservableObject {
    @Published private(set) var fileURL: URL?
    @Published private(set) var isDirty = false
    @Published private(set) var markdown = ""
    @Published var stats = TextStats()
    @Published var outline: [OutlineItem] = []

    weak var bridge: EditorBridge?

    var displayName: String { fileURL?.lastPathComponent ?? "未命名" }
    var isCleanEmpty: Bool { fileURL == nil && !isDirty && markdown.isEmpty }

    func load(url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            let alert = NSAlert()
            alert.messageText = "无法打开文件"
            alert.informativeText = url.path
            alert.runModal()
            return
        }
        fileURL = url
        markdown = content
        isDirty = false
        bridge?.setValue(content)
        noteRecent(url)
        refreshCandidateState()
        // 由文档启动时 SwiftUI 不会把窗口置前，这里补一次（只影响装着文档的窗口）
        OpenCoordinator.shared.bringToFront(store: self)
    }

    func newDocument() {
        fileURL = nil
        markdown = ""
        isDirty = false
        bridge?.setValue("")
        refreshCandidateState()
    }

    func contentChanged(_ md: String) {
        if md != markdown {
            markdown = md
            isDirty = true
        }
        refreshCandidateState()
    }

    @discardableResult
    func save() async -> Bool {
        if let url = fileURL {
            return await write(to: url)
        }
        return await saveAs()
    }

    @discardableResult
    func saveAs() async -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.markdown]
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "未命名.md"
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        if await write(to: url) {
            fileURL = url
            refreshCandidateState()
            return true
        }
        return false
    }

    private func write(to url: URL) async -> Bool {
        guard let bridge else { return false }
        guard let md = await bridge.getValue() else {
            let alert = NSAlert()
            alert.messageText = "无法读取编辑器内容"
            alert.runModal()
            return false
        }
        do {
            try md.write(to: url, atomically: true, encoding: .utf8)
            markdown = md
            isDirty = false
            noteRecent(url)
            refreshCandidateState()
            return true
        } catch {
            NSAlert(error: error).runModal()
            return false
        }
    }

    private func noteRecent(_ url: URL) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    func refreshCandidateState() {
        if isCleanEmpty {
            OpenCoordinator.shared.noteCandidate(self)
        } else {
            OpenCoordinator.shared.clearCandidate(self)
        }
    }
}

@MainActor
final class CloseGuard: NSObject, NSWindowDelegate {
    let store: DocumentStore
    private var cancellables = Set<AnyCancellable>()

    init(store: DocumentStore) {
        self.store = store
        super.init()
    }

    func attach(to window: NSWindow) {
        window.isDocumentEdited = store.isDirty
        store.$isDirty
            .receive(on: DispatchQueue.main)
            .sink { window.isDocumentEdited = $0 }
            .store(in: &cancellables)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard store.isDirty else { return true }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "“\(store.displayName)”有未存储的更改"
        alert.informativeText = "不存储的话，这些更改将会丢失。"
        alert.addButton(withTitle: "存储")
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "不存储")
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            Task { @MainActor in
                if await store.save() {
                    sender.close()
                }
            }
            return false
        case .alertThirdButtonReturn:
            return true
        default:
            return false
        }
    }
}
