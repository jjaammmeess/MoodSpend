import Foundation

enum CurrencyCode: String, CaseIterable, Codable, Identifiable {
    case CNY = "CNY"
    case USD = "USD"
    case GBP = "GBP"
    case EUR = "EUR"
    case JPY = "JPY"
    case AUD = "AUD"
    case CAD = "CAD"
    case SGD = "SGD"
    case TWD = "TWD"
    case HKD = "HKD"

    var id: String { rawValue }

    /// Display order in currency settings (after「跟随系统」).
    static let settingsListOrder: [CurrencyCode] = allCases

    var symbol: String {
        switch self {
        case .CNY: return "¥"
        case .USD, .AUD, .CAD, .SGD: return "$"
        case .GBP: return "£"
        case .EUR: return "€"
        case .JPY: return "¥"
        case .TWD: return "NT$"
        case .HKD: return "HK$"
        }
    }

    /// Settings row title, e.g. 「美元 (USD)」/ "US Dollar (USD)".
    func displayName(locale: Locale) -> String {
        let id = locale.identifier.lowercased()
        if id.hasPrefix("zh-hant") || id.hasPrefix("zh_tw") || id.hasPrefix("zh-hk") || id.hasPrefix("zh-mo") {
            return traditionalChineseSettingsName
        }
        if id.hasPrefix("zh") {
            return simplifiedChineseSettingsName
        }
        return englishSettingsName
    }

    private var simplifiedChineseSettingsName: String {
        switch self {
        case .CNY: return "人民币 (CNY)"
        case .USD: return "美元 (USD)"
        case .GBP: return "英镑 (GBP)"
        case .EUR: return "欧元 (EUR)"
        case .JPY: return "日元 (JPY)"
        case .AUD: return "澳大利亚元 (AUD)"
        case .CAD: return "加拿大元 (CAD)"
        case .SGD: return "新加坡元 (SGD)"
        case .TWD: return "新台币 (TWD)"
        case .HKD: return "港元 (HKD)"
        }
    }

    private var traditionalChineseSettingsName: String {
        switch self {
        case .CNY: return "人民幣 (CNY)"
        case .USD: return "美元 (USD)"
        case .GBP: return "英鎊 (GBP)"
        case .EUR: return "歐元 (EUR)"
        case .JPY: return "日圓 (JPY)"
        case .AUD: return "澳大利亞元 (AUD)"
        case .CAD: return "加拿大元 (CAD)"
        case .SGD: return "新加坡元 (SGD)"
        case .TWD: return "新臺幣 (TWD)"
        case .HKD: return "港元 (HKD)"
        }
    }

    private var englishSettingsName: String {
        switch self {
        case .CNY: return "Chinese Yuan (CNY)"
        case .USD: return "US Dollar (USD)"
        case .GBP: return "British Pound (GBP)"
        case .EUR: return "Euro (EUR)"
        case .JPY: return "Japanese Yen (JPY)"
        case .AUD: return "Australian Dollar (AUD)"
        case .CAD: return "Canadian Dollar (CAD)"
        case .SGD: return "Singapore Dollar (SGD)"
        case .TWD: return "New Taiwan Dollar (TWD)"
        case .HKD: return "Hong Kong Dollar (HKD)"
        }
    }

    static func supported(_ code: String) -> CurrencyCode? {
        CurrencyCode(rawValue: code.uppercased())
    }

    static func systemDefaultCode() -> CurrencyCode {
        if let id = Locale.current.currency?.identifier,
           let supported = supported(id) {
            return supported
        }
        let region = Locale.current.region?.identifier ?? ""
        return region == "CN" ? .CNY : .USD
    }
}
