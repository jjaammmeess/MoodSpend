import Foundation

/// Curated SF Symbol names for custom categories and custom moods (scheme A).
enum CustomIconCatalog {
    static let categorySymbols: [String] = [
        "tag.fill",
        "fork.knife",
        "basket.fill",
        "car.fill",
        "desktopcomputer",
        "pawprint.fill",
        "airplane",
        "tshirt.fill",
        "gamecontroller.fill",
        "person.2.fill",
        "cross.case.fill",
        "book.fill",
        "house.fill",
        "creditcard.fill",
        "cart.fill",
        "gift.fill",
        "takeoutbag.and.cup.and.straw.fill",
        "leaf.fill",
        "cup.and.saucer.fill",
        "figure.walk",
    ]

    static let emotionSymbols: [String] = [
        "heart.fill",
        "star.fill",
        "sparkles",
        "face.smiling.fill",
        "sun.max.fill",
        "moon.stars.fill",
        "leaf.fill",
        "flame.fill",
        "bolt.heart.fill",
        "cloud.fill",
        "music.note",
        "camera.fill",
        "cup.and.saucer.fill",
        "figure.run",
        "hands.sparkles.fill",
        "bird.fill",
        "fish.fill",
        "rainbow",
        "gift.fill",
        "wind",
    ]

    static var defaultCategorySymbol: String { categorySymbols[0] }
    static var defaultEmotionSymbol: String { emotionSymbols[0] }

    static func normalizedCategorySymbol(_ raw: String?) -> String {
        guard let s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
              categorySymbols.contains(s) else {
            return defaultCategorySymbol
        }
        return s
    }

    static func normalizedEmotionSymbol(_ raw: String?) -> String {
        guard let s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
              emotionSymbols.contains(s) else {
            return defaultEmotionSymbol
        }
        return s
    }
}
