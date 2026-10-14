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
}
