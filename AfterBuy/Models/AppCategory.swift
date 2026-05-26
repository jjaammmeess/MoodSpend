import Foundation

struct AppCategory: Identifiable, Hashable {
    let key: LKey
    var id: String { key.rawValue }
}

struct CategoryOption: Identifiable, Hashable {
    let id: String
    let key: LKey?
    let customName: String?
    /// Resolved SF Symbol for custom rows; `nil` uses `CategoryVisualStyle` for preset keys.
    let customIconSymbol: String?

    var isCustom: Bool { key == nil }
}

enum CategoryPreset {
    static let all: [AppCategory] = [
        AppCategory(key: .categoryFood),
        AppCategory(key: .categoryDaily),
        AppCategory(key: .categoryTransport),
        AppCategory(key: .categoryDigital),
        AppCategory(key: .categoryPet),
        AppCategory(key: .categoryTravel),
        AppCategory(key: .categoryClothing),
        AppCategory(key: .categoryEntertainment),
        AppCategory(key: .categorySocial),
        AppCategory(key: .categoryMedical),
        AppCategory(key: .categoryLearning),
        AppCategory(key: .categoryHousing),
        AppCategory(key: .categoryOther)
    ]

    static var options: [CategoryOption] {
        all.map { CategoryOption(id: $0.id, key: $0.key, customName: nil, customIconSymbol: nil) }
    }
}
