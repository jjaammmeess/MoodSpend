import Combine
import Foundation

// MARK: - Period mode (global; legacy `DateFilter` remains for report picker / home)

enum PeriodMode: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case year
    case custom

    var id: String { rawValue }

    /// Maps to legacy `DateFilter` for copy templates that still use four natural buckets.
    var dateFilterEquivalent: DateFilter {
        switch self {
        case .day: return .day
        case .week: return .week
        case .month, .custom: return .month
        case .year: return .year
        }
    }
}

// MARK: - Custom same-year month span

struct CustomMonthRange: Equatable {
    var year: Int
    var startMonth: Int
    var endMonth: Int

    mutating func normalize() {
        guard startMonth > endMonth else { return }
        swap(&startMonth, &endMonth)
    }

    var normalized: CustomMonthRange {
        var copy = self
        copy.normalize()
        return copy
    }

    func contains(month: Int) -> Bool {
        let range = normalized
        return month >= range.startMonth && month <= range.endMonth
    }
}

// MARK: - Paywall gate result

enum AppPeriodPaywallGate {
    case applied
    case requiresPaywall
}

// MARK: - App-wide period context

/// Shared timeline state for bill list + mood review (anchored periods + optional custom month span).
@MainActor
final class AppPeriodContext: ObservableObject {
    static let shared = AppPeriodContext()

    @Published var selectedPeriod: PeriodMode = .month
    @Published var targetDate: Date = Date()
    @Published var customRange: CustomMonthRange?

    /// Gregorian calendar with user `firstDayOfWeek` and current locale (never `Calendar.current` for week math).
    var calendar: Calendar {
        AppCalendar.make(locale: Locale.current)
    }

    var now: Date = Date()

    private init() {
        FirstDayOfWeek.registerDefaults()
    }

    /// Re-anchor week navigation after the user changes「每周起始日」.
    func applyFirstDayOfWeekChange() {
        refreshNow()
        if selectedPeriod == .week,
           let weekStart = calendar.dateInterval(of: .weekOfYear, for: targetDate)?.start {
            targetDate = weekStart
        }
        objectWillChange.send()
    }

    // MARK: Active interval

    /// Half-open range `[start, end)` for in-memory record filtering.
    var dateInterval: DateInterval? {
        interval(for: selectedPeriod, targetDate: targetDate, customRange: customRange)
    }

    /// Prior period of the same granularity (dashboard deltas).
    var previousComparisonInterval: DateInterval? {
        previousInterval(
            for: selectedPeriod,
            targetDate: targetDate,
            customRange: customRange
        )
    }

    func recordIsInPeriod(_ date: Date) -> Bool {
        guard let interval = dateInterval else { return false }
        return date >= interval.start && date < interval.end
    }

    func recordIsInPreviousPeriod(_ date: Date) -> Bool {
        guard let interval = previousComparisonInterval else { return false }
        return date >= interval.start && date < interval.end
    }

    // MARK: Free vs Pro window
    //
    // Free tier retention policy:
    // - Day / week: unrestricted backward shuttle; forward until current day/week (symmetric).
    // - Month / custom: current natural month + previous calendar month; older spans need Pro.
    // - Custom (free): single month only within that window; multi-month spans need Pro.
    // - Year: blocked at tab select.

    /// Whether `date`'s calendar month is the current month or the immediately prior month (relative to `now`).
    func isInFreeMonthRetentionWindow(_ date: Date) -> Bool {
        Self.isMonthInFreeRetentionWindow(
            year: calendar.component(.year, from: date),
            month: calendar.component(.month, from: date),
            calendar: calendar,
            now: now
        )
    }

    /// Whether every month in `range` lies in the free retention window.
    func isCustomRangeInFreeRetentionWindow(_ range: CustomMonthRange) -> Bool {
        Self.isCustomRangeInFreeRetentionWindow(range, calendar: calendar, now: now)
    }

    /// Free custom period: exactly one calendar month, and that month is this month or last month.
    func isCustomRangeAllowedForFreeUser(_ range: CustomMonthRange) -> Bool {
        Self.isCustomRangeAllowedForFreeUser(range, calendar: calendar, now: now)
    }

    /// Reverts month/custom anchors that fall outside the free retention window (e.g. after subscription lapse).
    func clampToFreeRetentionWindowIfNeeded(isPro: Bool) {
        guard !isPro else { return }
        refreshNow()
        switch selectedPeriod {
        case .month:
            if !isInFreeMonthRetentionWindow(targetDate) {
                snapToCurrentNaturalMonth()
            }
        case .custom:
            if let range = customRange, !isCustomRangeAllowedForFreeUser(range) {
                resetToCurrentMonth()
            }
        case .day, .week, .year:
            break
        }
    }

    func isAnchorInFreeWindow(for mode: PeriodMode) -> Bool {
        switch mode {
        case .day, .week:
            return true
        case .month:
            return isInFreeMonthRetentionWindow(targetDate)
        case .custom:
            guard let customRange else { return false }
            return isCustomRangeAllowedForFreeUser(customRange)
        case .year:
            return false
        }
    }

    /// Month offsets from anchor month start to current month start (`0` = this month, `1` = last month).
    static func monthsBeforeCurrentMonth(
        for date: Date,
        calendar: Calendar,
        now: Date
    ) -> Int? {
        guard let anchorStart = calendar.dateInterval(of: .month, for: date)?.start,
              let currentStart = calendar.dateInterval(of: .month, for: now)?.start
        else { return nil }
        return calendar.dateComponents([.month], from: anchorStart, to: currentStart).month
    }

    /// Whether the calendar month is the current month or earlier (future months are not selectable).
    static func isMonthAtOrBeforeCurrentMonth(
        year: Int,
        month: Int,
        calendar: Calendar,
        now: Date
    ) -> Bool {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let monthStart = calendar.date(from: components),
              let currentStart = calendar.dateInterval(of: .month, for: now)?.start
        else { return false }
        return monthStart <= currentStart
    }

    /// Last month index (1...12) selectable in `year` relative to `now`; `nil` when the whole year is in the future.
    static func maxSelectableMonth(
        in year: Int,
        calendar: Calendar,
        now: Date
    ) -> Int? {
        let currentYear = calendar.component(.year, from: now)
        if year > currentYear { return nil }
        if year < currentYear { return 12 }
        return calendar.component(.month, from: now)
    }

    static func isCustomRangeWithinSelectableMonths(
        _ range: CustomMonthRange,
        calendar: Calendar,
        now: Date
    ) -> Bool {
        let normalized = range.normalized
        for month in normalized.startMonth...normalized.endMonth {
            if !isMonthAtOrBeforeCurrentMonth(
                year: normalized.year,
                month: month,
                calendar: calendar,
                now: now
            ) {
                return false
            }
        }
        return true
    }

    /// Truncates `endMonth` to the last non-future month in `year`; returns `nil` if the range is entirely in the future.
    static func clampCustomRangeToSelectableMonths(
        _ range: CustomMonthRange,
        calendar: Calendar,
        now: Date
    ) -> CustomMonthRange? {
        let normalized = range.normalized
        guard let maxMonth = maxSelectableMonth(in: normalized.year, calendar: calendar, now: now) else {
            return nil
        }
        let start = normalized.startMonth
        let end = min(normalized.endMonth, maxMonth)
        guard start <= maxMonth, start <= end else { return nil }
        return CustomMonthRange(year: normalized.year, startMonth: start, endMonth: end)
    }

    /// Custom picker cell: never future; free tier also requires the two-month retention window.
    static func isMonthSelectableInCustomPicker(
        year: Int,
        month: Int,
        calendar: Calendar,
        now: Date,
        isPro: Bool
    ) -> Bool {
        guard isMonthAtOrBeforeCurrentMonth(year: year, month: month, calendar: calendar, now: now) else {
            return false
        }
        if isPro { return true }
        return isMonthInFreeRetentionWindow(
            year: year,
            month: month,
            calendar: calendar,
            now: now
        )
    }

    static func isMonthInFreeRetentionWindow(
        year: Int,
        month: Int,
        calendar: Calendar,
        now: Date
    ) -> Bool {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let date = calendar.date(from: components),
              let offset = monthsBeforeCurrentMonth(for: date, calendar: calendar, now: now)
        else { return false }
        return offset >= 0 && offset <= 1
    }

    static func isCustomRangeInFreeRetentionWindow(
        _ range: CustomMonthRange,
        calendar: Calendar,
        now: Date
    ) -> Bool {
        let normalized = range.normalized
        for month in normalized.startMonth...normalized.endMonth {
            if !isMonthInFreeRetentionWindow(
                year: normalized.year,
                month: month,
                calendar: calendar,
                now: now
            ) {
                return false
            }
        }
        return true
    }

    static func isSingleMonthCustomRange(_ range: CustomMonthRange) -> Bool {
        let normalized = range.normalized
        return normalized.startMonth == normalized.endMonth
    }

    static func isCustomRangeAllowedForFreeUser(
        _ range: CustomMonthRange,
        calendar: Calendar,
        now: Date
    ) -> Bool {
        guard isSingleMonthCustomRange(range) else { return false }
        let normalized = range.normalized
        return isMonthInFreeRetentionWindow(
            year: normalized.year,
            month: normalized.startMonth,
            calendar: calendar,
            now: now
        )
    }

    /// Years that contain at least one month in the free retention window (for custom picker).
    static func freeRetentionYears(calendar: Calendar, now: Date) -> [Int] {
        guard let currentStart = calendar.dateInterval(of: .month, for: now)?.start else {
            return [calendar.component(.year, from: now)]
        }
        var years = Set<Int>()
        years.insert(calendar.component(.year, from: currentStart))
        if let previousStart = calendar.date(byAdding: .month, value: -1, to: currentStart) {
            years.insert(calendar.component(.year, from: previousStart))
        }
        return years.sorted(by: >)
    }

    func canStepForward(isPro: Bool) -> Bool {
        if isPro { return !isAtLatestAnchor(for: selectedPeriod) }
        switch selectedPeriod {
        case .day, .week:
            return !isAtLatestAnchor(for: selectedPeriod)
        case .month:
            return isInFreeMonthRetentionWindow(targetDate) && !isAtLatestAnchor(for: .month)
        case .year, .custom:
            return false
        }
    }

    func canStepBackward(isPro: Bool) -> Bool {
        if isPro { return hasEarlierAnchor(for: selectedPeriod) }
        switch selectedPeriod {
        case .day, .week:
            return hasEarlierAnchor(for: selectedPeriod)
        case .month:
            return isInFreeMonthRetentionWindow(targetDate) && hasEarlierAnchor(for: .month)
        case .year, .custom:
            return false
        }
    }

    // MARK: Mutations

    @discardableResult
    func selectPeriod(_ mode: PeriodMode, isPro: Bool) -> AppPeriodPaywallGate {
        if mode == .year, !isPro {
            resetToCurrentMonth()
            return .requiresPaywall
        }

        if mode == .custom,
           !isPro,
           let range = customRange,
           !isCustomRangeAllowedForFreeUser(range) {
            resetToCurrentMonth()
            return .requiresPaywall
        }

        selectedPeriod = mode

        switch mode {
        case .custom:
            if customRange == nil {
                return .applied
            }
            alignTargetDateToCustomRange()
        case .day, .week, .month, .year:
            snapToCurrentPeriod(for: mode)
        }
        return .applied
    }

    @discardableResult
    func stepBackward(isPro: Bool) -> AppPeriodPaywallGate {
        guard selectedPeriod != .custom else { return .applied }
        guard let stepped = shiftedAnchor(by: -1, mode: selectedPeriod) else { return .applied }

        if isPro {
            targetDate = stepped
            return .applied
        }

        switch selectedPeriod {
        case .day, .week:
            targetDate = stepped
            return .applied
        case .month:
            if isInFreeMonthRetentionWindow(stepped) {
                targetDate = stepped
                return .applied
            }
            return .requiresPaywall
        case .year:
            return .requiresPaywall
        case .custom:
            return .applied
        }
    }

    @discardableResult
    func stepForward(isPro: Bool) -> AppPeriodPaywallGate {
        guard selectedPeriod != .custom else { return .applied }
        guard let stepped = shiftedAnchor(by: 1, mode: selectedPeriod) else { return .applied }
        guard !isAnchorAfterNow(stepped, mode: selectedPeriod) else { return .applied }

        if isPro {
            targetDate = stepped
            return .applied
        }

        switch selectedPeriod {
        case .day, .week:
            targetDate = stepped
            return .applied
        case .month:
            if isInFreeMonthRetentionWindow(stepped) {
                targetDate = stepped
            }
            return .applied
        case .year:
            return .requiresPaywall
        case .custom:
            return .applied
        }
    }

    func applyCustomRange(_ range: CustomMonthRange) {
        refreshNow()
        let normalized = range.normalized
        guard let clamped = Self.clampCustomRangeToSelectableMonths(
            normalized,
            calendar: calendar,
            now: now
        ) else { return }
        customRange = clamped
        selectedPeriod = .custom
        alignTargetDateToCustomRange()
    }

    func resetToCurrentMonth() {
        selectedPeriod = .month
        snapToCurrentNaturalMonth()
    }

    /// Keeps `selectedPeriod`, snaps anchor to today / this week / this month / this year.
    func snapToCurrentPeriod(for mode: PeriodMode) {
        refreshNow()
        if mode != .custom {
            customRange = nil
        }
        switch mode {
        case .day:
            targetDate = calendar.startOfDay(for: now)
        case .week:
            if let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start {
                targetDate = weekStart
            } else {
                targetDate = now
            }
        case .month:
            if let monthStart = calendar.dateInterval(of: .month, for: now)?.start {
                targetDate = monthStart
            } else {
                targetDate = now
            }
        case .year:
            if let yearStart = calendar.dateInterval(of: .year, for: now)?.start {
                targetDate = yearStart
            } else {
                targetDate = now
            }
        case .custom:
            break
        }
    }

    /// Keeps `selectedPeriod`, snaps anchor to the start of the current natural month.
    func snapToCurrentNaturalMonth() {
        snapToCurrentPeriod(for: .month)
    }

    /// Safe rollback when Paywall closes without purchase (mode-aware).
    func rollbackAfterFreePaywallDismiss() {
        refreshNow()
        switch selectedPeriod {
        case .month:
            snapToCurrentNaturalMonth()
        case .day, .week:
            break
        case .year, .custom:
            resetToCurrentMonth()
        }
    }

    func refreshNow() {
        now = Date()
    }

    // MARK: Year discovery

    static func availableYears(
        from records: [TransactionRecord],
        calendar: Calendar = AppCalendar.make(),
        now: Date = Date()
    ) -> [Int] {
        let years = records.map { calendar.component(.year, from: $0.createdAt) }
        let currentYear = calendar.component(.year, from: now)
        guard let minYear = years.min(), let maxYear = years.max() else {
            return [currentYear]
        }
        return Array(minYear...max(maxYear, currentYear)).sorted(by: >)
    }

    // MARK: Interval math

    func interval(
        for mode: PeriodMode,
        targetDate: Date,
        customRange: CustomMonthRange?
    ) -> DateInterval? {
        switch mode {
        case .day:
            return calendar.dateInterval(of: .day, for: targetDate)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: targetDate)
        case .month:
            return calendar.dateInterval(of: .month, for: targetDate)
        case .year:
            return calendar.dateInterval(of: .year, for: targetDate)
        case .custom:
            guard let customRange else { return nil }
            return Self.customMonthInterval(for: customRange.normalized, calendar: calendar)
        }
    }

    func previousInterval(
        for mode: PeriodMode,
        targetDate: Date,
        customRange: CustomMonthRange?
    ) -> DateInterval? {
        switch mode {
        case .day:
            guard let dayStart = calendar.dateInterval(of: .day, for: targetDate)?.start,
                  let previousDay = calendar.date(byAdding: .day, value: -1, to: dayStart)
            else { return nil }
            return calendar.dateInterval(of: .day, for: previousDay)

        case .week:
            guard let current = calendar.dateInterval(of: .weekOfYear, for: targetDate)?.start,
                  let prevStart = calendar.date(byAdding: .weekOfYear, value: -1, to: current)
            else { return nil }
            return calendar.dateInterval(of: .weekOfYear, for: prevStart)

        case .month:
            guard let current = calendar.dateInterval(of: .month, for: targetDate)?.start,
                  let prevStart = calendar.date(byAdding: .month, value: -1, to: current)
            else { return nil }
            return calendar.dateInterval(of: .month, for: prevStart)

        case .year:
            guard let current = calendar.dateInterval(of: .year, for: targetDate)?.start,
                  let prevStart = calendar.date(byAdding: .year, value: -1, to: current)
            else { return nil }
            return calendar.dateInterval(of: .year, for: prevStart)

        case .custom:
            guard let customRange else { return nil }
            let span = customRange.normalized.endMonth - customRange.normalized.startMonth + 1
            let prevEnd = customRange.normalized.startMonth - 1
            let prevStart = prevEnd - span + 1
            if prevStart < 1 { return nil }
            return Self.customMonthInterval(
                for: CustomMonthRange(year: customRange.year, startMonth: prevStart, endMonth: prevEnd),
                calendar: calendar
            )
        }
    }

    static func customMonthInterval(
        for range: CustomMonthRange,
        calendar: Calendar
    ) -> DateInterval? {
        var startComponents = DateComponents()
        startComponents.year = range.year
        startComponents.month = range.startMonth
        startComponents.day = 1
        guard let start = calendar.date(from: startComponents) else { return nil }

        var endComponents = DateComponents()
        endComponents.year = range.year
        endComponents.month = range.endMonth + 1
        endComponents.day = 1
        guard let end = calendar.date(from: endComponents) else { return nil }
        return DateInterval(start: start, end: end)
    }

    // MARK: Private helpers

    private func alignTargetDateToCustomRange() {
        guard let customRange else { return }
        var components = DateComponents()
        components.year = customRange.year
        components.month = customRange.startMonth
        components.day = 1
        if let start = calendar.date(from: components) {
            targetDate = start
        }
    }

    private func shiftedAnchor(by offset: Int, mode: PeriodMode) -> Date? {
        switch mode {
        case .day:
            return calendar.date(byAdding: .day, value: offset, to: targetDate)
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: offset, to: targetDate)
        case .month:
            return calendar.date(byAdding: .month, value: offset, to: targetDate)
        case .year:
            return calendar.date(byAdding: .year, value: offset, to: targetDate)
        case .custom:
            return nil
        }
    }

    private func hasEarlierAnchor(for mode: PeriodMode) -> Bool {
        shiftedAnchor(by: -1, mode: mode) != nil
    }

    /// Whether `targetDate` already sits in the same calendar bucket as `now` (cannot `[ > ]` further).
    private func isAtLatestAnchor(for mode: PeriodMode) -> Bool {
        isSamePeriod(anchor: targetDate, as: now, mode: mode)
    }

    /// Whether `date` lies in a period strictly after the one containing `now`.
    private func isAnchorAfterNow(_ date: Date, mode: PeriodMode) -> Bool {
        guard let anchorStart = periodStart(for: date, mode: mode),
              let nowStart = periodStart(for: now, mode: mode)
        else { return false }
        return anchorStart > nowStart
    }

    private func isSamePeriod(anchor: Date, as other: Date, mode: PeriodMode) -> Bool {
        switch mode {
        case .day:
            return calendar.isDate(anchor, inSameDayAs: other)
        case .week:
            return calendar.isDate(anchor, equalTo: other, toGranularity: .weekOfYear)
                && calendar.isDate(anchor, equalTo: other, toGranularity: .yearForWeekOfYear)
        case .month:
            return calendar.isDate(anchor, equalTo: other, toGranularity: .month)
                && calendar.isDate(anchor, equalTo: other, toGranularity: .year)
        case .year:
            return calendar.isDate(anchor, equalTo: other, toGranularity: .year)
        case .custom:
            return false
        }
    }

    private func periodStart(for date: Date, mode: PeriodMode) -> Date? {
        switch mode {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start
        case .month:
            return calendar.dateInterval(of: .month, for: date)?.start
        case .year:
            return calendar.dateInterval(of: .year, for: date)?.start
        case .custom:
            return nil
        }
    }

    func navigationTitle(
        localize: (LKey) -> String,
        locale: Locale
    ) -> String {
        switch selectedPeriod {
        case .day:
            return AppFormatter.dayString(from: targetDate, locale: locale)
        case .week:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: targetDate) else {
                return localize(.billsPeriodNavWeekFallback)
            }
            let start = AppFormatter.dayString(from: interval.start, locale: locale)
            let end = AppFormatter.dayString(from: interval.end.addingTimeInterval(-1), locale: locale)
            return String(
                format: localize(.billsPeriodNavWeekRange),
                locale: locale,
                arguments: [start, end]
            )
        case .month:
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.setLocalizedDateFormatFromTemplate("yyyyMMMM")
            return formatter.string(from: targetDate)
        case .year:
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.setLocalizedDateFormatFromTemplate("yyyy")
            return formatter.string(from: targetDate)
        case .custom:
            return localize(.billsPeriodCustomUnset)
        }
    }

    func customRangeStatusText(
        localize: (LKey) -> String,
        locale: Locale
    ) -> String? {
        guard selectedPeriod == .custom, let customRange else { return nil }
        let normalized = customRange.normalized
        return String(
            format: localize(.billsPeriodCustomLocked),
            locale: locale,
            arguments: [
                AppFormatter.plainInteger(normalized.year),
                normalized.startMonth,
                normalized.endMonth
            ]
        )
    }

    // MARK: - Bill list insight copy (custom range)

    /// Prior span of equal month count immediately before `range` (same calendar year).
    static func previousCustomRange(before range: CustomMonthRange) -> CustomMonthRange? {
        let normalized = range.normalized
        let span = normalized.endMonth - normalized.startMonth + 1
        let prevEnd = normalized.startMonth - 1
        let prevStart = prevEnd - span + 1
        guard prevStart >= 1 else { return nil }
        return CustomMonthRange(
            year: normalized.year,
            startMonth: prevStart,
            endMonth: prevEnd
        )
    }

    /// Sentence opener for insights, e.g. 「在 2025年08月–12月 这段区间里，」
    static func insightClause(
        for range: CustomMonthRange,
        localize: (LKey) -> String,
        locale: Locale
    ) -> String {
        let normalized = range.normalized
        if normalized.startMonth == normalized.endMonth {
            return String(
                format: localize(.billsInsightCustomClauseSingleMonth),
                locale: locale,
                arguments: [
                    AppFormatter.plainInteger(normalized.year),
                    normalized.startMonth
                ]
            )
        }
        return String(
            format: localize(.billsInsightCustomClauseRange),
            locale: locale,
            arguments: [
                AppFormatter.plainInteger(normalized.year),
                normalized.startMonth,
                normalized.endMonth
            ]
        )
    }

    /// Short range label for compare copy, e.g. 「2025年08月–12月」
    static func insightRangeLabel(
        for range: CustomMonthRange,
        localize: (LKey) -> String,
        locale: Locale
    ) -> String {
        let normalized = range.normalized
        if normalized.startMonth == normalized.endMonth {
            return String(
                format: localize(.billsInsightCustomRangeLabelSingleMonth),
                locale: locale,
                arguments: [
                    AppFormatter.plainInteger(normalized.year),
                    normalized.startMonth
                ]
            )
        }
        return String(
            format: localize(.billsInsightCustomRangeLabelRange),
            locale: locale,
            arguments: [
                AppFormatter.plainInteger(normalized.year),
                normalized.startMonth,
                normalized.endMonth
            ]
        )
    }

}
