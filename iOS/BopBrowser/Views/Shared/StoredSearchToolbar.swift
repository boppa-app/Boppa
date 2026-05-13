import SwiftUI

struct StoredSearchToolbar: View {
    @Binding var searchText: String
    @Binding var showSearchBar: Bool
    var placeholder: String = "Search"
    var isSearchFieldFocused: FocusState<Bool>.Binding
    var isSearching: Bool = false
    var fadeOpacity: CGFloat = 0
    var fadeHeight: CGFloat = 40

    @State private var showFocus = false

    private var isFocused: Bool {
        self.isSearchFieldFocused.wrappedValue
    }

    var body: some View {
        VStack(spacing: 0) {
            if self.showSearchBar {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(self.showFocus ? Color(.white) : Color(.systemGray))
                                .frame(width: 20, height: 20)

                            TextField(
                                "",
                                text: self.$searchText,
                                prompt: Text(self.placeholder).foregroundColor(Color(.systemGray3))
                            )
                            .font(.system(size: 15))
                            .tint(Color.purp)
                            .textFieldStyle(.plain)
                            .foregroundColor(self.showFocus ? .white : Color(.systemGray))
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .focused(self.isSearchFieldFocused)

                            if self.isSearching {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(Color(.systemGray))
                            }

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

                        if self.showFocus {
                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color(.systemGray3))
                                    .frame(width: 2)
                                    .padding(.vertical, 2)

                                Button {
                                    self.isSearchFieldFocused.wrappedValue = false
                                } label: {
                                    Text("Done")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.purp)
                                }
                                .padding(.horizontal, 12)
                            }
                            .transition(.opacity)
                        }
                    }
                    .frame(height: 40)
                    .background(
                        VStack(spacing: 0) {
                            Color.clear.frame(height: 2)
                            Color.black
                        }
                    )
                    .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10))
                    .overlay(
                        GeometryReader { geo in
                            let borderColor = self.showFocus
                                ? Color.purp
                                : Color.purp.opacity(0.5)
                            let w: CGFloat = 2
                            let r: CGFloat = 10

                            Path { path in
                                // Start at top-left
                                path.move(to: CGPoint(x: 0, y: 0))
                                // Left side down
                                path.addLine(to: CGPoint(x: 0, y: geo.size.height - r))
                                // Bottom-left corner
                                path.addQuadCurve(
                                    to: CGPoint(x: r, y: geo.size.height),
                                    control: CGPoint(x: 0, y: geo.size.height)
                                )
                                // Bottom edge
                                path.addLine(to: CGPoint(x: geo.size.width - r, y: geo.size.height))
                                // Bottom-right corner
                                path.addQuadCurve(
                                    to: CGPoint(x: geo.size.width, y: geo.size.height - r),
                                    control: CGPoint(x: geo.size.width, y: geo.size.height)
                                )
                                // Right side up
                                path.addLine(to: CGPoint(x: geo.size.width, y: 0))
                            }
                            .stroke(borderColor, lineWidth: w)
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        VStack(spacing: 0) {
                            Color.clear.frame(height: 10)
                            Color.black
                        }
                    )

                    LinearGradient(
                        colors: [.black.opacity(self.fadeOpacity), .black.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: self.fadeHeight)
                    .allowsHitTesting(false)
                }
                .transition(.move(edge: .top))
            }
        }
        .clipped()
        .onChange(of: self.isFocused) { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                self.showFocus = newValue
            }
        }
    }
}

