import SwiftUI

struct SearchCacheView: View {
    let cachedQueries: [CachedSearchQuery]
    var keyboardHeight: CGFloat = 0
    let onSelect: (CachedSearchQuery) -> Void
    let onRemove: (CachedSearchQuery) -> Void
    let onClearAll: () -> Void

    var body: some View {
        if self.cachedQueries.isEmpty {
            self.headerView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                self.headerView

                ScrollFadeView {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(self.cachedQueries, id: \.id) { cached in
                                Button {
                                    self.onSelect(cached)
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(cached.query)
                                            .font(.system(size: 15))
                                            .foregroundColor(.white)
                                            .lineLimit(1)

                                        Spacer()

                                        Button {
                                            self.onRemove(cached)
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 15))
                                                .foregroundColor(Color(.systemGray))
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Remove")
                                        .accessibilityHint("Remove \"\(cached.query)\" from recent searches")
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(cached.query)
                                .accessibilityHint("Search for \"\(cached.query)\"")
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
                Color.clear.frame(height: self.keyboardHeight + 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    var headerView: some View {
        HStack {
            Text("Recent Searches")
                .font(.system(size: 17))
                .fontWeight(.semibold)
                .foregroundColor(Color(.systemGray))

            Spacer()

            if !self.cachedQueries.isEmpty {
                Button {
                    self.onClearAll()
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 17))
                        .foregroundColor(Color(.systemGray))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear All Recent Searches")
                .accessibilityHint("Remove all recent searches")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}
