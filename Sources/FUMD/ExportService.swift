import AppKit
import UniformTypeIdentifiers
import WebKit

enum ExportFormat {
    case html
    case pdf
}

@MainActor
enum ExportService {
    static func export(store: DocumentStore, format: ExportFormat) async {
        guard let bridge = store.bridge else { return }
        guard var bodyHTML = await bridge.getHtml() else { return }
        if bodyHTML.isEmpty { bodyHTML = "<p>（空文档）</p>" }
        let dark = OpenCoordinator.shared.isDark
        let html = Self.document(title: store.displayName, body: bodyHTML, dark: dark)

        let panel = NSSavePanel()
        let baseName = store.fileURL?.deletingPathExtension().lastPathComponent ?? "未命名"
        switch format {
        case .html:
            panel.allowedContentTypes = [UTType.html]
            panel.nameFieldStringValue = baseName + ".html"
        case .pdf:
            panel.allowedContentTypes = [UTType.pdf]
            panel.nameFieldStringValue = baseName + ".pdf"
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            switch format {
            case .html:
                try html.write(to: url, atomically: true, encoding: .utf8)
            case .pdf:
                let data = try await Self.renderPDF(html: html)
                try data.write(to: url)
            }
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private static func document(title: String, body: String, dark: Bool) -> String {
        let css = Self.inlineCSS(dark: dark)
        let escapedTitle = title
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return """
        <!DOCTYPE html><html lang="zh_CN"><head><meta charset="utf-8"><title>\(escapedTitle)</title><style>\(css)</style></head>
        <body class="markdown-body"><article>\(body)</article></body></html>
        """
    }

    private static func inlineCSS(dark: Bool) -> String {
        var css = """
        html { background: \(dark ? "#1e1e1e" : "#ffffff"); }
        body { max-width: 820px; margin: 0 auto; padding: 48px 32px; }
        @media print { body { padding: 0; } }
        """
        let theme = dark ? "dark" : "light"
        if let url = Bundle.module.url(forResource: "content", withExtension: "css",
                                       subdirectory: "Resources/editor/vditor/dist/css/content-theme/\(theme)"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            css += "\n" + text
        }
        if let url = Bundle.module.url(forResource: "katex.min", withExtension: "css",
                                       subdirectory: "Resources/editor/vditor/dist/js/katex"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            css += "\n" + text
        }
        return css
    }

    private static func renderPDF(html: String) async throws -> Data {
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 794, height: 1123))
        webView.underPageBackgroundColor = .white
        let katexBase = Bundle.module.url(forResource: "katex.min", withExtension: "css",
                                          subdirectory: "Resources/editor/vditor/dist/js/katex")?
            .deletingLastPathComponent()
        webView.loadHTMLString(html, baseURL: katexBase)
        for _ in 0..<200 {
            if !webView.isLoading { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        let height = (try? await webView.evaluateJavaScript(
            "Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)"
        )).flatMap { $0 as? Double } ?? 1123
        let pdfConfig = WKPDFConfiguration()
        pdfConfig.rect = CGRect(x: 0, y: 0, width: 794, height: max(height, 1123))
        return try await withCheckedThrowingContinuation { continuation in
            webView.createPDF(configuration: pdfConfig) { result in
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
