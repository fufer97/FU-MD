import SwiftUI
import AppKit

@main
struct FUMDApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "editor") {
            EditorWindowView()
                .frame(minWidth: 680, minHeight: 440)
        }
        .commands { AppCommands() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            let target = url
            Task { @MainActor in
                OpenCoordinator.shared.requestOpen(target)
            }
        }
    }
}

@MainActor
final class EditorContext: ObservableObject {
    let store = DocumentStore()
    let bridge: EditorBridge

    init() {
        let b = EditorBridge(store: store)
        self.bridge = b
        store.bridge = b
    }
}

struct EditorWindowView: View {
    @StateObject private var ctx = EditorContext()

    var body: some View {
        EditorContent(store: ctx.store, bridge: ctx.bridge)
    }
}

private struct EditorContent: View {
    @ObservedObject var store: DocumentStore
    let bridge: EditorBridge
    @ObservedObject private var coord = OpenCoordinator.shared

    private var editorBackground: Color {
        coord.isDark ? Color(red: 0.118, green: 0.118, blue: 0.118) : .white
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if coord.showOutline {
                    OutlineSidebar(store: store)
                        .frame(width: 200)
                    Divider()
                }
                EditorWebView(bridge: bridge)
            }
            .background(editorBackground)
            Divider()
            StatusBarView(store: store)
                .background(editorBackground)
        }
        .background(WindowConfigurator(store: store))
        .background(OpenWindowCapture())
        .navigationTitle(store.displayName)
        .onAppear {
            ThemeManager.shared.start()
            if let url = coord.claimPendingForNewWindow() {
                store.load(url: url)
            }
            store.refreshCandidateState()
        }
        .onReceive(coord.$isDark.dropFirst()) { dark in
            bridge.setTheme(dark: dark)
        }
    }
}

struct OpenWindowCapture: View {
    @Environment(\.openWindow) private var action

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear { OpenCoordinator.shared.openWindowAction = action }
    }
}

struct WindowConfigurator: NSViewRepresentable {
    let store: DocumentStore

    private final class ProbeView: NSView {
        var onWindow: ((NSWindow?) -> Void)?
        override func viewDidMoveToWindow() {
            onWindow?(window)
        }
    }

    func makeNSView(context: Context) -> NSView {
        let view = ProbeView()
        view.onWindow = { [store] window in
            guard let window else { return }
            let closeGuard = CloseGuard(store: store)
            objc_setAssociatedObject(window, &WindowConfigurator.assocKey, closeGuard, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            closeGuard.attach(to: window)
            window.delegate = closeGuard
            OpenCoordinator.shared.register(window: window, store: store)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    static var assocKey: UInt8 = 0
}
