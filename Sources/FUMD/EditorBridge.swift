import AppKit
import WebKit

final class BridgeProxy: NSObject, WKScriptMessageHandler {
    weak var target: EditorBridge?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.handle(message: message)
    }
}

@MainActor
final class EditorBridge: NSObject {
    let store: DocumentStore
    private(set) var webView: WKWebView!
    private let proxy = BridgeProxy()
    private var isReady = false
    private var queuedValue: String?

    init(store: DocumentStore) {
        self.store = store
        super.init()
        proxy.target = self
        self.webView = Self.makeWebView(proxy: proxy)
    }

    private static func makeWebView(proxy: BridgeProxy) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.userContentController.add(proxy, name: "fumd")
        let view = WKWebView(frame: .zero, configuration: config)
        view.underPageBackgroundColor = .clear
        if let index = Bundle.module.url(forResource: "index", withExtension: "html",
                                         subdirectory: "Resources/editor") {
            view.loadFileURL(index, allowingReadAccessTo: index.deletingLastPathComponent())
        }
        return view
    }

    // MARK: - JS → Swift

    func handle(message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        switch type {
        case "ready":
            isReady = true
            setTheme(dark: OpenCoordinator.shared.isDark)
            let initial = queuedValue ?? store.markdown
            queuedValue = nil
            if !initial.isEmpty {
                pushValue(initial)
            }
            call("FUMDBridge.focus()")
            requestOutline()
        case "contentChanged":
            if let md = body["markdown"] as? String {
                store.contentChanged(md)
            }
            if let s = body["stats"] as? [String: Any] {
                store.stats = TextStats(
                    characters: s["characters"] as? Int ?? 0,
                    words: s["words"] as? Int ?? 0,
                    lines: s["lines"] as? Int ?? 0
                )
            }
        case "outline":
            if let items = body["items"] as? [[String: Any]] {
                store.outline = items.compactMap { d in
                    guard let level = d["level"] as? Int,
                          let index = d["index"] as? Int,
                          let text = d["text"] as? String else { return nil }
                    return OutlineItem(index: index, level: level, text: text)
                }
            }
        default:
            break
        }
    }

    // MARK: - Swift → JS

    func setValue(_ md: String) {
        guard isReady else {
            queuedValue = md
            return
        }
        pushValue(md)
    }

    private func pushValue(_ md: String) {
        let payload = Self.jsonString(["markdown": md])
        call("FUMDBridge.setValue(\(payload))")
    }

    func getValue() async -> String? {
        guard let result = try? await webView.evaluateJavaScript("FUMDBridge.getValue()") else { return nil }
        return result as? String
    }

    func getHtml() async -> String? {
        guard let result = try? await webView.evaluateJavaScript("FUMDBridge.getHtml()") else { return nil }
        return result as? String
    }

    func setTheme(dark: Bool) {
        call("FUMDBridge.setTheme(\(dark))")
    }

    func requestOutline() {
        call("FUMDBridge.requestOutline()")
    }

    func scrollToHeading(_ index: Int) {
        call("FUMDBridge.scrollToHeading(\(index))")
    }

    private func call(_ js: String) {
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private static func jsonString(_ obj: [String: String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: obj),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }
}
