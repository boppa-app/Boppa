import SwiftUI

struct SearchCacheView: View {
    let cachedQueries: [CachedSearchQuery]
    let onSelect: (CachedSearchQuery) -> Void
    let onRemove: (CachedSearchQuery) -> Void
    let onClearAll: () -> Void

    var body: some View {
        if self.cachedQueries.isEmpty {
            self.headerView
        } else {
            VStack(alignment: .leading, spacing: 0) {
                self.headerView

                ScrollFadeView {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(self.cachedQueries, id: \.persistentModelID) { cached in
                                Button {
                                    self.onSelect(cached)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: cached.category?.icon ?? "magnifyingglass")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(.systemGray))
                                            .frame(width: 20)

                                        Text(cached.query)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                            .lineLimit(1)

                                        Spacer()

                                        Button {
                                            self.onRemove(cached)
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(.systemGray))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: UIScreen.main.bounds.height * 0.35, alignment: .top)
        }
    }

    var headerView: some View {
        HStack {
            Text("Recent Searches")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color(.systemGray))

            Spacer()

            if !self.cachedQueries.isEmpty {
                Button {
                    self.onClearAll()
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(.systemGray))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}
