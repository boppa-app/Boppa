import SwiftUI

struct AlphabetIndexedList<Item: Identifiable, RowContent: View>: View {
    @Environment(\.bottomBarInset) private var bottomBarInset
    @Environment(\.scrollFadeBottomInset) private var scrollFadeBottomInset
    let items: [Item]
    let name: KeyPath<Item, String>
    @ViewBuilder let rowContent: (Item) -> RowContent

    private struct LetterGroup: Identifiable {
        var id: String {
            self.letter
        }

        let letter: String
        let items: [Item]
    }

    @State private var visibleLetterCounts: [String: Int] = [:]

    private var letterGroups: [LetterGroup] {
        let grouped = Dictionary(grouping: self.items) { item -> String in
            guard let first = item[keyPath: self.name].trimmingCharacters(in: .whitespaces).first,
                  first.isLetter
            else {
                return "#"
            }
            return String(first).uppercased()
        }
        return grouped.keys.sorted().map { letter in
            let items = (grouped[letter] ?? []).sorted {
                $0[keyPath: self.name]
                    .localizedCaseInsensitiveCompare($1[keyPath: self.name]) == .orderedAscending
            }
            return LetterGroup(letter: letter, items: items)
        }
    }

    private var topVisibleLetter: String? {
        self.visibleLetterCounts.keys.sorted().first
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                EdgeFadeView(bottomInset: self.scrollFadeBottomInset) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                            ForEach(self.letterGroups) { group in
                                Section {
                                    ForEach(group.items) { item in
                                        self.rowContent(item)
                                            .onAppear { self.markLetterVisible(group.letter) }
                                            .onDisappear { self.markLetterHidden(group.letter) }
                                    }
                                } header: {
                                    Text(group.letter)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 12)
                                        .padding(.bottom, 4)
                                        .background(Color.black)
                                }
                                .id(group.letter)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .contentMargins(.bottom, self.bottomBarInset, for: .scrollContent)
                    .reportsBottomScrollProximity()
                }

                AlphabetIndexView(
                    availableLetters: Set(self.letterGroups.map(\.letter)),
                    activeLetter: self.topVisibleLetter ?? self.letterGroups.first?.letter ?? "#"
                ) { letter in
                    proxy.scrollTo(letter, anchor: .top)
                }
            }
        }
    }

    private func markLetterVisible(_ letter: String) {
        self.visibleLetterCounts[letter, default: 0] += 1
    }

    private func markLetterHidden(_ letter: String) {
        guard let count = self.visibleLetterCounts[letter] else { return }
        if count <= 1 {
            self.visibleLetterCounts.removeValue(forKey: letter)
        } else {
            self.visibleLetterCounts[letter] = count - 1
        }
    }
}

struct AlphabetIndexView: View {
    let availableLetters: Set<String>
    let activeLetter: String
    let onSelect: (String) -> Void

    private let letters: [String] = ["#"] + (65 ... 90).map { String(UnicodeScalar($0)!) }

    @State private var draggingLetter: String?
    @State private var lastTarget: String?

    var body: some View {
        GeometryReader { geometry in
            let rowHeight = geometry.size.height / CGFloat(self.letters.count)
            let displayLetter = self.draggingLetter ?? self.activeLetter

            VStack(spacing: 0) {
                ForEach(self.letters, id: \.self) { letter in
                    let isActive = displayLetter == letter
                    Text(letter)
                        .font(.system(size: isActive ? 13 : 11, weight: .semibold))
                        .foregroundColor(
                            isActive
                                ? .white
                                : self.availableLetters
                                .contains(letter) ? .purp : Color(.systemGray5)
                        )
                        .frame(maxWidth: .infinity, minHeight: rowHeight)
                        .background(
                            Circle()
                                .fill(Color.purp.opacity(isActive ? 1 : 0))
                                .frame(width: rowHeight * 0.9, height: rowHeight * 0.9)
                        )
                        .animation(.easeOut(duration: 0.12), value: isActive)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        self.handleDrag(at: value.location.y, rowHeight: rowHeight)
                    }
                    .onEnded { _ in
                        self.draggingLetter = nil
                        self.lastTarget = nil
                    }
            )
        }
        .frame(width: 20)
        .padding(.trailing, 4)
    }

    private func handleDrag(at y: CGFloat, rowHeight: CGFloat) {
        guard rowHeight > 0 else { return }
        let index = min(max(Int(y / rowHeight), 0), self.letters.count - 1)
        let tapped = self.letters[index]
        self.draggingLetter = tapped

        guard let target = self.nearestAvailableLetter(from: tapped),
              target != self.lastTarget
        else {
            return
        }
        self.lastTarget = target
        withAnimation(.easeOut(duration: 0.2)) {
            self.onSelect(target)
        }
    }

    private func nearestAvailableLetter(from letter: String) -> String? {
        guard let tappedIndex = self.letters.firstIndex(of: letter) else { return nil }
        if let forward = self.letters[tappedIndex...]
            .first(where: { self.availableLetters.contains($0) })
        {
            return forward
        }
        return self.letters[..<tappedIndex].reversed().first { self.availableLetters.contains($0) }
    }
}
