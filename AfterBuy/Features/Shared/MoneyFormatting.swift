import Foundation

struct MoneyDisplayParts {
    let major: String
    let minor: String
}

extension Double {
    func formattedAsMoney(currencyManager: CurrencyManager, locale: Locale) -> String {
        let formatter = currencyManager.moneyFormatter(locale: locale)
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    func moneyDisplayParts(currencyManager: CurrencyManager, locale: Locale) -> MoneyDisplayParts {
        let formatter = currencyManager.moneyFormatter(locale: locale)
        let formatted = formatter.string(from: NSNumber(value: self)) ?? "\(self)"
        let minorDigits = formatter.minimumFractionDigits
        guard minorDigits > 0 else {
            return MoneyDisplayParts(major: formatted, minor: "")
        }

        let separator = formatter.decimalSeparator ?? "."
        let parts = formatted.split(separator: separator, maxSplits: 1, omittingEmptySubsequences: false)
        let major = String(parts.first ?? Substring(formatted))
        let fraction = parts.count > 1
            ? String(parts[1])
            : String(repeating: "0", count: minorDigits)
        return MoneyDisplayParts(major: major, minor: "\(separator)\(fraction)")
    }
}
