import Foundation

enum BillListInsightEngine {
    struct Input {
        let periodMode: PeriodMode
        let customRange: CustomMonthRange?
        let dateFilter: DateFilter
        let selectedCategoryKeys: Set<String>
        let categoryScopeExpenses: [TransactionRecord]
        let filteredRecords: [TransactionRecord]
        let sparklinePoints: [BillListSparklineMetrics.Point]
        let totalExpense: Double
        let previousPeriodExpense: Double
        let periodCompareLabel: String
        let categoryTitle: (String) -> String
        /// Natural-period opener (日/周/月/年); unused when `periodMode == .custom`.
        let periodPrefix: String
        /// Custom-range opener, e.g. 「在 2025年08月–12月 这段区间里，」
        let customRangeClause: String?
        /// Prior equal-length span label for compare insights, e.g. 「2025年03月–07月」.
        let previousCustomRangeLabel: String?
        let localize: (LKey, [CVarArg]) -> String
        var calendar: Calendar = .current
        var now: Date = Date()
    }

    private static let categoryShareThreshold = 60
    private static let compareMinimumBaseline = 10.0
    private static let compareUpRatio = 0.30
    private static let compareDownRatio = -0.20
    private static let trendShiftRatio = 0.15
    private static let trendFlatRelativeRange = 0.15

    static func make(input: Input) -> String? {
        guard !input.categoryScopeExpenses.isEmpty else { return nil }
        if input.periodMode == .custom, input.customRange == nil { return nil }

        if let emptyDay = emptyDayInsight(input) { return emptyDay }
        if let category = categoryShareInsight(input) { return category }
        if let trend = trendInsight(input) { return trend }
        if let compare = periodCompareInsight(input) { return compare }
        return input.localize(.billsInsightFallback, [])
    }

    // MARK: - P1

    private static func emptyDayInsight(_ input: Input) -> String? {
        guard input.periodMode == .day, input.filteredRecords.isEmpty else { return nil }
        return input.localize(.billsInsightEmptyDay, [])
    }

    // MARK: - P2 / P3

    private static func categoryShareInsight(_ input: Input) -> String? {
        let totals = categoryTotals(from: input.categoryScopeExpenses)
        let grandTotal = totals.reduce(0) { $0 + $1.amount }
        guard grandTotal > 0, let top = totals.first else { return nil }

        let topPercent = Int((top.amount / grandTotal * 100).rounded())
        let isCustom = input.periodMode == .custom
        let clause = input.customRangeClause ?? ""

        if !input.selectedCategoryKeys.isEmpty {
            let selectedKeys = input.selectedCategoryKeys
            let selectedTotal = totals
                .filter { selectedKeys.contains($0.key) }
                .reduce(0) { $0 + $1.amount }
            guard selectedTotal > 0 else { return nil }
            let percent = Int((selectedTotal / grandTotal * 100).rounded())
            guard percent >= categoryShareThreshold else { return nil }

            if selectedKeys.count == 1, let selectedKey = selectedKeys.first {
                let title = input.categoryTitle(selectedKey)
                if isCustom {
                    return input.localize(
                        .billsInsightCategoryShareSelectedCustom,
                        [clause, title, "\(percent)"]
                    )
                }
                return input.localize(
                    .billsInsightCategoryShareSelected,
                    [title, "\(percent)", input.periodPrefix]
                )
            }

            let topTitles = totals
                .filter { selectedKeys.contains($0.key) }
                .sorted { $0.amount > $1.amount }
                .prefix(2)
                .map { input.categoryTitle($0.key) }
            let joined = topTitles.joined(separator: "、")
            if isCustom {
                return input.localize(
                    .billsInsightCategoryShareSelectedManyCustom,
                    [clause, joined, "\(selectedKeys.count)", "\(percent)"]
                )
            }
            return input.localize(
                .billsInsightCategoryShareSelectedMany,
                [joined, "\(selectedKeys.count)", "\(percent)"]
            )
        }

        guard topPercent >= categoryShareThreshold else { return nil }
        let title = input.categoryTitle(top.key)
        if isCustom {
            return input.localize(
                .billsInsightCategoryShareDominantCustom,
                [clause, title, "\(topPercent)"]
            )
        }
        return input.localize(
            .billsInsightCategoryShareDominant,
            [title, "\(topPercent)", input.periodPrefix]
        )
    }

    // MARK: - P4

    private static func trendInsight(_ input: Input) -> String? {
        let elapsed = elapsedPoints(from: input.sparklinePoints, input: input)
        let amounts = elapsed.map(\.amount)
        guard amounts.count >= 3 else { return nil }

        let nonZero = amounts.filter { $0 > 0 }
        guard nonZero.count >= 2 else { return nil }

        let prefix = input.periodMode == .custom
            ? (input.customRangeClause ?? "")
            : input.periodPrefix

        let mean = amounts.reduce(0, +) / Double(amounts.count)
        let peak = amounts.max() ?? 0
        let floor = amounts.min() ?? 0

        if mean > 0, (peak - floor) / mean <= trendFlatRelativeRange {
            return input.localize(.billsInsightTrendFlat, [prefix])
        }

        let split = amounts.count / 2
        let firstMean = amounts.prefix(split).reduce(0, +) / Double(max(split, 1))
        let secondMean = amounts.suffix(amounts.count - split).reduce(0, +)
            / Double(max(amounts.count - split, 1))

        if secondMean > firstMean * (1 + trendShiftRatio) {
            return input.localize(.billsInsightTrendRising, [prefix])
        }
        if secondMean < firstMean * (1 - trendShiftRatio) {
            return input.localize(.billsInsightTrendFalling, [prefix])
        }

        return input.localize(.billsInsightTrendFlat, [prefix])
    }

    // MARK: - P5

    private static func periodCompareInsight(_ input: Input) -> String? {
        let previous = input.previousPeriodExpense
        let current = input.totalExpense
        guard previous >= compareMinimumBaseline else { return nil }

        let ratio = (current - previous) / previous
        let isCustom = input.periodMode == .custom

        if ratio >= compareUpRatio {
            let percent = Int((ratio * 100).rounded())
            if isCustom, let priorLabel = input.previousCustomRangeLabel {
                return input.localize(
                    .billsInsightCompareUpCustom,
                    ["\(percent)", priorLabel]
                )
            }
            return input.localize(
                .billsInsightCompareUp,
                ["\(percent)", input.periodCompareLabel]
            )
        }
        if ratio <= compareDownRatio {
            if isCustom, let priorLabel = input.previousCustomRangeLabel {
                return input.localize(.billsInsightCompareDownCustom, [priorLabel])
            }
            return input.localize(.billsInsightCompareDown, [input.periodCompareLabel])
        }
        return nil
    }

    // MARK: - Helpers

    private static func categoryTotals(
        from expenses: [TransactionRecord]
    ) -> [(key: String, amount: Double)] {
        let grouped = Dictionary(grouping: expenses, by: \.categoryKey)
        return grouped
            .map { (key: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.amount > $1.amount }
    }

    static func elapsedPoints(
        from points: [BillListSparklineMetrics.Point],
        input: Input
    ) -> [BillListSparklineMetrics.Point] {
        if input.periodMode == .custom {
            return points
        }

        let dateFilter = input.dateFilter
        let calendar = input.calendar
        let now = input.now

        let lastElapsedID: Int?
        switch dateFilter {
        case .day:
            lastElapsedID = calendar.component(.hour, from: now)
        case .week:
            if let weekStart = dateFilter.currentPeriodInterval(now: now, calendar: calendar)?.start {
                lastElapsedID = calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: weekStart),
                    to: calendar.startOfDay(for: now)
                ).day
            } else {
                lastElapsedID = nil
            }
        case .month:
            lastElapsedID = calendar.component(.day, from: now) - 1
        case .year:
            lastElapsedID = calendar.component(.month, from: now) - 1
        }

        guard let lastElapsedID else { return points }
        return points.filter { $0.id <= lastElapsedID }
    }

    /// Legacy entry for tests or callers still on `DateFilter` only.
    static func elapsedPoints(
        from points: [BillListSparklineMetrics.Point],
        dateFilter: DateFilter,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [BillListSparklineMetrics.Point] {
        let periodMode: PeriodMode = switch dateFilter {
        case .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        }
        return elapsedPoints(
            from: points,
            input: Input(
                periodMode: periodMode,
                customRange: nil,
                dateFilter: dateFilter,
                selectedCategoryKeys: [],
                categoryScopeExpenses: [],
                filteredRecords: [],
                sparklinePoints: points,
                totalExpense: 0,
                previousPeriodExpense: 0,
                periodCompareLabel: "",
                categoryTitle: { $0 },
                periodPrefix: "",
                customRangeClause: nil,
                previousCustomRangeLabel: nil,
                localize: { _, _ in "" },
                calendar: calendar,
                now: now
            )
        )
    }
}

