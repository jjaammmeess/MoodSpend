import Foundation

/// Product display name and legacy default profile nicknames (formerly the old app name).
enum AppBranding {
    static let nameZhHans = "花钱了"
    static let nameZhHant = "花錢了"
    static let nameEn = "WhySpend"

    static let legacyDefaultDisplayNames: Set<String> = [
        "情绪账单",
        "情緒賬單",
        nameZhHans,
        nameZhHant,
        "AfterBuy",
        nameEn
    ]

    static func productName(for language: AppLanguage) -> String {
        switch language.resolved {
        case .zhHans:
            return nameZhHans
        case .zhHant:
            return nameZhHant
        case .en, .system:
            return nameEn
        }
    }

    static func defaultDisplayName(for language: AppLanguage) -> String {
        productName(for: language)
    }

    static func isLegacyDefaultDisplayName(_ name: String) -> Bool {
        legacyDefaultDisplayNames.contains(name.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Profile nickname for UI: custom names are kept; empty or legacy factory defaults follow the active app language.
    static func resolvedDisplayName(stored: String, language: AppLanguage) -> String {
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLegacyDefaultDisplayName(trimmed) else {
            return defaultDisplayName(for: language)
        }
        return trimmed
    }
}
