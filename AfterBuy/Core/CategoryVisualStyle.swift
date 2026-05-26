import SwiftUI

enum CategoryVisualStyle {
    static func iconName(for categoryKey: String) -> String {
        guard let key = LKey(rawValue: categoryKey) else { return "tag" }
        switch key {
        case .categoryFood: return "fork.knife"
        case .categoryDaily: return "basket"
        case .categoryTransport: return "car.fill"
        case .categoryDigital: return "desktopcomputer"
        case .categoryPet: return "pawprint.fill"
        case .categoryTravel: return "airplane"
        case .categoryClothing: return "tshirt.fill"
        case .categoryEntertainment: return "gamecontroller.fill"
        case .categorySocial: return "person.2.fill"
        case .categoryMedical: return "cross.case.fill"
        case .categoryLearning: return "book.fill"
        case .categoryHousing: return "house.fill"
        case .categoryOther: return "ellipsis.circle.fill"
        default: return "tag"
        }
    }

    static func iconColor(for categoryKey: String) -> Color {
        guard let key = LKey(rawValue: categoryKey) else { return AppTheme.textPrimary }
        switch key {
        case .categoryOther: return Color(hex: "5B3F80")
        case .categoryFood: return Color(hex: "A83B62")
        case .categoryEntertainment: return Color(hex: "B53878")
        case .categoryTransport: return Color(hex: "1F6F83")
        case .categoryDaily: return Color(hex: "8A6A1A")
        case .categoryClothing: return Color(hex: "933A52")
        case .categorySocial: return Color(hex: "8F4C20")
        case .categoryMedical: return Color(hex: "1F7D66")
        case .categoryLearning: return Color(hex: "4054A0")
        case .categoryHousing: return Color(hex: "3F5E70")
        case .categoryDigital: return Color(hex: "275F84")
        case .categoryPet: return Color(hex: "95581E")
        case .categoryTravel: return Color(hex: "1E6D91")
        default: return AppTheme.textPrimary
        }
    }

    /// Ring / icon tint for grid selection (custom / unknown keys use brand blue).
    static func selectionAccentColor(for categoryKey: String) -> Color {
        Color(hex: accentHex(for: categoryKey))
    }

    /// Icon tint in the category grid: accent ring uses category color; glyph stays readable in dark mode.
    static func gridIconForeground(isSelected: Bool, accent: Color) -> Color {
        if isSelected {
            return AppTheme.textPrimary
        }
        return AppTheme.textSecondary
    }

    /// List / notification row badge: preset hue in light mode; lightened hue in dark mode for contrast on `pageBackground`.
    static func listBadgeIconForeground(for categoryKey: String, colorScheme: ColorScheme) -> Color {
        guard colorScheme == .dark else {
            return iconColor(for: categoryKey)
        }
        if categoryKey.hasPrefix("custom.category.") || LKey(rawValue: categoryKey) != nil {
            return AppTheme.lightenedColor(hex: accentHex(for: categoryKey), mixTowardWhite: 0.48)
                ?? AppTheme.textSecondary
        }
        return AppTheme.textPrimary
    }

    /// Hex accent aligned with `iconColor` (记一笔 category grid).
    static func accentHex(for categoryKey: String) -> String {
        if categoryKey.hasPrefix("custom.category.") {
            return "3F6F76"
        }
        guard let key = LKey(rawValue: categoryKey),
              CategoryPreset.all.contains(where: { $0.key == key }) else {
            return "3F6F76"
        }
        switch key {
        case .categoryOther: return "5B3F80"
        case .categoryFood: return "A83B62"
        case .categoryEntertainment: return "B53878"
        case .categoryTransport: return "1F6F83"
        case .categoryDaily: return "8A6A1A"
        case .categoryClothing: return "933A52"
        case .categorySocial: return "8F4C20"
        case .categoryMedical: return "1F7D66"
        case .categoryLearning: return "4054A0"
        case .categoryHousing: return "3F5E70"
        case .categoryDigital: return "275F84"
        case .categoryPet: return "95581E"
        case .categoryTravel: return "1E6D91"
        default: return "3F6F76"
        }
    }
}
