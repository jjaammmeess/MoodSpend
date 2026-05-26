import Foundation

extension DateFilter {
    /// Calendar interval for the period that contains `now` (day / week / month / year).
    func currentPeriodInterval(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DateInterval? {
        switch self {
        case .day:
            return calendar.dateInterval(of: .day, for: now)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: now)
        case .month:
            return calendar.dateInterval(of: .month, for: now)
        case .year:
            return calendar.dateInterval(of: .year, for: now)
        }
    }

    /// The immediately preceding period of the same granularity (yesterday, last week, etc.).
    func previousPeriodInterval(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DateInterval? {
        switch self {
        case .day:
            guard let dayStart = calendar.dateInterval(of: .day, for: now)?.start,
                  let yesterday = calendar.date(byAdding: .day, value: -1, to: dayStart)
            else { return nil }
            return calendar.dateInterval(of: .day, for: yesterday)

        case .week:
            guard let current = calendar.dateInterval(of: .weekOfYear, for: now),
                  let prevStart = calendar.date(byAdding: .weekOfYear, value: -1, to: current.start)
            else { return nil }
            return calendar.dateInterval(of: .weekOfYear, for: prevStart)

        case .month:
            guard let current = calendar.dateInterval(of: .month, for: now),
                  let prevStart = calendar.date(byAdding: .month, value: -1, to: current.start)
            else { return nil }
            return calendar.dateInterval(of: .month, for: prevStart)

        case .year:
            guard let current = calendar.dateInterval(of: .year, for: now),
                  let prevStart = calendar.date(byAdding: .year, value: -1, to: current.start)
            else { return nil }
            return calendar.dateInterval(of: .year, for: prevStart)
        }
    }
}
