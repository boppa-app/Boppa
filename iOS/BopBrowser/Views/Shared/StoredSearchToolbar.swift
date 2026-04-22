import SwiftUI

struct StoredSearchToolbar: View {
    @Binding var searchText: String
    @Binding var showSearchBar: Bool
    var placeholder: String = "Search"
    var isSearchFieldFocused: FocusState<Bool>.Binding
    var fadeOpacity: CGFloat = 0
    var fadeHeight: CGFloat = 40

    var body: some View {
        VStack(spacing: 0) {
            if self.showSearchBar {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(self.isSearchFieldFocused.wrappedValue ? Color(.white) : Color(.systemGray))
                            .frame(width: 20, height: 20)

                        TextField(
                            "",
                            text: self.$searchText,
                            prompt: Text(self.placeholder).foregroundColor(Color(.systemGray3))
                        )
                        .font(.system(size: 15))
                        .tint(Color.purp)
                        .textFieldStyle(.plain)
                        .foregroundColor(self.isSearchFieldFocused.wrappedValue ? .white : Color(.systemGray))
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused(self.isSearchFieldFocused)

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
                    .background(.black)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                LinearGradient(
                                    stops: [
                                        .init(color: .purp.opacity(0.3), location: 0),
                                        .init(color: .purp.opacity(0.5), location: 0.5),
                                        .init(color: .purp.opacity(0.3), location: 1),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(.black)

                    LinearGradient(
                        colors: [.black.opacity(self.fadeOpacity), .black.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: self.fadeHeight)
                    .allowsHitTesting(false)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .clipped()
    }
}
