import Foundation

enum SortMode: String, CaseIterable {
    case defaultOrder = "default"
    case reversed
    case authorAZ
    case authorZA
    case nameAZ
    case nameZA

    var label: String {
        switch self {
        case .defaultOrder: return "Default Order"
        case .reversed: return "Reversed"
        case .authorAZ: return "Author (A→Z)"
        case .authorZA: return "Author (Z→A)"
        case .nameAZ: return "Name (A→Z)"
        case .nameZA: return "Name (Z→A)"
        }
    }

    var icon: String {
        switch self {
        case .defaultOrder: return "list.number"
        case .reversed: return "arrow.up.arrow.down"
        case .authorAZ: return "person.fill"
        case .authorZA: return "person.fill"
        case .nameAZ: return "music.note"
        case .nameZA: return "music.note"
        }
    }
}
