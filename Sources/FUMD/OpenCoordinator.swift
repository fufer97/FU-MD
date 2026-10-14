import AppKit
import SwiftUI

struct WeakRef<T: AnyObject> {
    weak var value: T?
    init(_ value: T) { self.value = value }
}

@MainActor
final class OpenCoordinator: ObservableObject {
    static let shared = OpenCoordinator()

    var openWindowAction: OpenWindowAction?
    @Published var showOutline = false
    @Published var isDark: Bool = false

    private var pendingForNewWindow: URL?
    private var candidates: [WeakRef<DocumentStore>] = []
    private var windowStores: [(window: WeakRef<NSWindow>, store: WeakRef<DocumentStore>)] = []

    func requestOpen(_ url: URL) {
        if let store = availableCandidate() {
            store.load(url: url)
            return
        }
        pendingForNewWindow = url
        openWindowAction?(id: "editor")
    }

    func claimPendingForNewWindow() -> URL? {
        defer { pendingForNewWindow = nil }
        return pendingForNewWindow
    }

    private func availableCandidate() -> DocumentStore? {
        candidates.first { $0.value?.isCleanEmpty == true }?.value
    }

    func noteCandidate(_ store: DocumentStore) {
        if !candidates.contains(where: { $0.value === store }) {
            candidates.append(WeakRef(store))
        }
    }

    func clearCandidate(_ store: DocumentStore) {
        candidates.removeAll { $0.value === store }
    }

    func register(window: NSWindow, store: DocumentStore) {
        windowStores.removeAll { $0.window.value == nil || $0.store.value == nil }
        windowStores.append((WeakRef(window), WeakRef(store)))
    }

    func activeStore() -> DocumentStore? {
        windowStores.removeAll { $0.window.value == nil || $0.store.value == nil }
        if let key = NSApp.keyWindow,
           let pair = windowStores.first(where: { $0.window.value === key }) {
            return pair.store.value
        }
        return windowStores.last?.store.value
    }

    /// 把装着某个文档的窗口提到最前。
    ///
    /// 由文档启动（Finder 双击 / `open foo.md`）时，SwiftUI 会把窗口创建出来却不置前，
    /// 窗口的 `isVisible` 一直是 false —— 用户只看到菜单栏切到 FU MD、没有窗口出现。
    /// 这里只针对「装到了文档」的那个窗口补前置（窗口注册可能略晚于加载，故带重试）；
    /// 空窗口不在此列，避免多弹一个空的「未命名」。
    func bringToFront(store: DocumentStore, attempts: Int = 6) {
        windowStores.removeAll { $0.window.value == nil || $0.store.value == nil }
        if let pair = windowStores.first(where: { $0.store.value === store }), let window = pair.window.value {
            guard !window.isVisible else { return }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        guard attempts > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.bringToFront(store: store, attempts: attempts - 1)
        }
    }
}
