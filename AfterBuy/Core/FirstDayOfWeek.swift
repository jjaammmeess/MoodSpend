import Foundation

/// User preference for the first day of a calendar week (maps to `Calendar.firstWeekday`).
enum FirstDayOfWeek: Int, CaseIterable, Identifiable, Hashable, Sendable {
    case sunday = 1
    case monday = 2

    nonisolated var id: Int { rawValue }

    /// `Calendar.firstWeekday` value (1 = Sunday, 2 = Monday).
    nonisolated var calendarFirstWeekday: Int { rawValue }

    nonisolated static let storageKey = "firstDayOfWeek"

    /// Reads persisted preference; `0` and unknown values default to Monday.
    nonisolated static var current: FirstDayOfWeek {
        let raw = UserDefaults.standard.integer(forKey: storageKey)
        return raw == 1 ? .sunday : .monday
    }

    nonisolated static func registerDefaults() {
        UserDefaults.standard.register(defaults: [storageKey: FirstDayOfWeek.monday.rawValue])
    }
}

enum AppCalendar {
    nonisolated static func make(
        firstDayOfWeek: FirstDayOfWeek = .current,
        locale: Locale = .current
    ) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = locale
        cal.firstWeekday = firstDayOfWeek.calendarFirstWeekday
        return cal
    }
}
