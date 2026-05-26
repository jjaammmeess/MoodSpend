import Foundation

enum BillListSparklineMetrics {
    struct Point: Identifiable, Equatable {
        let id: Int
        let amount: Double
    }

    static func points(
        expenses: [TransactionRecord],
        dateFilter: DateFilter,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [Point] {
        points(
            expenses: expenses,
            period: dateFilter.asPeriodMode,
            anchor: now,
            customRange: nil,
            calendar: calendar
        )
    }

    /// Bill-list sparkline buckets aligned to `AppPeriodContext` (anchored date + custom span).
    static func points(
        expenses: [TransactionRecord],
        period: PeriodMode,
        anchor: Date,
        customRange: CustomMonthRange?,
        calendar: Calendar = .current
    ) -> [Point] {
        switch period {
        case .day:
            return dayHourPoints(expenses: expenses, calendar: calendar, anchor: anchor)
        case .week:
            return weekDayPoints(expenses: expenses, calendar: calendar, anchor: anchor)
        case .month:
            return monthDayPoints(expenses: expenses, calendar: calendar, anchor: anchor)
        case .year:
            return yearMonthPoints(expenses: expenses, calendar: calendar, anchor: anchor)
        case .custom:
            return customRangePoints(
                expenses: expenses,
                customRange: customRange,
                calendar: calendar
            )
        }
    }

    private static func customRangePoints(
        expenses: [TransactionRecord],
        customRange: CustomMonthRange?,
        calendar: Calendar
    ) -> [Point] {
        guard let customRange,
              let interval = AppPeriodContext.customMonthInterval(for: customRange.normalized, calendar: calendar)
        else { return [] }

        let monthSpan = customRange.normalized.endMonth - customRange.normalized.startMonth + 1
        if monthSpan <= 1 {
            return intervalDayPoints(expenses: expenses, interval: interval, calendar: calendar)
        }

        return (0..<monthSpan).map { offset in
            var components = DateComponents()
            components.year = customRange.year
            components.month = customRange.normalized.startMonth + offset
            components.day = 1
            guard let bucketStart = calendar.date(from: components),
                  let bucketEnd = calendar.date(byAdding: .month, value: 1, to: bucketStart)
            else {
                return Point(id: offset, amount: 0)
            }
            let amount = expenses
                .filter { $0.createdAt >= bucketStart && $0.createdAt < bucketEnd }
                .reduce(0) { $0 + $1.amount }
            return Point(id: offset, amount: amount)
        }
    }

    private static func intervalDayPoints(
        expenses: [TransactionRecord],
        interval: DateInterval,
        calendar: Calendar
    ) -> [Point] {
        let dayCount = max(1, calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1)
        return (0..<dayCount).map { offset in
            guard let bucketStart = calendar.date(byAdding: .day, value: offset, to: interval.start),
                  let bucketEnd = calendar.date(byAdding: .day, value: 1, to: bucketStart)
            else {
                return Point(id: offset, amount: 0)
            }
            let amount = expenses
                .filter { $0.createdAt >= bucketStart && $0.createdAt < bucketEnd }
                .reduce(0) { $0 + $1.amount }
            return Point(id: offset, amount: amount)
        }
    }

    private static func dayHourPoints(
        expenses: [TransactionRecord],
        calendar: Calendar,
        anchor: Date
    ) -> [Point] {
        guard let dayStart = calendar.dateInterval(of: .day, for: anchor)?.start else { return [] }
        return (0..<24).map { hour in
            guard let bucketStart = calendar.date(byAdding: .hour, value: hour, to: dayStart),
                  let bucketEnd = calendar.date(byAdding: .hour, value: 1, to: bucketStart)
            else {
                return Point(id: hour, amount: 0)
            }
            let amount = expenses
                .filter { $0.createdAt >= bucketStart && $0.createdAt < bucketEnd }
                .reduce(0) { $0 + $1.amount }
            return Point(id: hour, amount: amount)
        }
    }

    private static func weekDayPoints(
        expenses: [TransactionRecord],
        calendar: Calendar,
        anchor: Date
    ) -> [Point] {
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: anchor)?.start else {
            return []
        }
        return (0..<7).map { offset in
            guard let bucketStart = calendar.date(byAdding: .day, value: offset, to: weekStart),
                  let bucketEnd = calendar.date(byAdding: .day, value: 1, to: bucketStart)
            else {
                return Point(id: offset, amount: 0)
            }
            let amount = expenses
                .filter { $0.createdAt >= bucketStart && $0.createdAt < bucketEnd }
                .reduce(0) { $0 + $1.amount }
            return Point(id: offset, amount: amount)
        }
    }

    private static func monthDayPoints(
        expenses: [TransactionRecord],
        calendar: Calendar,
        anchor: Date
    ) -> [Point] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: anchor) else { return [] }
        let dayCount = calendar.dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day ?? 0
        return (0..<dayCount).map { offset in
            guard let bucketStart = calendar.date(byAdding: .day, value: offset, to: monthInterval.start),
                  let bucketEnd = calendar.date(byAdding: .day, value: 1, to: bucketStart)
            else {
                return Point(id: offset, amount: 0)
            }
            let amount = expenses
                .filter { $0.createdAt >= bucketStart && $0.createdAt < bucketEnd }
                .reduce(0) { $0 + $1.amount }
            return Point(id: offset, amount: amount)
        }
    }

    private static func yearMonthPoints(
        expenses: [TransactionRecord],
        calendar: Calendar,
        anchor: Date
    ) -> [Point] {
        guard let yearStart = calendar.dateInterval(of: .year, for: anchor)?.start else { return [] }
        return (0..<12).map { month in
            guard let bucketStart = calendar.date(byAdding: .month, value: month, to: yearStart),
                  let bucketEnd = calendar.date(byAdding: .month, value: 1, to: bucketStart)
            else {
                return Point(id: month, amount: 0)
            }
            let amount = expenses
                .filter { $0.createdAt >= bucketStart && $0.createdAt < bucketEnd }
                .reduce(0) { $0 + $1.amount }
            return Point(id: month, amount: amount)
        }
    }
}

private extension DateFilter {
    var asPeriodMode: PeriodMode {
        switch self {
        case .day: return .day
        case .week: return .week
        case .month: return .month
        case .year: return .year
        }
    }
}
