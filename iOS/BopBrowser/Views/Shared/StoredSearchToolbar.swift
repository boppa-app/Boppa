import SwiftUI

struct StoredSearchToolbar: View {
    @Binding var searchText: String
    @Binding var showSearchBar: Bool
    var placeholder: String = "Search"

    var body: some View {
        VStack(spacing: 0) {
            if self.showSearchBar {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color(.systemGray))
                        .frame(width: 20, height: 20)

                    TextField(
                        "",
                        text: self.$searchText,
                        prompt: Text(self.placeholder).foregroundColor(Color(.systemGray4))
                    )
                    .tint(Color.purp)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()

                    if !self.searchText.isEmpty {
                        Button {
                            self.searchText = ""
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
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .transition(.opacity)
            }
        }
        .clipped()
    }
}
