import AppKit

@MainActor
final class ThemeManager {
    static let shared = ThemeManager()
    private var observer: NSObjectProtocol?

    func start() {
        guard observer == nil else { return }
        sync()
        observer = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChanged"),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.sync()
            }
        }
    }

    private func sync() {
        let match = NSApp?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        OpenCoordinator.shared.isDark = (match == NSAppearance.Name.darkAqua)
    }
}
