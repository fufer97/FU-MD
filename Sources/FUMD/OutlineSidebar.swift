import SwiftUI

struct OutlineSidebar: View {
    @ObservedObject var store: DocumentStore

    var body: some View {
        Group {
            if store.outline.isEmpty {
                Text("暂无大纲")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(store.outline) { item in
                    Text(item.text.isEmpty ? "无标题" : item.text)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .padding(.leading, CGFloat(min(item.level - 1, 5)) * 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.bridge?.scrollToHeading(item.index)
                        }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
