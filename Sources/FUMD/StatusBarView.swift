import SwiftUI

struct StatusBarView: View {
    @ObservedObject var store: DocumentStore

    var body: some View {
        HStack(spacing: 12) {
            Text(store.fileURL?.path ?? "未命名（未保存）")
                .lineLimit(1)
                .truncationMode(.head)
            Spacer()
            Text("字数 \(store.stats.words)　字符 \(store.stats.characters)")
        }
        .font(.system(size: 11))
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
