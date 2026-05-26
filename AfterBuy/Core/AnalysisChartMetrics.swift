import Foundation
import SwiftUI

enum AnalysisChartMetrics {
    enum SpectrumInsightTier: Equatable {
        case elevated
        case balanced
        case calm
    }

    struct SpectrumInsight: Equatable {
        let tier: SpectrumInsightTier
        let text: String
    }

    static let spectrumElevatedShareThreshold = 0.4
    static let spectrumBalancedShareThreshold = 0.15
    static let spectrumElevatedMinExpenseCount = 3

    static let heatRingMaxSlices = 5
    static let heatRingOtherKey = "__other__"
    static let retrospectiveMinAge: TimeInterval = 3 * 24 * 60 * 60
    /// CNY. Emotional-bucket expenses below this do not get retrospective **push** notifications.
    static let retrospectivePushSmallAmountThreshold: Double = 30
    /// CNY. Necessary-bucket expenses need at least this for a retrospective push.
    static let retrospectivePushNecessityLargeAmountThreshold: Double = 200
    /// Max retrospective notifications counted in the current ISO-style week (see `NotificationCenterStore`).
    static let retrospectivePushWeeklyCap: Int = 5

    struct HeatRingSlice: Identifiable {
        let id: String
        /// Compact label for legend and nebula (e.g. short emotion name).
        let title: String
        /// Full emotion name for VoiceOver (defaults to `title` when not set at build time).
        let accessibilityTitle: String
        let color: Color
        let amount: Double
        let count: Int
    }

    struct CorrelationDayPoint: Identifiable, Equatable {
        let id: String
        let bucketStart: Date
        let axisLabel: String
        let totalExpense: Double
        let billCount: Int
        /// 0…1 for plotting alongside negativity on one axis.
        let expenseNormalized: Double
        /// 0…1 normalized negativity for chart area.
        let negativityNormalized: Double
        let negativityRaw: Double
    }

    struct SpectrumBucketColumn: Identifiable {
        let id: String
        let bucketStart: Date
        /// Period-local index for ticks (hour 0…23, day 1…31, week 1…52, etc.).
        let bucketIndex: Int
        let axisLabel: String?
        let strokes: [SpectrumStroke]
    }

    struct SpectrumStroke: Identifiable {
        let id: String
        let color: Color
        let amount: Double
    }

    struct RegretQuadrantPoint: Identifiable {
        let id: String
        let recordPublicId: UUID
        let emotionRaw: String
        let createdAt: Date
        let instantJoy: Double
        let longTermValue: Double
        let worth: RetrospectiveWorth
        /// Scatter fill — driven by retrospective worth (worth it / neutral / regret).
        let feedbackColor: Color
        /// Mood tag pill tint — emotion category color.
        let tagColor: Color
        let amount: Double
        let title: String
    }

    struct RegretQuadrantMoodChipGroup: Identifiable {
        let emotionRaw: String
        let title: String
        let tagColor: Color
        let points: [RegretQuadrantPoint]

        var id: String { emotionRaw }
        var count: Int { points.count }
    }

    static func regretQuadrantMoodChipGroups(
        from points: [RegretQuadrantPoint]
    ) -> [RegretQuadrantMoodChipGroup] {
        let grouped = Dictionary(grouping: points, by: \.emotionRaw)
        return grouped.map { raw, groupedPoints in
            let sorted = groupedPoints.sorted { $0.createdAt > $1.createdAt }
            let first = sorted[0]
            return RegretQuadrantMoodChipGroup(
                emotionRaw: raw,
                title: first.title,
                tagColor: first.tagColor,
                points: sorted
            )
        }
        .sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    static func heatRingSlices(
        from expenses: [TransactionRecord],
        displayName: (String, String) -> String,
        accessibilityName: (String, String) -> String,
        maxSlices: Int = heatRingMaxSlices
    ) -> [HeatRingSlice] {
        guard !expenses.isEmpty else { return [] }

        var amountByKey: [String: Double] = [:]
        var countByKey: [String: Int] = [:]
        var colorByKey: [String: Color] = [:]
        var titleByKey: [String: String] = [:]
        var accessibilityTitleByKey: [String: String] = [:]

        for record in expenses {
            let key = record.emotionRaw
            amountByKey[key, default: 0] += record.amount
            countByKey[key, default: 0] += 1
            if colorByKey[key] == nil {
                colorByKey[key] = record.emotionColor
                let fallback = record.safeEmotionName
                titleByKey[key] = displayName(key, fallback)
                accessibilityTitleByKey[key] = accessibilityName(key, fallback)
            }
        }

        let sortedKeys = amountByKey.keys.sorted { amountByKey[$0, default: 0] > amountByKey[$1, default: 0] }
        let topKeys = Array(sortedKeys.prefix(maxSlices))
        let otherKeys = sortedKeys.filter { !topKeys.contains($0) }

        var slices: [HeatRingSlice] = topKeys.map { key in
            let title = titleByKey[key] ?? key
            return HeatRingSlice(
                id: key,
                title: title,
                accessibilityTitle: accessibilityTitleByKey[key] ?? title,
                color: colorByKey[key] ?? AppTheme.actionBlue,
                amount: amountByKey[key, default: 0],
                count: countByKey[key, default: 0]
            )
        }

        if !otherKeys.isEmpty {
            let otherAmount = otherKeys.reduce(0) { $0 + amountByKey[$1, default: 0] }
            let otherCount = otherKeys.reduce(0) { $0 + countByKey[$1, default: 0] }
            slices.append(
                HeatRingSlice(
                    id: heatRingOtherKey,
                    title: "",
                    accessibilityTitle: "",
                    color: Color(hex: "8A96A0"),
                    amount: otherAmount,
                    count: otherCount
                )
            )
        }

        return slices
    }

    // MARK: - Emotion dashboard (distress / fulfillment)

    struct EmotionDashboardMetrics {
        let distressExpense: Double
        let distressShareOfTotal: Double
        let fulfillmentEntryCount: Int
        let positivePurchaseRateDeltaPoints: Int?
    }

    /// Preset stress + impulse; custom moods in the emotional bucket (excludes social preset).
    static func isDistressRecord(_ record: TransactionRecord, customEmotions: [CustomOption]) -> Bool {
        if let tag = EmotionTag.from(raw: record.emotionRaw) {
            return tag == .stress || tag == .impulse
        }
        return EmotionGrouping.isEmotional(record, customEmotions: customEmotions)
    }

    /// Preset pamper + ritual; custom moods in the effective bucket.
    static func isFulfillmentRecord(_ record: TransactionRecord, customEmotions: [CustomOption]) -> Bool {
        if let tag = EmotionTag.from(raw: record.emotionRaw) {
            return tag == .pamper || tag == .ritual
        }
        return EmotionGrouping.isEffective(record, customEmotions: customEmotions)
    }

    static func distressExpense(
        in expenses: [TransactionRecord],
        customEmotions: [CustomOption]
    ) -> Double {
        expenses
            .filter { isDistressRecord($0, customEmotions: customEmotions) }
            .reduce(0) { $0 + $1.amount }
    }

    static func fulfillmentEntryCount(
        in expenses: [TransactionRecord],
        customEmotions: [CustomOption]
    ) -> Int {
        expenses.filter { isFulfillmentRecord($0, customEmotions: customEmotions) }.count
    }

    static func positivePurchaseRate(in expenses: [TransactionRecord], customEmotions: [CustomOption]) -> Double {
        guard !expenses.isEmpty else { return 0 }
        let fulfilled = fulfillmentEntryCount(in: expenses, customEmotions: customEmotions)
        return Double(fulfilled) / Double(expenses.count)
    }

    static func emotionDashboardMetrics(
        currentExpenses: [TransactionRecord],
        previousExpenses: [TransactionRecord],
        customEmotions: [CustomOption]
    ) -> EmotionDashboardMetrics {
        let total = currentExpenses.reduce(0) { $0 + $1.amount }
        let distress = distressExpense(in: currentExpenses, customEmotions: customEmotions)
        let share = total > 0 ? distress / total : 0

        let currentRate = positivePurchaseRate(in: currentExpenses, customEmotions: customEmotions)
        let previousRate = positivePurchaseRate(in: previousExpenses, customEmotions: customEmotions)
        let deltaPoints: Int?
        if currentExpenses.isEmpty, previousExpenses.isEmpty {
            deltaPoints = nil
        } else if previousExpenses.isEmpty {
            deltaPoints = Int((currentRate * 100).rounded())
        } else {
            deltaPoints = Int(((currentRate - previousRate) * 100).rounded())
        }

        return EmotionDashboardMetrics(
            distressExpense: distress,
            distressShareOfTotal: share,
            fulfillmentEntryCount: fulfillmentEntryCount(in: currentExpenses, customEmotions: customEmotions),
            positivePurchaseRateDeltaPoints: deltaPoints
        )
    }

    static func litTickCount(for progressRatio: Double, tickCount: Int = 10, warningThreshold: Double = 1.0, warningUsesInclusive: Bool = false) -> Int {
        let isWarning = warningUsesInclusive
            ? progressRatio >= warningThreshold
            : progressRatio > warningThreshold
        if isWarning { return tickCount }
        return (0..<tickCount).filter { Double($0) / Double(tickCount) <= progressRatio }.count
    }

    static func negativityWeight(
        for record: TransactionRecord,
        customEmotions: [CustomOption]
    ) -> Double {
        if EmotionGrouping.isEmotional(record, customEmotions: customEmotions) {
            switch EmotionTag.from(raw: record.emotionRaw) {
            case .impulse, .stress, .social:
                return 1.0
            default:
                return 0.85
            }
        }
        if EmotionGrouping.isNecessary(record, customEmotions: customEmotions) {
            return 0.2
        }
        return 0
    }

    static func correlationDayPoints(
        expenses: [TransactionRecord],
        period: PeriodMode,
        calendar: Calendar,
        locale: Locale,
        customEmotions: [CustomOption],
        axisLabel: (Date) -> String
    ) -> [CorrelationDayPoint] {
        guard !expenses.isEmpty else { return [] }

        let buckets: [(Date, [TransactionRecord])]
        switch period {
        case .year:
            let grouped = Dictionary(grouping: expenses) { record in
                calendar.date(from: calendar.dateComponents([.year, .month], from: record.createdAt)) ?? record.createdAt
            }
            buckets = grouped.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
        default:
            let grouped = Dictionary(grouping: expenses) { record in
                calendar.startOfDay(for: record.createdAt)
            }
            buckets = grouped.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
        }

        let rawNegativities = buckets.map { pair -> Double in
            pair.1.reduce(0) { partial, record in
                partial + record.amount * negativityWeight(for: record, customEmotions: customEmotions)
            }
        }
        let maxNeg = rawNegativities.max() ?? 0
        let dailyTotals = buckets.map { $0.1.reduce(0) { $0 + $1.amount } }
        let maxExp = dailyTotals.max() ?? 0

        return zip(buckets, zip(rawNegativities, dailyTotals)).map { bucket, pair in
            let (raw, total) = pair
            let start = bucket.0
            let normNeg = maxNeg > 0 ? raw / maxNeg : 0
            let normExp = maxExp > 0 ? total / maxExp : 0
            return CorrelationDayPoint(
                id: "\(start.timeIntervalSince1970)",
                bucketStart: start,
                axisLabel: axisLabel(start),
                totalExpense: total,
                billCount: bucket.1.count,
                expenseNormalized: normExp,
                negativityNormalized: normNeg,
                negativityRaw: raw
            )
        }
    }

    /// Evenly spaced X-axis tick dates from plotted buckets (short `axisLabel` on each point).
    static func correlationXAxisTickDates(
        points: [CorrelationDayPoint],
        period: PeriodMode
    ) -> [Date] {
        let sorted = points.sorted { $0.bucketStart < $1.bucketStart }
        guard !sorted.isEmpty else { return [] }

        let desiredTickCount: Int = switch period {
        case .day: 5
        case .week: 7
        case .month, .custom: 6
        case .year: 6
        }
        let pick = min(desiredTickCount, sorted.count)
        let indices = evenlySpacedIndices(count: sorted.count, pick: pick)
        return indices.map { sorted[$0].bucketStart }
    }

    private static func evenlySpacedIndices(count: Int, pick: Int) -> [Int] {
        guard count > 0 else { return [] }
        if pick <= 1 { return [0] }
        if pick >= count { return Array(0..<count) }
        var indices: [Int] = []
        for i in 0..<pick {
            let index = Int((Double(i) * Double(count - 1) / Double(pick - 1)).rounded())
            if indices.last != index {
                indices.append(index)
            }
        }
        if indices.first != 0 { indices[0] = 0 }
        if indices.last != count - 1 {
            indices[indices.count - 1] = count - 1
        }
        return indices
    }

    static let spectrumYearWeekCount = 52

    static func spectrumStrokeHeight(amount: Double, barHeight: CGFloat = 52) -> CGFloat {
        max(6, barHeight * CGFloat(min(1, amount / 500)))
    }

    static func spectrumColumns(
        expenses: [TransactionRecord],
        period: PeriodMode,
        interval: DateInterval,
        calendar: Calendar,
        locale: Locale,
        maxStrokesPerBucket: Int = 8
    ) -> [SpectrumBucketColumn] {
        let anchor = interval.start
        switch period {
        case .day:
            return spectrumDayHourColumns(
                expenses: expenses,
                calendar: calendar,
                dayStart: calendar.startOfDay(for: anchor),
                maxStrokesPerBucket: maxStrokesPerBucket
            )
        case .week:
            return spectrumWeekDayColumns(
                expenses: expenses,
                calendar: calendar,
                locale: locale,
                weekStart: interval.start,
                maxStrokesPerBucket: maxStrokesPerBucket
            )
        case .month:
            return spectrumMonthDayColumns(
                expenses: expenses,
                calendar: calendar,
                monthStart: interval.start,
                maxStrokesPerBucket: maxStrokesPerBucket
            )
        case .year:
            return spectrumYearWeekColumns(
                expenses: expenses,
                calendar: calendar,
                yearAnchor: anchor,
                maxStrokesPerBucket: maxStrokesPerBucket
            )
        case .custom:
            return spectrumIntervalDayColumns(
                expenses: expenses,
                calendar: calendar,
                interval: interval,
                maxStrokesPerBucket: maxStrokesPerBucket
            )
        }
    }

    private static func spectrumStrokes(
        from records: [TransactionRecord],
        bucketId: String,
        maxStrokesPerBucket: Int
    ) -> [SpectrumStroke] {
        let sorted = records.sorted { $0.createdAt < $1.createdAt }
        guard !sorted.isEmpty else { return [] }
        if sorted.count <= maxStrokesPerBucket {
            return sorted.enumerated().map { index, record in
                SpectrumStroke(
                    id: "\(bucketId)-\(index)",
                    color: record.emotionColor,
                    amount: record.amount
                )
            }
        }
        let dominant = Dictionary(grouping: sorted, by: \.emotionRaw)
            .max(by: { $0.value.count < $1.value.count })
        guard let dom = dominant, let first = dom.value.first else { return [] }
        return [
            SpectrumStroke(
                id: "\(bucketId)-dom",
                color: first.emotionColor,
                amount: dom.value.reduce(0) { $0 + $1.amount }
            )
        ]
    }

    private static func spectrumDayHourColumns(
        expenses: [TransactionRecord],
        calendar: Calendar,
        dayStart: Date,
        maxStrokesPerBucket: Int
    ) -> [SpectrumBucketColumn] {
        return (0..<24).compactMap { hour -> SpectrumBucketColumn? in
            guard let bucketStart = calendar.date(byAdding: .hour, value: hour, to: dayStart),
                  let bucketEnd = calendar.date(byAdding: .hour, value: 1, to: bucketStart)
            else { return nil }
            let bucketRecords = expenses.filter {
                $0.createdAt >= bucketStart && $0.createdAt < bucketEnd
            }
            let axisLabel = hour % 6 == 0 ? "\(hour)" : nil
            return SpectrumBucketColumn(
                id: "h\(hour)",
                bucketStart: bucketStart,
                bucketIndex: hour,
                axisLabel: axisLabel,
                strokes: spectrumStrokes(from: bucketRecords, bucketId: "h\(hour)", maxStrokesPerBucket: maxStrokesPerBucket)
            )
        }
    }

    private static func spectrumWeekDayColumns(
        expenses: [TransactionRecord],
        calendar: Calendar,
        locale: Locale,
        weekStart: Date,
        maxStrokesPerBucket: Int
    ) -> [SpectrumBucketColumn] {
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.calendar = calendar
        weekdayFormatter.locale = locale
        weekdayFormatter.setLocalizedDateFormatFromTemplate("EEE")

        return (0..<7).compactMap { offset -> SpectrumBucketColumn? in
            guard let bucketStart = calendar.date(byAdding: .day, value: offset, to: weekStart),
                  let bucketEnd = calendar.date(byAdding: .day, value: 1, to: bucketStart)
            else { return nil }
            let bucketRecords = expenses.filter {
                $0.createdAt >= bucketStart && $0.createdAt < bucketEnd
            }
            let dayIndex = offset + 1
            return SpectrumBucketColumn(
                id: "d\(dayIndex)",
                bucketStart: bucketStart,
                bucketIndex: dayIndex,
                axisLabel: weekdayFormatter.string(from: bucketStart),
                strokes: spectrumStrokes(from: bucketRecords, bucketId: "d\(dayIndex)", maxStrokesPerBucket: maxStrokesPerBucket)
            )
        }
    }

    private static func spectrumMonthDayColumns(
        expenses: [TransactionRecord],
        calendar: Calendar,
        monthStart: Date,
        maxStrokesPerBucket: Int
    ) -> [SpectrumBucketColumn] {
        let dayCount = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30

        return (1...dayCount).compactMap { day -> SpectrumBucketColumn? in
            guard let bucketStart = calendar.date(byAdding: .day, value: day - 1, to: monthStart),
                  let bucketEnd = calendar.date(byAdding: .day, value: 1, to: bucketStart)
            else { return nil }
            let bucketRecords = expenses.filter {
                $0.createdAt >= bucketStart && $0.createdAt < bucketEnd
            }
            let axisLabel = day == 1 || day % 5 == 1 ? "\(day)" : nil
            return SpectrumBucketColumn(
                id: "d\(day)",
                bucketStart: bucketStart,
                bucketIndex: day,
                axisLabel: axisLabel,
                strokes: spectrumStrokes(from: bucketRecords, bucketId: "d\(day)", maxStrokesPerBucket: maxStrokesPerBucket)
            )
        }
    }

    private static func spectrumIntervalDayColumns(
        expenses: [TransactionRecord],
        calendar: Calendar,
        interval: DateInterval,
        maxStrokesPerBucket: Int
    ) -> [SpectrumBucketColumn] {
        var columns: [SpectrumBucketColumn] = []
        var dayStart = calendar.startOfDay(for: interval.start)
        let end = interval.end
        var dayIndex = 1
        while dayStart < end {
            guard let bucketEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            let bucketRecords = expenses.filter {
                $0.createdAt >= dayStart && $0.createdAt < bucketEnd
            }
            let day = calendar.component(.day, from: dayStart)
            let axisLabel = dayIndex == 1 || day % 5 == 1 ? "\(day)" : nil
            columns.append(
                SpectrumBucketColumn(
                    id: "c\(dayIndex)",
                    bucketStart: dayStart,
                    bucketIndex: dayIndex,
                    axisLabel: axisLabel,
                    strokes: spectrumStrokes(
                        from: bucketRecords,
                        bucketId: "c\(dayIndex)",
                        maxStrokesPerBucket: maxStrokesPerBucket
                    )
                )
            )
            dayStart = bucketEnd
            dayIndex += 1
        }
        return columns
    }

    private static func spectrumYearWeekColumns(
        expenses: [TransactionRecord],
        calendar: Calendar,
        yearAnchor: Date,
        maxStrokesPerBucket: Int
    ) -> [SpectrumBucketColumn] {
        let year = calendar.component(.yearForWeekOfYear, from: yearAnchor)
        return (1...spectrumYearWeekCount).compactMap { week -> SpectrumBucketColumn? in
            var comps = DateComponents()
            comps.yearForWeekOfYear = year
            comps.weekOfYear = week
            comps.weekday = calendar.firstWeekday
            guard let bucketStart = calendar.date(from: comps) else { return nil }

            let bucketRecords = expenses.filter { record in
                calendar.component(.yearForWeekOfYear, from: record.createdAt) == year &&
                    min(calendar.component(.weekOfYear, from: record.createdAt), spectrumYearWeekCount) == week
            }

            let axisLabel = week == 1 || week % 13 == 0 || week == spectrumYearWeekCount ? "\(week)" : nil
            return SpectrumBucketColumn(
                id: "w\(week)",
                bucketStart: bucketStart,
                bucketIndex: week,
                axisLabel: axisLabel,
                strokes: spectrumStrokes(from: bucketRecords, bucketId: "w\(week)", maxStrokesPerBucket: maxStrokesPerBucket)
            )
        }
    }

    static func instantJoyScore(
        for record: TransactionRecord,
        customEmotions: [CustomOption]
    ) -> Double {
        switch EmotionGrouping.bucket(for: record, customEmotions: customEmotions) {
        case .effective:
            return 0.82
        case .necessary:
            return 0.28
        case .emotional:
            switch EmotionTag.from(raw: record.emotionRaw) {
            case .impulse, .social:
                return 0.9
            case .stress:
                return 0.75
            default:
                return 0.8
            }
        }
    }

    static func longTermValueScore(for worth: RetrospectiveWorth) -> Double {
        switch worth {
        case .worthIt: return 0.88
        case .neutral: return 0.5
        case .regret: return 0.12
        }
    }

    static func retrospectiveWorthColor(for worth: RetrospectiveWorth) -> Color {
        switch worth {
        case .worthIt: return AppTheme.accentSecondary
        case .neutral: return AppTheme.textSecondary
        case .regret: return AppTheme.accentRisk
        }
    }

    static func regretQuadrantPoints(
        from expenses: [TransactionRecord],
        customEmotions: [CustomOption],
        displayName: (String, String) -> String
    ) -> [RegretQuadrantPoint] {
        expenses.compactMap { record -> RegretQuadrantPoint? in
            guard let raw = record.retrospectiveWorthRaw,
                  let worth = RetrospectiveWorth(rawValue: raw) else { return nil }
            return RegretQuadrantPoint(
                id: record.publicId.uuidString,
                recordPublicId: record.publicId,
                emotionRaw: record.emotionRaw,
                createdAt: record.createdAt,
                instantJoy: instantJoyScore(for: record, customEmotions: customEmotions),
                longTermValue: longTermValueScore(for: worth),
                worth: worth,
                feedbackColor: retrospectiveWorthColor(for: worth),
                tagColor: record.emotionColor,
                amount: record.amount,
                title: displayName(record.emotionRaw, record.safeEmotionName)
            )
        }
    }

    static func emotionalExpenseShare(
        expenses: [TransactionRecord],
        customEmotions: [CustomOption]
    ) -> Double {
        let total = expenses.reduce(0) { $0 + $1.amount }
        guard total > 0 else { return 0 }
        let emotional = expenses
            .filter { EmotionGrouping.isEmotional($0, customEmotions: customEmotions) }
            .reduce(0) { $0 + $1.amount }
        return emotional / total
    }

    /// Elevated when emotional share ≥ 40% and at least 3 expenses; balanced ≥ 15%; else calm.
    static func spectrumInsightTier(
        expenses: [TransactionRecord],
        customEmotions: [CustomOption]
    ) -> SpectrumInsightTier? {
        guard !expenses.isEmpty else { return nil }
        let share = emotionalExpenseShare(expenses: expenses, customEmotions: customEmotions)
        if share >= spectrumElevatedShareThreshold,
           expenses.count >= spectrumElevatedMinExpenseCount {
            return .elevated
        }
        if share >= spectrumBalancedShareThreshold {
            return .balanced
        }
        return .calm
    }

    static func spectrumIsPredominantlyDark(
        expenses: [TransactionRecord],
        customEmotions: [CustomOption],
        threshold: Double = spectrumElevatedShareThreshold
    ) -> Bool {
        emotionalExpenseShare(expenses: expenses, customEmotions: customEmotions) >= threshold
    }
}
