import SwiftUI

struct SearchCacheView: View {
    let cachedQueries: [StoredSearchQuery]
    var keyboardHeight: CGFloat = 0
    let onSelect: (StoredSearchQuery) -> Void
    let onPopTop: () -> Void

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
                    self.onPopTop()
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 17))
                        .foregroundColor(.purp)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove Most Recent")
                .accessibilityHint("Remove the most recent search")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}
