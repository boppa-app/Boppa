import SwiftUI

struct LibrarySearchToolbarView: View {
    @Binding var searchQuery: String
    var isSearchFieldFocused: FocusState<Bool>.Binding
    var isFuzzySearching: Bool
    var selectedCategory: SearchCategory
    var onClear: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Group {
                    if self.isFuzzySearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: self.selectedCategory.icon)
                    }
                }
                .foregroundColor(self.isSearchFieldFocused.wrappedValue ? Color.white : Color(.systemGray))
                .frame(width: 20, height: 24)

                TextField(
                    "",
                    text: self.$searchQuery,
                    prompt: Text("Search library").foregroundColor(Color(.systemGray4))
                )
                .tint(Color.purp)
                .textFieldStyle(.plain)
                .foregroundColor(self.isSearchFieldFocused.wrappedValue ? Color.white : Color(.systemGray))
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .focused(self.isSearchFieldFocused)

                if !self.searchQuery.isEmpty {
                    Button {
                        self.searchQuery = ""
                        self.onClear?()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16))
                            .foregroundColor(Color(.systemGray))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding(.horizontal, 16)
    }
}
