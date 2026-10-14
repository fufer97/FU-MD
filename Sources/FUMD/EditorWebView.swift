import SwiftUI
import WebKit

struct EditorWebView: NSViewRepresentable {
    let bridge: EditorBridge

    func makeNSView(context: Context) -> WKWebView { bridge.webView }

    func updateNSView(_ webView: WKWebView, context: Context) {}
}
