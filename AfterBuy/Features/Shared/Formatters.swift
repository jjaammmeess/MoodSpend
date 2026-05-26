import Foundation

enum AppFormatter {
    @MainActor
    static weak var currencyManager: CurrencyManager?

    @MainActor
    static func moneyString(from amount: Double, locale: Locale) -> String {
        if let currencyManager {
            return amount.formattedAsMoney(currencyManager: currencyManager, locale: locale)
        }
        let code = CurrencyCode.systemDefaultCode()
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code.rawValue
        formatter.locale = locale
        formatter.maximumFractionDigits = code == .JPY ? 0 : 2
        formatter.minimumFractionDigits = code == .JPY ? 0 : 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    @MainActor
    static var activeCurrencySymbol: String {
        currencyManager?.activeCurrencySymbol ?? CurrencyCode.systemDefaultCode().symbol
    }

    @MainActor
    static var activeCurrencyCode: String {
        currencyManager?.activeCurrencyCode ?? CurrencyCode.systemDefaultCode().rawValue
    }

    /// Gregorian calendar date for UI and exports.
    /// - Chinese locales: `yyyy/MM/dd` (zero-padded).
    /// - English locales: `MM/dd/yyyy` (US-style, zero-padded).
    /// - Other locales: system **medium** date in that locale.
    static func dayString(from date: Date, locale: Locale) -> String {
        let id = locale.identifier.lowercased()
        if id.hasPrefix("zh") {
            return gregorianNumericYMD(date: date, yearFirst: true)
        }
        if id.hasPrefix("en") {
            return gregorianNumericYMD(date: date, yearFirst: false)
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = locale
        formatter.timeZone = TimeZone.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// Time for UI lists and detail rows.
    /// - Chinese locales: 24-hour `HH:mm` (same for Simplified and Traditional).
    /// - Other locales: system short time in that locale.
    static func timeString(from date: Date, locale: Locale) -> String {
        let id = locale.identifier.lowercased()
        if id.hasPrefix("zh") {
            return gregorian24HourTime(date: date)
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = locale
        formatter.timeZone = TimeZone.current
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Combined date and time for compact list rows (`yyyy/MM/dd HH:mm` in Chinese).
    static func dayTimeString(from date: Date, locale: Locale) -> String {
        "\(dayString(from: date, locale: locale)) \(timeString(from: date, locale: locale))"
    }

    /// Gallery sheet top line: `2026年5月` (zh) or `May 2026` (en).
    static func galleryYearMonthString(from date: Date, locale: Locale) -> String {
        let id = locale.identifier.lowercased()
        if id.hasPrefix("zh") {
            let cal = Calendar(identifier: .gregorian)
            let c = cal.dateComponents(in: TimeZone.current, from: date)
            guard let y = c.year, let m = c.month else { return "" }
            return "\(y)年\(m)月"
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = locale
        formatter.timeZone = TimeZone.current
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMMM")
        return formatter.string(from: date)
    }

    /// Gallery sheet month headline when the bucket is a whole month: `5月` (zh) or `May` (en).
    static func galleryMonthOnlyString(from date: Date, locale: Locale) -> String {
        let id = locale.identifier.lowercased()
        if id.hasPrefix("zh") {
            let cal = Calendar(identifier: .gregorian)
            let c = cal.dateComponents(in: TimeZone.current, from: date)
            guard let m = c.month else { return "" }
            return "\(m)月"
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = locale
        formatter.timeZone = TimeZone.current
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter.string(from: date)
    }

    /// Gallery sheet year-only caption for month buckets: `2026年` (zh) or `2026` (en).
    static func galleryYearOnlyString(from date: Date, locale: Locale) -> String {
        let id = locale.identifier.lowercased()
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents(in: TimeZone.current, from: date)
        guard let y = c.year else { return "" }
        if id.hasPrefix("zh") {
            return "\(y)年"
        }
        return String(y)
    }

    /// Gallery sheet headline: `13日 · 周三` (zh) or `13 · Wed` (en).
    static func galleryDayWeekdayString(from date: Date, locale: Locale) -> String {
        let id = locale.identifier.lowercased()
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents(in: TimeZone.current, from: date)
        guard let d = c.day else { return "" }

        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.locale = locale
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = id.hasPrefix("zh") ? "EEE" : "EEE"
        let weekday = formatter.string(from: date)

        if id.hasPrefix("zh") {
            return "\(d)日 · \(weekday)"
        }
        return "\(d) · \(weekday)"
    }

    /// Month + day for compact capsules (`5月14日` in Chinese; localized short form elsewhere).
    static func monthDayString(from date: Date, locale: Locale) -> String {
        let id = locale.identifier.lowercased()
        if id.hasPrefix("zh") {
            let cal = Calendar(identifier: .gregorian)
            let c = cal.dateComponents(in: TimeZone.current, from: date)
            guard let m = c.month, let d = c.day else { return "" }
            return "\(m)月\(d)日"
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = locale
        formatter.timeZone = TimeZone.current
        formatter.setLocalizedDateFormatFromTemplate("MMMMd")
        return formatter.string(from: date)
    }

    /// Plain decimal text for integers (e.g. years) without locale grouping separators.
    static func plainInteger(_ value: Int) -> String {
        String(value)
    }

    /// File-export stamp (`yyyy-MM-dd`) in the user's current time zone.
    static func exportDateStamp(from date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func gregorian24HourTime(date: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents(in: TimeZone.current, from: date)
        guard let h = c.hour, let m = c.minute else { return "" }
        return String(format: "%02d:%02d", h, m)
    }

    private static func gregorianNumericYMD(date: Date, yearFirst: Bool) -> String {
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents(in: TimeZone.current, from: date)
        guard let y = c.year, let m = c.month, let d = c.day else { return "" }
        if yearFirst {
            return String(format: "%04d/%02d/%02d", y, m, d)
        }
        return String(format: "%02d/%02d/%04d", m, d, y)
    }
}
