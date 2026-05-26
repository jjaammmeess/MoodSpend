import SwiftData
import SwiftUI

private struct EmotionTrendLegendDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .frame(width: 10, height: 10)
    }
}

struct InsightFeatureBadge: Identifiable {
    let id: String
    let systemImage: String
    let label: String
    let count: Int
}

struct GeneratedInsight {
    let badges: [InsightFeatureBadge]
    let ineffectiveRatio: Double
    let prescriptionAdvice: String
    /// No expenses in the selected period.
    let isEmpty: Bool
    /// Has expenses but not enough for pattern badges / share bar.
    let isSparseSample: Bool
}

struct EmotionHeatmapCell: Identifiable {
    let id: String
    let weekdayLabel: String
    let timeLabel: String
    let value: Double
    let normalized: Double
    let dominantEmotionColor: Color
    let hasConsumption: Bool
    let phaseOffset: Double

    var bubbleDiameter: CGFloat {
        guard hasConsumption else { return 1 }
        return 4 + (24 - 4) * CGFloat(normalized)
    }
}

struct AnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.isTabActive) private var isTabActive
    @EnvironmentObject private var analysisMetricsStore: AnalysisTabMetricsStore
    @EnvironmentObject private var analysisScrollActivity: AnalysisScrollActivityTracker
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var appSettings: AppSettings
    @EnvironmentObject private var notificationStore: NotificationCenterStore
    @EnvironmentObject private var rootTab: RootTabCoordinator
    @EnvironmentObject private var periodContext: AppPeriodContext
    @Query(
        filter: #Predicate<TransactionRecord> { $0.deletedAt == nil },
        sort: \TransactionRecord.createdAt,
        order: .reverse
    ) private var records: [TransactionRecord]
    @Query(
        filter: #Predicate<CustomOption> { $0.deletedAt == nil },
        sort: \CustomOption.createdAt,
        order: .reverse
    ) private var customOptions: [CustomOption]
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false
    @State private var paywallSource: PaywallSource = .general
    @State private var pendingEmotionTrend60Selection = false
    @State private var showCustomPicker = false
    @State private var calendarDisplayMonth = Date()
    @State private var monthPickerYear: Int = Calendar.current.component(.year, from: Date())
    @State private var monthPickerMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var calendarMonthPickerSnapshot = Date()
    @State private var monthPickerKeepChangesOnDismiss = false
    @State private var showCalendarMonthPickerSheet = false
    @State private var selectedCalendarDate: Date?
    @State private var showDayRecords = false
    @State private var emotionReportScope: EmotionReportScope?
    @State private var showReportScopeUnavailableAlert = false
    @State private var retrospectiveSheetRecord: TransactionRecord?
    @State private var regretTappedRecord: TransactionRecord?
    @State private var correlationInspect: CorrelationInspectSession?
    @State private var dashboardDetailSession: AnalysisDashboardDetailSession?
    @State private var spectrumAnimationEpoch = 0
    @State private var didPlaySpectrumEntrance = false
    @State private var retrospectiveEnqueueTask: Task<Void, Never>?
    @State private var metricsCache: AnalysisViewMetricsCache
    @State private var chartMetricsRefreshTask: Task<Void, Never>?
    @State private var heatmapCellsRefreshTask: Task<Void, Never>?
    @State private var correlationChartContentOpacity: Double = 1
    @State private var pendingReviewAfterCustomRangeApply = false
    @State private var isRecomputingCharts = false
    @State private var cachedTrendChartBuckets: [EmotionTrendChartBucket]
    @State private var cachedHeatmapCells: [EmotionHeatmapCell]
    @State private var cachedGeneratedInsight: GeneratedInsight
    @State private var chartMotionMode: AnalysisChartMotionMode = .live
    @State private var lastAppliedPeriodMetricsToken: String?
    @State private var cachedFilteredExpenses: [TransactionRecord] = []
    @State private var cachedPreviousPeriodFilteredExpenses: [TransactionRecord] = []
    @State private var cachedEmotionTrendWindowExpenses: [TransactionRecord] = []
    @State private var cachedEmotionTrendLegend: [(key: String, label: String, color: Color)] = []
    @State private var cachedEmotionTrendYAxisTicks: [Double] = [0, 1]
    @State private var cachedEmotionTrendYAxisTop: Double = 1
    @State private var cachedEmotionTrendStackGap: Double = 0
    @State private var cachedEmotionTrendXAxisTickLabels: [String] = []
    @State private var cachedEmotionTrendInsightCaption: String = ""
    @State private var cachedEmotionTrendInsightAccent: Color = AppTheme.accentInsight

    init(initialSnapshot: AnalysisTabMetricsSnapshot? = nil) {
        _metricsCache = State(initialValue: initialSnapshot?.metricsCache ?? .empty)
        _cachedTrendChartBuckets = State(initialValue: initialSnapshot?.trendBuckets ?? [])
        _cachedHeatmapCells = State(initialValue: initialSnapshot?.heatmapCells ?? [])
        _cachedGeneratedInsight = State(
            initialValue: initialSnapshot?.generatedInsight ?? GeneratedInsight(
                badges: [],
                ineffectiveRatio: 0,
                prescriptionAdvice: "",
                isEmpty: true,
                isSparseSample: false
            )
        )
    }

    /// Rolling window for the emotion trend chart only (independent of top period shuttle).
    private enum EmotionTrendWindow: String, CaseIterable, Identifiable {
        case today
        case last7
        case last14
        case last30
        case last60
        var id: String { rawValue }
    }

    @State private var emotionTrendWindow: EmotionTrendWindow = .last7

    private enum EmotionHeatmapMeasure: String, CaseIterable, Identifiable {
        case amount
        case count
        var id: String { rawValue }
    }

    @State private var emotionHeatmapMeasure: EmotionHeatmapMeasure = .amount
    @State private var showHeatmapGuide = false

    private static let emotionTrendOtherKey = "__other__"

    private var customEmotionOptions: [CustomOption] {
        customOptions.filter { $0.kind == .emotion }
    }

    private var filteredExpenses: [TransactionRecord] {
        cachedFilteredExpenses
    }

    private var totalExpense: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }

    private var recordCount: Int {
        filteredExpenses.count
    }

    private var previousPeriodFilteredExpenses: [TransactionRecord] {
        cachedPreviousPeriodFilteredExpenses
    }

    private var emotionDashboardMetrics: AnalysisChartMetrics.EmotionDashboardMetrics {
        AnalysisChartMetrics.emotionDashboardMetrics(
            currentExpenses: filteredExpenses,
            previousExpenses: previousPeriodFilteredExpenses,
            customEmotions: customEmotionOptions
        )
    }

    private var emotionDashboardModel: AnalysisEmotionDashboardModel {
        let metrics = emotionDashboardMetrics
        let sharePercent = Int((metrics.distressShareOfTotal * 100).rounded())
        return AnalysisEmotionDashboardModel(
            distressTitle: localization.text(.analysisDashboardDistressTitle),
            distressExpenseAmount: metrics.distressExpense,
            distressShareText: localizedTemplate(.analysisDashboardDistressShare, "\(sharePercent)"),
            distressShareTrend: distressShareTrend(for: metrics.distressShareOfTotal),
            distressShareA11y: localizedTemplate(.analysisDashboardDistressShareA11y, "\(sharePercent)"),
            fulfillmentTitle: localization.text(.analysisDashboardFulfillmentTitle),
            fulfillmentEntryCount: metrics.fulfillmentEntryCount,
            entriesLabel: localization.text(.analysisDashboardEntries),
            positiveRateDeltaText: positiveRateDeltaDisplayText,
            positiveRateDeltaTrend: positiveRateDeltaTrend(
                points: emotionDashboardMetrics.positivePurchaseRateDeltaPoints
            )
        )
    }

    private func distressShareTrend(for share: Double) -> MetricTrendDeltaCapsule.Trend {
        if share >= 0.9 { return .up }
        if share > 0, share <= 0.3 { return .down }
        return .neutral
    }

    /// Pro custom-range apply: review only after range is locked and period charts have refreshed.
    private func consumePendingCustomRangeReviewIfNeeded(customRange: CustomMonthRange?) {
        guard pendingReviewAfterCustomRangeApply else { return }
        guard subscriptionManager.isPro else {
            pendingReviewAfterCustomRangeApply = false
            return
        }
        guard periodContext.selectedPeriod == .custom, customRange != nil else { return }

        pendingReviewAfterCustomRangeApply = false
        let distressShare = emotionDashboardMetrics.distressShareOfTotal
        AppReviewManager.shared.considerReviewAfterCustomEmotionDashboard(
            distressShareOfTotal: distressShare
        )
    }

    private func positiveRateDeltaTrend(points: Int?) -> MetricTrendDeltaCapsule.Trend {
        guard let points else { return .neutral }
        if points == 0 { return .flat }
        if points > 0 { return .down }
        return .up
    }

    private func openDashboardDistressDetail() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dashboardDetailSession = AnalysisDashboardDetailSession(kind: .distress)
    }

    private func openDashboardFulfillmentDetail() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dashboardDetailSession = AnalysisDashboardDetailSession(kind: .fulfillment)
    }

    private var positiveRateDeltaDisplayText: String? {
        let periodLabel = localization.text(dashboardComparePeriodKey)
        guard let points = emotionDashboardMetrics.positivePurchaseRateDeltaPoints else {
            return localizedTemplate(.analysisDashboardPositiveRateDeltaUnavailable, periodLabel)
        }
        if points == 0 {
            return localizedTemplate(.analysisDashboardPositiveRateDeltaFlat, periodLabel)
        }
        if points > 0 {
            return localizedTemplate(.analysisDashboardPositiveRateDeltaUp, "\(points)", periodLabel)
        }
        return localizedTemplate(.analysisDashboardPositiveRateDeltaDown, "\(points)", periodLabel)
    }

    private var dashboardComparePeriodKey: LKey {
        switch periodContext.selectedPeriod {
        case .day: return .billsDashboardComparePeriodDay
        case .week: return .billsDashboardComparePeriodWeek
        case .month: return .billsDashboardComparePeriodMonth
        case .year: return .billsDashboardComparePeriodYear
        case .custom: return .analysisDashboardComparePeriodCustom
        }
    }

    private var periodMetricsToken: String {
        let customToken: String = {
            guard let range = periodContext.customRange else { return "-" }
            return "\(range.year)-\(range.startMonth)-\(range.endMonth)"
        }()
        return "\(periodContext.selectedPeriod.rawValue)|\(periodContext.targetDate.timeIntervalSince1970)|\(customToken)"
    }

    private func moneyText(_ amount: Double) -> String {
        AppFormatter.moneyString(from: amount, locale: localization.locale)
    }

    private var analysisHeatRingSlices: [AnalysisChartMetrics.HeatRingSlice] {
        metricsCache.heatRingSlices
    }

    private var correlationPoints: [AnalysisChartMetrics.CorrelationDayPoint] {
        metricsCache.correlationPoints
    }

    private var correlationWarmTip: String {
        metricsCache.correlationWarmTip
    }

    private var emotionSpectrumColumns: [AnalysisChartMetrics.SpectrumBucketColumn] {
        metricsCache.emotionSpectrumColumns
    }

    private var spectrumInsight: AnalysisChartMetrics.SpectrumInsight? {
        metricsCache.spectrumInsight
    }

    private var regretQuadrantPoints: [AnalysisChartMetrics.RegretQuadrantPoint] {
        metricsCache.regretQuadrantPoints
    }

    private var metricsRecomputeToken: String {
        "\(periodMetricsToken)|\(records.count)|\(customEmotionOptions.count)|\(localization.effectiveLanguage.rawValue)|\(appSettings.firstDayOfWeek.rawValue)|\(emotionTrendWindow.rawValue)"
    }

    /// True while heavy chart metrics are being built and we have expenses but no chart payload yet.
    private var showsChartsLoading: Bool {
        isRecomputingCharts && !records.isEmpty
    }

    private func correlationAxisLabel(for date: Date) -> String {
        let df = DateFormatter()
        df.locale = localization.locale
        df.calendar = calendarForAnalysisGrid
        switch periodContext.selectedPeriod {
        case .year:
            df.setLocalizedDateFormatFromTemplate("MMM")
        case .day, .week, .month, .custom:
            df.setLocalizedDateFormatFromTemplate("Md")
        }
        return df.string(from: date)
    }

    private func presentRetrospectiveFromPending() {
        defer {
            notificationStore.pendingRetrospectivePersistentToken = nil
            notificationStore.pendingRetrospectivePublicId = nil
        }

        if let pid = notificationStore.pendingRetrospectivePublicId,
           let record = records.first(where: { $0.publicId == pid }) {
            retrospectiveSheetRecord = record
            return
        }

        guard let token = notificationStore.pendingRetrospectivePersistentToken,
              let item = notificationStore.items.first(where: { $0.linkedRecordPersistentToken == token }),
              let pid = item.linkedRecordId,
              let record = records.first(where: { $0.publicId == pid }) else {
            return
        }
        retrospectiveSheetRecord = record
    }

    private func enqueueRetrospectiveReviewTasks() {
        RetrospectiveReviewService.enqueueReviewNotifications(
            records: records,
            customEmotions: customEmotionOptions,
            store: notificationStore,
            localizedText: localization.text,
            title: localization.text(.notificationRetrospectiveTitle),
            messageTemplate: { emotion, amount, destination in
                String(
                    format: localization.text(.notificationRetrospectiveBody),
                    locale: localization.locale,
                    arguments: [emotion, amount, destination]
                )
            },
            money: { amt in
                AppFormatter.moneyString(from: amt, locale: localization.locale)
            },
            displayEmotion: { r in
                displayEmotionName(raw: r.emotionRaw, fallback: r.safeEmotionName)
            }
        )
    }

    private func openCorrelationBucket(_ bucketStart: Date) {
        let cal = calendarForAnalysisGrid
        let list: [TransactionRecord]
        switch periodContext.selectedPeriod {
        case .year:
            guard let interval = cal.dateInterval(of: .month, for: bucketStart) else { return }
            list = records.filter { $0.type == .expense && $0.createdAt >= interval.start && $0.createdAt < interval.end }
                .sorted { $0.createdAt > $1.createdAt }
        default:
            list = records.filter { $0.type == .expense && cal.isDate($0.createdAt, inSameDayAs: bucketStart) }
                .sorted { $0.createdAt > $1.createdAt }
        }
        correlationInspect = CorrelationInspectSession(bucketStart: bucketStart, records: list)
    }

    private func syncCalendarToPeriodContext() {
        let cal = calendarForAnalysisGrid
        let anchorMonth = startOfMonth(for: periodContext.targetDate, calendar: cal)
        applyCalendarDisplayMonth(anchorMonth, calendar: cal)
    }

    private func handleAnalysisPaywallDismiss() {
        guard !subscriptionManager.isPro else { return }
        pendingEmotionTrend60Selection = false
        periodContext.rollbackAfterFreePaywallDismiss()
        showCustomPicker = false
        syncCalendarToPeriodContext()
    }

    private func selectEmotionTrendWindow(_ window: EmotionTrendWindow) {
        if window == .last60, !subscriptionManager.isPro {
            pendingEmotionTrend60Selection = true
            paywallSource = .emotionTrend60Day
            showPaywall = true
            return
        }
        pendingEmotionTrend60Selection = false
        emotionTrendWindow = window
    }

    private func clampEmotionTrendWindowForFreeTierIfNeeded() {
        guard !subscriptionManager.isPro, emotionTrendWindow == .last60 else { return }
        emotionTrendWindow = .last30
        scheduleChartMetricsRefresh(debounceMilliseconds: 0)
    }

    private func isEmotionTrendWindowProLocked(_ window: EmotionTrendWindow) -> Bool {
        window == .last60 && !subscriptionManager.isPro
    }

    private func emotionTrendWindowTitleKey(_ window: EmotionTrendWindow) -> LKey {
        switch window {
        case .today: return .analysisEmotionTrendWindowToday
        case .last7: return .analysisEmotionTrendWindow7
        case .last14: return .analysisEmotionTrendWindow14
        case .last30: return .analysisEmotionTrendWindow30
        case .last60: return .analysisEmotionTrendWindow60
        }
    }

    private func emotionTrendRollingDayCount(for window: EmotionTrendWindow) -> Int {
        switch window {
        case .today: return 1
        case .last7: return 7
        case .last14: return 14
        case .last30: return 30
        case .last60: return 60
        }
    }

    private var emotionTrendWindowExpenses: [TransactionRecord] {
        cachedEmotionTrendWindowExpenses
    }

    private var emotionTrendChartBuckets: [EmotionTrendChartBucket] {
        cachedTrendChartBuckets
    }

    private var emotionTrendChartDataSignature: String {
        emotionTrendChartBuckets.map { bucket in
            bucket.segments.map { "\($0.id):\($0.yEnd)" }.joined(separator: ",")
        }.joined(separator: "|")
    }

    private var emotionTrendChartHasData: Bool {
        emotionTrendChartBuckets.contains(where: \.hasData)
    }

    private var emotionTrendGranularityHintKey: LKey {
        switch emotionTrendWindow {
        case .today: return .analysisEmotionTrendHintTodaySegment
        case .last7: return .analysisEmotionTrendHintLast7
        case .last14: return .analysisEmotionTrendHintLast14
        case .last30: return .analysisEmotionTrendHintLast30
        case .last60: return .analysisEmotionTrendHintLast60
        }
    }

    /// Rebuilds trend chart buckets, axis, legend, and insight from cached window expenses (single pass).
    @MainActor
    private func rebuildEmotionTrendPresentationCaches(now: Date = Date()) {
        let expenses = cachedEmotionTrendWindowExpenses
        let calendar = Calendar.current
        let buckets = buildEmotionTrendAxisBuckets(now: now, calendar: calendar)
        let bucketDates = Set(buckets.map(\.0))

        let rawTotals = Dictionary(grouping: expenses, by: \.emotionRaw)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        let topFiveRaw = Set(rawTotals.sorted { $0.value > $1.value }.prefix(5).map(\.0))

        func collapseKey(for raw: String) -> String {
            topFiveRaw.contains(raw) ? raw : Self.emotionTrendOtherKey
        }

        var collapsedTotals: [String: Double] = [:]
        var sums: [Date: [String: Double]] = [:]
        for start in bucketDates { sums[start] = [:] }

        for record in expenses {
            collapsedTotals[collapseKey(for: record.emotionRaw), default: 0] += record.amount
            guard let bucketStart = emotionTrendBucketStart(for: record, calendar: calendar, now: now),
                  bucketDates.contains(bucketStart)
            else { continue }
            let key = collapseKey(for: record.emotionRaw)
            sums[bucketStart, default: [:]][key, default: 0] += record.amount
        }

        let orderedTop = topFiveRaw
            .sorted { (collapsedTotals[$0] ?? 0) > (collapsedTotals[$1] ?? 0) }
            .filter { (collapsedTotals[$0] ?? 0) > 0 }
        var seriesKeys = orderedTop
        if collapsedTotals[Self.emotionTrendOtherKey, default: 0] > 0,
           !seriesKeys.contains(Self.emotionTrendOtherKey) {
            seriesKeys.append(Self.emotionTrendOtherKey)
        }

        func seriesColor(for key: String) -> Color {
            if key == Self.emotionTrendOtherKey { return Color(hex: "8A96A0") }
            return expenses.first(where: { $0.emotionRaw == key })?.emotionColor ?? AppTheme.textSecondary
        }

        func seriesLabel(for key: String) -> String {
            if key == Self.emotionTrendOtherKey { return localization.text(.analysisEmotionTrendLegendOther) }
            if let record = expenses.first(where: { $0.emotionRaw == key }) {
                return displayEmotionName(raw: key, fallback: record.safeEmotionName)
            }
            return key
        }

        let maxBucketTotal = buckets.map { start, _ in
            seriesKeys.reduce(0) { $0 + (sums[start]?[$1] ?? 0) }
        }.max() ?? 0

        let yTop: Double
        if maxBucketTotal <= 0 {
            yTop = 1
        } else if maxBucketTotal <= 400 {
            yTop = 400
        } else if maxBucketTotal <= 800 {
            yTop = 800
        } else {
            yTop = ceil(maxBucketTotal / 400) * 400
        }
        let stackGap = yTop > 0 ? yTop * (1.5 / 220) : 0

        cachedTrendChartBuckets = buckets.map { start, label in
            var cursor = 0.0
            var placed = 0
            var segments: [EmotionTrendChartSegment] = []
            for seriesKey in seriesKeys {
                let amount = sums[start]?[seriesKey] ?? 0
                guard amount > 0 else { continue }
                if placed > 0 { cursor += stackGap }
                let yStart = cursor
                cursor += amount
                segments.append(
                    EmotionTrendChartSegment(
                        id: "\(start.timeIntervalSince1970)-\(seriesKey)",
                        color: seriesColor(for: seriesKey),
                        yStart: yStart,
                        yEnd: cursor
                    )
                )
                placed += 1
            }
            return EmotionTrendChartBucket(
                id: "\(start.timeIntervalSince1970)",
                label: label,
                segments: segments
            )
        }

        cachedEmotionTrendLegend = seriesKeys.map { key in
            (key: key, label: seriesLabel(for: key), color: seriesColor(for: key))
        }
        cachedEmotionTrendYAxisTicks = [0, yTop / 2, yTop]
        cachedEmotionTrendYAxisTop = yTop
        cachedEmotionTrendStackGap = stackGap

        switch emotionTrendWindow {
        case .last30:
            var indices: [Int] = []
            var index = 0
            while index < buckets.count {
                indices.append(index)
                index += 5
            }
            if indices.last != buckets.count - 1 {
                indices.append(buckets.count - 1)
            }
            cachedEmotionTrendXAxisTickLabels = indices.map { buckets[$0].1 }
        case .last60:
            var indices: [Int] = []
            var index = 0
            while index < buckets.count {
                indices.append(index)
                index += 7
            }
            if indices.last != buckets.count - 1 {
                indices.append(buckets.count - 1)
            }
            cachedEmotionTrendXAxisTickLabels = indices.map { buckets[$0].1 }
        default:
            cachedEmotionTrendXAxisTickLabels = buckets.map(\.1)
        }

        let windowTotal = expenses.reduce(0) { $0 + $1.amount }
        if expenses.isEmpty || windowTotal <= 0 {
            cachedEmotionTrendInsightCaption = localization.text(.analysisEmotionTrendInsightEven)
            cachedEmotionTrendInsightAccent = AppTheme.accentInsight
            return
        }

        guard let dominant = collapsedTotals.max(by: { $0.value < $1.value }) else {
            cachedEmotionTrendInsightCaption = localization.text(.analysisEmotionTrendInsightEven)
            cachedEmotionTrendInsightAccent = AppTheme.accentSecondary
            return
        }

        let dominantShare = dominant.value / windowTotal
        if dominantShare >= 0.38 {
            let pctText = "\(Int((dominantShare * 100).rounded()))%"
            cachedEmotionTrendInsightCaption = localizedTemplate(
                .analysisEmotionTrendInsightDominant,
                seriesLabel(for: dominant.key),
                pctText
            )
            cachedEmotionTrendInsightAccent = seriesColor(for: dominant.key)
            return
        }

        let bucketTotals = buckets.map { start, _ in
            (start, seriesKeys.reduce(0) { $0 + (sums[start]?[$1] ?? 0) })
        }
        guard let peak = bucketTotals.max(by: { $0.1 < $1.1 }), peak.1 > 0 else {
            cachedEmotionTrendInsightCaption = localization.text(.analysisEmotionTrendInsightEven)
            cachedEmotionTrendInsightAccent = AppTheme.accentSecondary
            return
        }
        let peakValues = bucketTotals.map(\.1).sorted(by: >)
        if peakValues.count >= 2,
           let first = peakValues.first,
           let second = peakValues.dropFirst().first,
           second > 0,
           first / second < 1.35 {
            cachedEmotionTrendInsightCaption = localization.text(.analysisEmotionTrendInsightEven)
            cachedEmotionTrendInsightAccent = AppTheme.accentSecondary
            return
        }
        let peakLabel = buckets.first(where: { $0.0 == peak.0 })?.1
            ?? AppFormatter.dayString(from: peak.0, locale: localization.locale)
        let money = AppFormatter.moneyString(from: peak.1, locale: localization.locale)
        cachedEmotionTrendInsightCaption = localizedTemplate(.analysisEmotionTrendInsightPeak, peakLabel, money)
        cachedEmotionTrendInsightAccent = AppTheme.accentSecondary
    }

    private func buildEmotionTrendAxisBuckets(now: Date, calendar: Calendar) -> [(Date, String)] {
        switch emotionTrendWindow {
        case .today:
            let sod = calendar.startOfDay(for: now)
            return (0..<6).compactMap { bin -> (Date, String)? in
                guard let start = calendar.date(byAdding: .hour, value: bin * 4, to: sod) else { return nil }
                let hs = bin * 4
                let he = min(hs + 3, 23)
                let label = localizedTemplate(.analysisEmotionTrendBinHours, "\(hs)", "\(he)")
                return (start, label)
            }
        case .last7, .last14, .last30, .last60:
            let n = emotionTrendRollingDayCount(for: emotionTrendWindow)
            let endDay = calendar.startOfDay(for: now)
            guard let startDay = calendar.date(byAdding: .day, value: -(n - 1), to: endDay) else { return [] }
            let dfWeekday = DateFormatter()
            dfWeekday.locale = localization.locale
            dfWeekday.setLocalizedDateFormatFromTemplate("EEE")
            let dfDayMd = DateFormatter()
            dfDayMd.locale = localization.locale
            dfDayMd.setLocalizedDateFormatFromTemplate("Md")
            var out: [(Date, String)] = []
            for i in 0..<n {
                guard let day = calendar.date(byAdding: .day, value: i, to: startDay) else { continue }
                let sod = calendar.startOfDay(for: day)
                let label = n == 7 ? dfWeekday.string(from: day) : dfDayMd.string(from: day)
                out.append((sod, label))
            }
            return out
        }
    }

    private func emotionTrendBucketStart(
        for record: TransactionRecord,
        calendar: Calendar,
        now: Date
    ) -> Date? {
        switch emotionTrendWindow {
        case .today:
            let sod = calendar.startOfDay(for: now)
            guard calendar.isDate(record.createdAt, inSameDayAs: now) else { return nil }
            let hour = calendar.component(.hour, from: record.createdAt)
            let bin = hour / 4
            return calendar.date(byAdding: .hour, value: bin * 4, to: sod)
        case .last7, .last14, .last30, .last60:
            return calendar.startOfDay(for: record.createdAt)
        }
    }

    private var heatmapTimeBucketsOrdered: [TimeBucket] {
        [.morning, .afternoon, .evening, .night]
    }

    private func heatmapWeekdayAxis(calendar: Calendar) -> [(weekday: Int, label: String)] {
        let labels = localizedWeekSymbols(calendar: calendar)
        return (0..<7).map { i in
            let weekday = (calendar.firstWeekday - 1 + i) % 7 + 1
            return (weekday, labels[i])
        }
    }

    private var emotionHeatmapTimeCategories: [String] {
        heatmapTimeBucketsOrdered.map { localizedTimeBucketName($0) }
    }

    private var emotionHeatmapWeekCategories: [String] {
        heatmapWeekdayAxis(calendar: calendarForAnalysisGrid).map(\.label)
    }

    private var emotionHeatmapCells: [EmotionHeatmapCell] {
        cachedHeatmapCells
    }

    private func computeHeatmapCells() -> [EmotionHeatmapCell] {
        let cal = calendarForAnalysisGrid
        let weekAxis = heatmapWeekdayAxis(calendar: cal)
        let times = heatmapTimeBucketsOrdered
        let timeLabels = times.map { localizedTimeBucketName($0) }
        var matrix: [[Double]] = Array(repeating: Array(repeating: 0, count: times.count), count: weekAxis.count)
        var emotionAmounts: [[ [String: Double] ]] = Array(
            repeating: Array(repeating: [:], count: times.count),
            count: weekAxis.count
        )
        for r in filteredExpenses {
            let wd = cal.component(.weekday, from: r.createdAt)
            guard let ri = weekAxis.firstIndex(where: { $0.weekday == wd }) else { continue }
            let tb = timeBucket(for: r.createdAt, calendar: cal)
            guard let ci = times.firstIndex(of: tb) else { continue }
            switch emotionHeatmapMeasure {
            case .amount:
                matrix[ri][ci] += r.amount
            case .count:
                matrix[ri][ci] += 1
            }
            emotionAmounts[ri][ci][r.emotionRaw, default: 0] += r.amount
        }
        var maxV: Double = 0
        for row in matrix {
            for v in row { maxV = max(maxV, v) }
        }
        var cells: [EmotionHeatmapCell] = []
        for (ri, w) in weekAxis.enumerated() {
            for (ci, tl) in timeLabels.enumerated() {
                let v = matrix[ri][ci]
                let norm = maxV > 0 ? v / maxV : 0
                let dominantColor = dominantEmotionColor(in: emotionAmounts[ri][ci])
                cells.append(
                    EmotionHeatmapCell(
                        id: "\(w.weekday)-\(ci)",
                        weekdayLabel: w.label,
                        timeLabel: tl,
                        value: v,
                        normalized: norm,
                        dominantEmotionColor: dominantColor,
                        hasConsumption: v > 0,
                        phaseOffset: Double(ri) * 0.65 + Double(ci) * 0.42
                    )
                )
            }
        }
        return cells
    }

    private var emotionHeatmapDataSignature: String {
        emotionHeatmapCells
            .filter(\.hasConsumption)
            .map { "\($0.id):\($0.value)" }
            .joined(separator: "|")
    }

    private func dominantEmotionColor(in totals: [String: Double]) -> Color {
        guard let dominant = totals.max(by: { $0.value < $1.value }) else {
            return AppTheme.textSecondary
        }
        return filteredExpenses
            .first(where: { $0.emotionRaw == dominant.key })?
            .emotionColor ?? AppTheme.textSecondary
    }

    private var emotionHeatmapSubtitleKey: LKey {
        switch periodContext.selectedPeriod {
        case .day: return .analysisHeatmapSubtitleDay
        case .week: return .analysisHeatmapSubtitleWeek
        case .month: return .analysisHeatmapSubtitleMonth
        case .year: return .analysisHeatmapSubtitleYear
        case .custom: return .analysisHeatmapSubtitleCustom
        }
    }

    private func emotionHeatmapMeasureTitle(_ measure: EmotionHeatmapMeasure) -> String {
        switch measure {
        case .amount: localization.text(.analysisHeatmapMeasureAmount)
        case .count: localization.text(.analysisHeatmapMeasureCount)
        }
    }

    private func emotionTrendChartBlock() -> some View {
        Group {
            if !emotionTrendChartHasData {
                EmotionTrendInsightPanel(
                    text: localization.text(.analysisEmotionTrendInsightEven),
                    accent: AppTheme.accentSecondary
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    EmotionTrendAnimatedChart(
                        buckets: emotionTrendChartBuckets,
                        yAxisTicks: cachedEmotionTrendYAxisTicks,
                        yAxisTop: cachedEmotionTrendYAxisTop,
                        stackGap: cachedEmotionTrendStackGap,
                        xAxisTickLabels: Set(cachedEmotionTrendXAxisTickLabels),
                        chartScopeID: emotionTrendWindow.rawValue,
                        dataSignature: emotionTrendChartDataSignature,
                        animationEpoch: spectrumAnimationEpoch
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(cachedEmotionTrendLegend.indices, id: \.self) { i in
                                    HStack(spacing: 5) {
                                        EmotionTrendLegendDot(color: cachedEmotionTrendLegend[i].color)
                                        Text(cachedEmotionTrendLegend[i].label)
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.textSecondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .frame(height: 22)

                        EmotionTrendInsightPanel(
                            text: cachedEmotionTrendInsightCaption,
                            accent: cachedEmotionTrendInsightAccent
                        )
                    }
                }
            }
        }
    }

    private var emotionTrendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localization.text(.analysisEmotionTrendTitle))
                        .font(.headline)
                    Text(localization.text(emotionTrendGranularityHintKey))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(EmotionTrendWindow.allCases) { window in
                            Button {
                                selectEmotionTrendWindow(window)
                            } label: {
                                HStack(spacing: 4) {
                                    Text(localization.text(emotionTrendWindowTitleKey(window)))
                                    if isEmotionTrendWindowProLocked(window) {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundStyle(AppTheme.textSecondary.opacity(0.75))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .softPeriodFilterCapsuleStyle(selected: emotionTrendWindow == window)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        }
                    }
                }
            }

            if showsChartsLoading {
                AnalysisChartLoadingPlaceholder()
            } else if emotionTrendWindowExpenses.isEmpty {
                EmptyStateBlock(
                    title: localization.text(.commonNoData),
                    hint: localization.text(.analysisEmotionTrendEmptyHint),
                    systemImage: "chart.bar.xaxis"
                )
            } else {
                emotionTrendChartBlock()
            }
        }
        .appCardStyle()
    }

    private var emotionHeatmapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localization.text(.analysisHeatmapTitle))
                        .font(.headline)
                    Text(localization.text(emotionHeatmapSubtitleKey))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    showHeatmapGuide = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.72))
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(localization.text(.analysisHeatmapGuideOpenA11yLabel)))
                .accessibilityHint(Text(localization.text(.analysisHeatmapGuideOpenA11yHint)))

                heatmapMeasureToggle
            }

            if showsChartsLoading {
                AnalysisChartLoadingPlaceholder()
            } else if filteredExpenses.isEmpty {
                EmptyStateBlock(
                    title: localization.text(.commonNoData),
                    hint: localization.text(.analysisDistributionEmptyHint),
                    systemImage: "square.grid.3x3.fill.square"
                )
            } else {
                EmotionTimeHeatmapView(
                    weekLabels: emotionHeatmapWeekCategories,
                    timeLabels: emotionHeatmapTimeCategories,
                    cells: emotionHeatmapCells,
                    periodMode: periodContext.selectedPeriod,
                    dataSignature: emotionHeatmapDataSignature,
                    animationEpoch: spectrumAnimationEpoch
                )
            }
        }
        .appCardStyle()
        .sheet(isPresented: $showHeatmapGuide) {
            EmotionHeatmapGuideSheet(periodExpenses: filteredExpenses)
                .environmentObject(localization)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var heatmapMeasureToggle: some View {
        HStack(spacing: 8) {
            ForEach(EmotionHeatmapMeasure.allCases) { measure in
                Button(emotionHeatmapMeasureTitle(measure)) {
                    emotionHeatmapMeasure = measure
                }
                .buttonStyle(.plain)
                .softPeriodFilterCapsuleStyle(selected: emotionHeatmapMeasure == measure)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }
        }
    }

    /// Title, period chips, and emotion dashboard stay pinned; charts scroll underneath.
    private var analysisPinnedHeader: some View {
        VStack(spacing: 0) {
            analysisTitleRow

            AppPeriodHeader(
                period: periodContext,
                subscriptionManager: subscriptionManager,
                showPaywall: $showPaywall,
                paywallSource: $paywallSource,
                showCustomPicker: $showCustomPicker,
                onPeriodChangeNeedsRollback: {
                    periodContext.resetToCurrentMonth()
                    syncCalendarToPeriodContext()
                }
            )

            AnalysisEmotionDashboard(
                model: emotionDashboardModel,
                openDetailAccessibilityHint: localization.text(.analysisDashboardDetailOpenA11yHint),
                onDistressTap: openDashboardDistressDetail,
                onFulfillmentTap: openDashboardFulfillmentDetail
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            AppTheme.pageBackground
                .ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.divider)
                .frame(height: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 6, y: 3)
        .zIndex(1)
    }

    private var analysisTitleRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(localization.text(.analysisTitle))
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            reportGenerateButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var activeAnalysisScrollContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                MoodHeatRingCard(
                    periodExpenses: filteredExpenses,
                    slices: analysisHeatRingSlices,
                    totalAmount: totalExpense,
                    totalCount: recordCount,
                    showsLoading: showsChartsLoading
                )
                .environmentObject(localization)
                MoodCorrelationCard(
                    points: correlationPoints,
                    warmTip: correlationWarmTip,
                    periodMode: periodContext.selectedPeriod,
                    showsLoading: showsChartsLoading,
                    chartContentOpacity: correlationChartContentOpacity,
                    onOpenBucket: { openCorrelationBucket($0) }
                )
                .environmentObject(localization)
                EmotionSpectrumCard(
                    periodMode: periodContext.selectedPeriod,
                    periodExpenses: filteredExpenses,
                    columns: emotionSpectrumColumns,
                    insight: spectrumInsight,
                    showsLoading: showsChartsLoading,
                    animationEpoch: spectrumAnimationEpoch
                )
                .environmentObject(localization)
                emotionTrendCard
                emotionHeatmapCard
                calendarCard
                RegretQuadrantCard(
                    periodExpenses: filteredExpenses,
                    points: regretQuadrantPoints
                ) { publicId in
                    if let record = records.first(where: { $0.publicId == publicId }) {
                        regretTappedRecord = record
                    }
                }
                .environmentObject(localization)
                compareCard
                patternCard
            }
            .padding(16)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: AnalysisScrollOffsetPreferenceKey.self,
                        value: proxy.frame(in: .named("analysisScroll")).minY
                    )
                }
            }
        }
        .coordinateSpace(name: "analysisScroll")
        .onPreferenceChange(AnalysisScrollOffsetPreferenceKey.self) { _ in
            analysisScrollActivity.noteScrollActivity()
        }
        .environment(\.analysisChartMotionMode, chartMotionMode)
        .analysisChartMotionLifecycle(motionMode: $chartMotionMode)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isTabActive {
                    activeAnalysisScrollContent
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if isTabActive {
                    analysisPinnedHeader
                }
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showCalendarMonthPickerSheet, onDismiss: handleCalendarMonthPickerSheetDismiss) {
            calendarMonthPickerSheet
        }
        .sheet(isPresented: $showDayRecords) {
            dayRecordSheet
        }
        .sheet(item: $emotionReportScope) { scope in
            MonthlyReportView(
                records: reportScopedExpenses(for: scope),
                scope: scope
            )
            .environmentObject(localization)
            .environmentObject(appSettings)
        }
        .alert(
            localization.text(.analysisReportCustomRangeRequired),
            isPresented: $showReportScopeUnavailableAlert
        ) {
            Button(localization.text(.commonOk), role: .cancel) {}
        }
        .sheet(item: $retrospectiveSheetRecord) { record in
            RecordRetrospectiveSheet(record: record)
                .environmentObject(localization)
                .environmentObject(notificationStore)
        }
        .sheet(item: $regretTappedRecord) { record in
            RecordDetailView(record: record)
                .environmentObject(localization)
                .environmentObject(appSettings)
                .environmentObject(notificationStore)
        }
        .sheet(item: $correlationInspect) { session in
            DayBillsSheetView(
                selectedDate: session.bucketStart,
                records: session.records,
                headerMode: periodContext.selectedPeriod == .year ? .month : .day
            )
            .environmentObject(localization)
            .environmentObject(appSettings)
            .environmentObject(notificationStore)
        }
        .sheet(item: $dashboardDetailSession) { session in
            AnalysisDashboardDetailSheet(
                kind: session.kind,
                periodExpenses: filteredExpenses,
                periodTotalExpense: totalExpense,
                customEmotions: customEmotionOptions,
                periodMode: periodContext.selectedPeriod,
                fulfillmentFooterNote: session.kind == .fulfillment ? positiveRateDeltaDisplayText : nil
            )
            .environmentObject(localization)
            .environmentObject(appSettings)
            .environmentObject(notificationStore)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCustomPicker, onDismiss: {
            if periodContext.selectedPeriod == .custom, periodContext.customRange == nil {
                periodContext.resetToCurrentMonth()
                syncCalendarToPeriodContext()
            }
        }) {
            CustomRangePickerSheet(
                availableYears: AppPeriodContext.availableYears(
                    from: records,
                    calendar: periodContext.calendar
                ),
                initialRange: periodContext.customRange,
                copy: .analysis,
                onApply: { range in
                    periodContext.applyCustomRange(range)
                    syncCalendarToPeriodContext()
                    showCustomPicker = false
                    if subscriptionManager.isPro {
                        pendingReviewAfterCustomRangeApply = true
                        consumePendingCustomRangeReviewIfNeeded(customRange: range)
                    }
                }
            )
            .environmentObject(localization)
        }
        .fullScreenCover(isPresented: $showPaywall, onDismiss: handleAnalysisPaywallDismiss) {
            PaywallView(source: paywallSource)
                .environmentObject(localization)
        }
        .onChange(of: subscriptionManager.isPro) { _, isPro in
            if isPro {
                showPaywall = false
                if pendingEmotionTrend60Selection {
                    pendingEmotionTrend60Selection = false
                    emotionTrendWindow = .last60
                }
            } else {
                periodContext.clampToFreeRetentionWindowIfNeeded(isPro: false)
                clampEmotionTrendWindowForFreeTierIfNeeded()
            }
        }
        .onAppear {
            periodContext.refreshNow()
            syncCalendarDisplayMonthToMonthStart()
            syncCalendarToPeriodContext()
            presentRetrospectiveFromPending()
            playSpectrumEntranceIfNeeded()
            scheduleRetrospectiveEnqueue()
            scheduleChartMetricsRefresh(debounceMilliseconds: 0)
        }
        .onChange(of: metricsRecomputeToken) { _, _ in
            scheduleChartMetricsRefresh()
        }
        .onChange(of: periodContext.selectedPeriod) { _, _ in
            syncCalendarToPeriodContext()
        }
        .onChange(of: periodContext.targetDate) { _, _ in
            syncCalendarToPeriodContext()
        }
        .onChange(of: periodContext.customRange) { _, newRange in
            syncCalendarToPeriodContext()
            consumePendingCustomRangeReviewIfNeeded(customRange: newRange)
        }
        .onChange(of: emotionTrendWindow) { _, _ in
            scheduleChartMetricsRefresh(debounceMilliseconds: 0)
        }
        .onChange(of: emotionHeatmapMeasure) { _, _ in
            scheduleHeatmapCellsRefresh()
        }
        .onChange(of: appSettings.firstDayOfWeek) { _, _ in
            syncCalendarToPeriodContext()
        }
        .onChange(of: isTabActive) { _, active in
            guard active else { return }
            scheduleChartMetricsRefresh(debounceMilliseconds: 0)
        }
        .onChange(of: notificationStore.pendingRetrospectivePublicId) { _, _ in
            presentRetrospectiveFromPending()
        }
        .onChange(of: notificationStore.pendingRetrospectivePersistentToken) { _, _ in
            presentRetrospectiveFromPending()
        }
        .onChange(of: rootTab.selected) { _, tab in
            guard tab == .analysis else { return }
            presentRetrospectiveFromPending()
            scheduleRetrospectiveEnqueue()
        }
        .onDisappear {
            retrospectiveEnqueueTask?.cancel()
            chartMetricsRefreshTask?.cancel()
            heatmapCellsRefreshTask?.cancel()
        }
    }

    /// Keeps bubble sizes/values in sync when toggling amount vs. count (yielded main-actor refresh).
    private func scheduleHeatmapCellsRefresh() {
        heatmapCellsRefreshTask?.cancel()
        let refreshToken = metricsRecomputeToken
        heatmapCellsRefreshTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled, metricsRecomputeToken == refreshToken else { return }
            cachedHeatmapCells = computeHeatmapCells()
            publishMetricsSnapshot()
        }
    }

    @MainActor
    private func makeExpenseFilterBuildInput(now: Date = Date()) -> AnalysisExpenseFilterBuildInput {
        let periodInterval = periodContext.dateInterval
        let previousInterval = periodContext.previousComparisonInterval
        return AnalysisExpenseFilterBuildInput(
            stubs: records.map {
                AnalysisRecordFilterStub(
                    publicId: $0.publicId,
                    createdAt: $0.createdAt,
                    typeRaw: $0.typeRaw
                )
            },
            periodIntervalStart: periodInterval?.start,
            periodIntervalEnd: periodInterval?.end,
            previousIntervalStart: previousInterval?.start,
            previousIntervalEnd: previousInterval?.end,
            emotionTrendWindowRaw: emotionTrendWindow.rawValue,
            calendarFirstWeekday: periodContext.calendar.firstWeekday,
            now: now
        )
    }

    @MainActor
    private func applyExpenseFilterResult(_ result: AnalysisExpenseFilterBuildResult) {
        let byPublicId = Dictionary(uniqueKeysWithValues: records.map { ($0.publicId, $0) })
        cachedFilteredExpenses = resolveRecords(publicIds: result.filteredPublicIds, from: byPublicId)
        cachedPreviousPeriodFilteredExpenses = resolveRecords(
            publicIds: result.previousPeriodPublicIds,
            from: byPublicId
        )
        cachedEmotionTrendWindowExpenses = resolveRecords(
            publicIds: result.emotionTrendWindowPublicIds,
            from: byPublicId
        )
        rebuildEmotionTrendPresentationCaches()
        cachedHeatmapCells = computeHeatmapCells()
    }

    private func resolveRecords(
        publicIds: [UUID],
        from byPublicId: [UUID: TransactionRecord]
    ) -> [TransactionRecord] {
        publicIds.compactMap { byPublicId[$0] }
    }

    /// Rebuilds period-scoped chart metrics off the main thread, then applies derived caches on `@MainActor`.
    private func scheduleChartMetricsRefresh(debounceMilliseconds: UInt64 = 200) {
        guard isTabActive else { return }
        chartMetricsRefreshTask?.cancel()

        let refreshToken = metricsRecomputeToken
        let periodChanged = lastAppliedPeriodMetricsToken.map { $0 != periodMetricsToken } ?? false
        let hadChartPayload = !metricsCache.heatRingSlices.isEmpty
            || !cachedTrendChartBuckets.isEmpty
            || !cachedHeatmapCells.isEmpty
        if !hadChartPayload, !records.isEmpty {
            isRecomputingCharts = true
        }

        if periodChanged {
            withAnimation(.easeOut(duration: 0.14)) {
                correlationChartContentOpacity = 0.42
            }
        }

        let debounce = periodChanged ? 0 : debounceMilliseconds

        chartMetricsRefreshTask = Task(priority: .userInitiated) {
            if debounce > 0 {
                try? await Task.sleep(for: .milliseconds(debounce))
            }
            guard !Task.isCancelled else { return }

            let filterInput = await MainActor.run { makeExpenseFilterBuildInput() }
            guard !Task.isCancelled else { return }
            let filterResult = AnalysisExpenseFilterCache.build(input: filterInput)

            let buildInput = await MainActor.run {
                PeriodScopedMetricsBuildInput.make(
                    records: records,
                    customEmotionOptions: customEmotionOptions,
                    period: periodContext.selectedPeriod,
                    periodInterval: periodContext.dateInterval,
                    calendar: periodContext.calendar,
                    localization: localization
                )
            }
            guard !Task.isCancelled else { return }

            guard let buildInput else {
                await MainActor.run {
                    guard !Task.isCancelled, metricsRecomputeToken == refreshToken else { return }
                    applyExpenseFilterResult(filterResult)
                    applyChartMetricsBuildResult(
                        .empty,
                        refreshToken: refreshToken,
                        periodChanged: periodChanged
                    )
                }
                return
            }

            let built = AnalysisViewMetricsCache.buildPeriodScoped(input: buildInput)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard !Task.isCancelled, metricsRecomputeToken == refreshToken else { return }
                applyExpenseFilterResult(filterResult)
                applyChartMetricsBuildResult(
                    built,
                    refreshToken: refreshToken,
                    periodChanged: periodChanged
                )
            }
        }
    }

    @MainActor
    private func applyChartMetricsBuildResult(
        _ built: AnalysisViewMetricsCache,
        refreshToken: String,
        periodChanged: Bool
    ) {
        metricsCache = built
        cachedGeneratedInsight = computeGeneratedInsight()
        isRecomputingCharts = false
        lastAppliedPeriodMetricsToken = periodMetricsToken
        publishMetricsSnapshot()

        if periodChanged {
            withAnimation(.easeOut(duration: 0.22)) {
                correlationChartContentOpacity = 1
            }
        } else if correlationChartContentOpacity < 1 {
            correlationChartContentOpacity = 1
        }
    }

    @MainActor
    private func publishMetricsSnapshot() {
        analysisMetricsStore.update(
            AnalysisTabMetricsSnapshot(
                token: metricsRecomputeToken,
                metricsCache: metricsCache,
                trendBuckets: cachedTrendChartBuckets,
                heatmapCells: cachedHeatmapCells,
                generatedInsight: cachedGeneratedInsight
            )
        )
    }

    private func playSpectrumEntranceIfNeeded() {
        guard !didPlaySpectrumEntrance else { return }
        didPlaySpectrumEntrance = true
        spectrumAnimationEpoch = 1
    }

    private func scheduleRetrospectiveEnqueue() {
        let now = Date()
        if let last = Self.lastRetrospectiveEnqueueAt,
           now.timeIntervalSince(last) < Self.retrospectiveEnqueueMinInterval {
            return
        }
        Self.lastRetrospectiveEnqueueAt = now

        retrospectiveEnqueueTask?.cancel()
        retrospectiveEnqueueTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            enqueueRetrospectiveReviewTasks()
        }
    }

    private static var lastRetrospectiveEnqueueAt: Date?
    private static let retrospectiveEnqueueMinInterval: TimeInterval = 120

    private func reportScopedExpenses(for scope: EmotionReportScope) -> [TransactionRecord] {
        records.filter {
            $0.type == .expense
                && $0.createdAt >= scope.interval.start
                && $0.createdAt < scope.interval.end
        }
    }

    private var canGenerateEmotionReport: Bool {
        periodContext.makeEmotionReportScope(
            localize: { localization.text($0) },
            locale: localization.locale
        ) != nil
    }

    private var reportGenerateButton: some View {
        Button {
            openEmotionReport()
        } label: {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.actionBlue)
                .periodFilterCircleIconStyle()
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .accessibilityLabel(localization.text(.analysisReportGenerate))
        .accessibilityHint(
            canGenerateEmotionReport
                ? periodContext.navigationTitle(
                    localize: { localization.text($0) },
                    locale: localization.locale
                )
                : localization.text(.analysisReportCustomRangeRequired)
        )
    }

    private func openEmotionReport() {
        guard let scope = periodContext.makeEmotionReportScope(
            localize: { localization.text($0) },
            locale: localization.locale
        ) else {
            showReportScopeUnavailableAlert = true
            return
        }
        emotionReportScope = scope
    }

    private var patternCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localization.text(.analysisPatternTitle))
                .font(.headline)
            EmotionInsightCard(
                insight: generatedInsight,
                ineffectiveShareLabel: localization.text(.analysisPatternIneffectiveShareLabel),
                motto: localization.text(.analysisWarmLine),
                countSuffix: { count in
                    localizedTemplate(.analysisPatternBadgeCount, "\(count)")
                }
            )
        }
        .appCardStyle()
    }

    private var compareCard: some View {
        let hasExpenses = !filteredExpenses.isEmpty
        let effectiveTotal = filteredExpenses
            .filter { EmotionGrouping.isEffective($0, customEmotions: customEmotionOptions) }
            .reduce(0) { $0 + $1.amount }
        let ineffectiveTotal = filteredExpenses
            .filter { EmotionGrouping.isEmotional($0, customEmotions: customEmotionOptions) }
            .reduce(0) { $0 + $1.amount }
        let denominator = effectiveTotal + ineffectiveTotal
        let effectiveRatio = denominator > 0 ? effectiveTotal / denominator : 0
        let ineffectiveRatio = denominator > 0 ? ineffectiveTotal / denominator : 0

        let effectiveMoney = AppFormatter.moneyString(from: effectiveTotal, locale: localization.locale)
        let ineffectiveMoney = AppFormatter.moneyString(from: ineffectiveTotal, locale: localization.locale)

        return VStack(alignment: .leading, spacing: 12) {
            Text(localization.text(.analysisCompareTitle))
                .font(.headline)

            MindBalanceView(
                effectiveHeading: localization.text(.analysisCompareEffective),
                ineffectiveHeading: localization.text(.analysisCompareIneffective),
                effectiveAmount: effectiveMoney,
                ineffectiveAmount: ineffectiveMoney,
                effectiveRatioLabel: localizedTemplate(
                    .analysisCompareEffectiveRatio,
                    "\(Int(effectiveRatio * 100))%"
                ),
                ineffectiveRatioLabel: localizedTemplate(
                    .analysisCompareDrainRatio,
                    "\(Int(ineffectiveRatio * 100))%"
                ),
                effectiveRatio: effectiveRatio,
                ineffectiveRatio: ineffectiveRatio,
                insightPrimary: hasExpenses
                    ? "\(localization.text(.analysisCompareInsight)) \(Int(effectiveRatio * 100))%"
                    : "",
                insightSecondary: hasExpenses
                    ? compareInsightMessage(for: effectiveRatio)
                    : localization.text(.analysisCompareEmptyHint)
            )
        }
        .appCardStyle()
    }

    private var calendarCard: some View {
        let calendar = calendarForAnalysisGrid
        let days = monthDays(calendar: calendar, anchorMonth: calendarDisplayMonth)

        return VStack(alignment: .leading, spacing: 8) {
            Text(localization.text(.analysisCalendarTitle))
                .font(.headline)

            calendarMonthHeader(calendar: calendar)

            if days.isEmpty {
                EmptyStateBlock(
                    title: localization.text(.analysisCalendarEmpty),
                    systemImage: "calendar"
                )
            } else {
                let symbols = localizedWeekSymbols(calendar: calendar)
                let dayColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
                VStack(alignment: .leading, spacing: 6) {
                    LazyVGrid(columns: dayColumns, spacing: 6) {
                        ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                            Text(symbol)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    LazyVGrid(columns: dayColumns, spacing: 6) {
                        ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                            if let date {
                                dayCell(date: date, calendar: calendar)
                            } else {
                                Color.clear
                                    .aspectRatio(1, contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.pageBackground)
                )
            }
        }
        .appCardStyle()
    }

    private var calendarForAnalysisGrid: Calendar {
        var cal = periodContext.calendar
        cal.locale = localization.locale
        return cal
    }

    private var analysisCalendarYearList: [Int] {
        let cal = calendarForAnalysisGrid
        let now = Date()
        let yNow = cal.component(.year, from: now)
        let yAnchor = cal.component(.year, from: calendarDisplayMonth)
        let expenseYears = records
            .filter { $0.type == .expense }
            .map { cal.component(.year, from: $0.createdAt) }
        let yMinRecord = expenseYears.min() ?? yNow
        let lower = min(yMinRecord, yAnchor, yNow) - 2
        let upper = yNow
        return Array(max(1990, lower)...max(lower + 1, upper))
    }

    private func analysisCalendarSelectableMonths(for year: Int, calendar: Calendar) -> [Int] {
        guard let maxMonth = AppPeriodContext.maxSelectableMonth(
            in: year,
            calendar: calendar,
            now: Date()
        ) else {
            return []
        }
        return Array(1 ... maxMonth)
    }

    private func clampMonthPickerMonthToSelectable(calendar: Calendar) {
        let months = analysisCalendarSelectableMonths(for: monthPickerYear, calendar: calendar)
        guard let maxMonth = months.last else {
            monthPickerMonth = 1
            return
        }
        if monthPickerMonth > maxMonth {
            monthPickerMonth = maxMonth
        } else if !months.contains(monthPickerMonth) {
            monthPickerMonth = maxMonth
        }
    }

    private func isFutureCalendarDay(_ date: Date, calendar: Calendar, now: Date = Date()) -> Bool {
        calendar.startOfDay(for: date) > calendar.startOfDay(for: now)
    }

    private func currentCalendarMonthStart(calendar: Calendar, now: Date = Date()) -> Date {
        startOfMonth(for: now, calendar: calendar)
    }

    private func clampCalendarDisplayMonthToSelectable(_ date: Date, calendar: Calendar, now: Date = Date()) -> Date {
        let normalized = startOfMonth(for: date, calendar: calendar)
        let currentStart = currentCalendarMonthStart(calendar: calendar, now: now)
        return normalized > currentStart ? currentStart : normalized
    }

    private func canNavigateCalendarForward(calendar: Calendar, now: Date = Date()) -> Bool {
        guard
            let currentStart = calendar.dateInterval(of: .month, for: now)?.start,
            let displayedStart = calendar.dateInterval(of: .month, for: calendarDisplayMonth)?.start
        else {
            return false
        }
        return displayedStart < currentStart
    }

    private func clearFutureSelectedCalendarDate(calendar: Calendar) {
        guard let selected = selectedCalendarDate else { return }
        if isFutureCalendarDay(selected, calendar: calendar) {
            selectedCalendarDate = nil
        }
    }

    private func handleCalendarMonthPickerSheetDismiss() {
        if !monthPickerKeepChangesOnDismiss {
            let cal = calendarForAnalysisGrid
            applyCalendarDisplayMonth(calendarMonthPickerSnapshot, calendar: cal)
            syncMonthPickers(from: calendarMonthPickerSnapshot)
        }
        monthPickerKeepChangesOnDismiss = false
    }

    private var calendarMonthPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Picker("", selection: $monthPickerYear) {
                        ForEach(analysisCalendarYearList, id: \.self) { year in
                            Text(localizedWheelYearLabel(year))
                                .tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Picker("", selection: $monthPickerMonth) {
                        ForEach(
                            analysisCalendarSelectableMonths(for: monthPickerYear, calendar: calendarForAnalysisGrid),
                            id: \.self
                        ) { month in
                            Text(localizedWheelMonthLabel(month))
                                .tag(month)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
                .tint(AppTheme.actionBlue)
                .onChange(of: monthPickerYear) { _, _ in
                    let cal = calendarForAnalysisGrid
                    clampMonthPickerMonthToSelectable(calendar: cal)
                    applyFromMonthPickerWheels()
                }
                .onChange(of: monthPickerMonth) { _, _ in
                    applyFromMonthPickerWheels()
                }
                Spacer(minLength: 0)
            }
            .navigationTitle(localization.text(.analysisCalendarMonthPickerA11yLabel))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.text(.analysisCalendarMonthPickerRestore)) {
                        showCalendarMonthPickerSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.text(.commonDone)) {
                        monthPickerKeepChangesOnDismiss = true
                        showCalendarMonthPickerSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .environment(\.locale, localization.locale)
    }

    private func syncMonthPickers(from anchor: Date) {
        let cal = calendarForAnalysisGrid
        let y = cal.component(.year, from: anchor)
        let m = cal.component(.month, from: anchor)
        let years = analysisCalendarYearList
        if let first = years.first, let last = years.last {
            monthPickerYear = min(max(y, first), last)
        } else {
            monthPickerYear = y
        }
        monthPickerMonth = m
        clampMonthPickerMonthToSelectable(calendar: cal)
    }

    private func applyFromMonthPickerWheels() {
        guard showCalendarMonthPickerSheet else { return }
        let cal = calendarForAnalysisGrid
        clampMonthPickerMonthToSelectable(calendar: cal)
        guard let date = cal.date(from: DateComponents(year: monthPickerYear, month: monthPickerMonth, day: 1)) else {
            return
        }
        applyCalendarDisplayMonth(date, calendar: cal)
    }

    private func localizedWheelMonthLabel(_ month: Int) -> String {
        let cal = calendarForAnalysisGrid
        guard let date = cal.date(from: DateComponents(year: 2000, month: month, day: 1)) else {
            return "\(month)"
        }
        let formatter = DateFormatter()
        formatter.locale = localization.locale
        formatter.calendar = cal
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter.string(from: date)
    }

    private func localizedWheelYearLabel(_ year: Int) -> String {
        let cal = calendarForAnalysisGrid
        guard let date = cal.date(from: DateComponents(year: year, month: 6, day: 1)) else {
            return "\(year)"
        }
        let formatter = DateFormatter()
        formatter.locale = localization.locale
        formatter.calendar = cal
        formatter.setLocalizedDateFormatFromTemplate("y")
        return formatter.string(from: date)
    }

    private func calendarMonthHeader(calendar: Calendar) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Button {
                calendarMonthPickerSnapshot = calendarDisplayMonth
                monthPickerKeepChangesOnDismiss = false
                syncMonthPickers(from: calendarDisplayMonth)
                showCalendarMonthPickerSheet = true
            } label: {
                HStack(spacing: 4) {
                    Text(monthYearTitle(calendar: calendar, date: calendarDisplayMonth))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localization.text(.analysisCalendarMonthPickerA11yLabel))
            .accessibilityHint(localization.text(.analysisCalendarMonthPickerA11yHint))

            Spacer(minLength: 4)
            HStack(spacing: 0) {
                Button {
                    shiftCalendarDisplayMonth(by: -1, calendar: calendar)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button {
                    shiftCalendarDisplayMonth(by: 1, calendar: calendar)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canNavigateCalendarForward(calendar: calendar))
                .opacity(canNavigateCalendarForward(calendar: calendar) ? 1 : 0.35)
                .accessibilityHint(
                    canNavigateCalendarForward(calendar: calendar)
                        ? ""
                        : localization.text(.analysisCalendarMonthForwardDisabledA11yHint)
                )
            }
        }
    }

    private func applyCalendarDisplayMonth(_ date: Date, calendar: Calendar) {
        let clamped = clampCalendarDisplayMonthToSelectable(date, calendar: calendar)
        calendarDisplayMonth = clamped
        syncMonthPickers(from: clamped)
        clearSelectedCalendarDateIfOutsideDisplayedMonth(calendar: calendar)
        clearFutureSelectedCalendarDate(calendar: calendar)
    }

    private func startOfMonth(for date: Date, calendar: Calendar) -> Date {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: parts) ?? date
    }

    private func syncCalendarDisplayMonthToMonthStart() {
        let calendar = calendarForAnalysisGrid
        let normalized = startOfMonth(for: calendarDisplayMonth, calendar: calendar)
        if !calendar.isDate(normalized, inSameDayAs: calendarDisplayMonth) {
            calendarDisplayMonth = normalized
        }
    }

    private func clearSelectedCalendarDateIfOutsideDisplayedMonth(calendar: Calendar) {
        guard let selected = selectedCalendarDate else { return }
        if !calendar.isDate(selected, equalTo: calendarDisplayMonth, toGranularity: .month) {
            selectedCalendarDate = nil
        }
    }

    private func monthYearTitle(calendar: Calendar, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = localization.locale
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: date)
    }

    private func shiftCalendarDisplayMonth(by delta: Int, calendar: Calendar) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: calendarDisplayMonth) else { return }
        applyCalendarDisplayMonth(next, calendar: calendar)
    }

    private func dayCell(date: Date, calendar: Calendar) -> some View {
        let isFuture = isFutureCalendarDay(date, calendar: calendar)
        let isSelected = !isFuture && (selectedCalendarDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false)
        let total = dayTotalExpense(for: date, calendar: calendar)
        let bucket = dominantBucket(for: date, calendar: calendar)
        let fill = dayCellBackgroundFill(total: total, bucket: bucket, isFuture: isFuture)
        let dayNumberColor: Color = isFuture
            ? AppTheme.textSecondary.opacity(0.82)
            : AppTheme.textPrimary
        let amountColor: Color = isFuture ? AppTheme.textSecondary.opacity(0.38) : AppTheme.textPrimary

        let tileRadius: CGFloat = 10
        let tileShape = RoundedRectangle(cornerRadius: tileRadius, style: .continuous)

        return Button {
            guard !isFuture else { return }
            selectedCalendarDate = date
            showDayRecords = true
        } label: {
            Group {
                if total > 0, !isFuture {
                    VStack(spacing: 4) {
                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(dayNumberColor)
                        Text(calendarDayMoneyString(total))
                            .font(.system(size: 10, weight: .regular))
                            .monospacedDigit()
                            .foregroundStyle(amountColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 6)
                    .padding(.horizontal, 3)
                    .padding(.bottom, 4)
                } else {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(dayNumberColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .background(tileShape.fill(fill))
            .clipShape(tileShape)
            .overlay {
                if isFuture {
                    tileShape
                        .strokeBorder(
                            AppTheme.border.opacity(0.58),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                } else if isSelected {
                    tileShape.stroke(Color.orange, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityHint(isFuture ? localization.text(.analysisCalendarFutureDayA11yHint) : "")
    }

    private func dayCellBackgroundFill(total: Double, bucket: EmotionBucket?, isFuture: Bool) -> Color {
        if isFuture {
            return AppTheme.cardBackground
        }
        guard total > 0, let bucket else { return AppTheme.cardBackground }
        return bucketAccentColor(bucket).opacity(0.22).opacity(0.9)
    }

    private func bucketAccentColor(_ bucket: EmotionBucket) -> Color {
        switch bucket {
        case .effective: return AppTheme.accentSecondary
        case .emotional: return AppTheme.accentRisk
        case .necessary: return AppTheme.accentWarning
        }
    }

    private func calendarDayMoneyString(_ amount: Double) -> String {
        let rounded = amount.rounded()
        if abs(amount - rounded) < 0.05 {
            return String(Int(rounded))
        }
        return amount.formatted(
            .number
                .locale(localization.locale)
                .precision(.fractionLength(1))
        )
    }

    /// All expense records on this calendar day (ignores analysis period chips).
    private func calendarDayExpenseRecords(for date: Date, calendar: Calendar) -> [TransactionRecord] {
        records.filter { $0.type == .expense && calendar.isDate($0.createdAt, inSameDayAs: date) }
    }

    private func dayTotalExpense(for date: Date, calendar: Calendar) -> Double {
        calendarDayExpenseRecords(for: date, calendar: calendar)
            .reduce(0) { $0 + $1.amount }
    }

    private func dominantBucket(for date: Date, calendar: Calendar) -> EmotionBucket? {
        let dayRecords = calendarDayExpenseRecords(for: date, calendar: calendar)
        guard !dayRecords.isEmpty else { return nil }
        var sums: [EmotionBucket: Double] = [:]
        for record in dayRecords {
            let bucket = EmotionGrouping.bucket(for: record, customEmotions: customEmotionOptions)
            sums[bucket, default: 0] += record.amount
        }
        var winner: EmotionBucket?
        var best: Double = 0
        for bucket in EmotionBucket.allCases {
            let v = sums[bucket, default: 0]
            if v > best {
                best = v
                winner = bucket
            }
        }
        return winner
    }

    private func monthDays(calendar: Calendar, anchorMonth: Date) -> [Date?] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: anchorMonth),
            let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)
        else {
            return []
        }

        var days: [Date?] = []
        var current = monthFirstWeek.start
        while current < monthInterval.start {
            days.append(nil)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }

        current = monthInterval.start
        while current < monthInterval.end {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }

    private func localizedWeekSymbols(calendar: Calendar) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = localization.locale
        formatter.calendar = calendar
        let symbols = formatter.shortWeekdaySymbols ?? []
        guard symbols.count == 7 else { return symbols }
        return (0..<7).map { i in
            let weekday = (calendar.firstWeekday - 1 + i) % 7 + 1
            return symbols[weekday - 1]
        }
    }

    private func displayEmotionName(raw: String, fallback: String) -> String {
        if let preset = EmotionTag.from(raw: raw) {
            return localization.text(preset.key)
        }
        return fallback
    }

    private var dayRecordSheet: some View {
        DayBillsSheetView(
            selectedDate: selectedCalendarDate,
            records: selectedDayRecords
        )
        .environmentObject(localization)
        .environmentObject(notificationStore)
    }

    private var selectedDayRecords: [TransactionRecord] {
        guard let selectedCalendarDate else { return [] }
        return records.filter { calendarForAnalysisGrid.isDate($0.createdAt, inSameDayAs: selectedCalendarDate) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func compareInsightMessage(for ratio: Double) -> String {
        guard !filteredExpenses.isEmpty else {
            return localization.text(.analysisCompareEmptyHint)
        }
        if ratio >= 0.6 {
            return localization.text(.analysisCompareInsightHigh)
        }
        if ratio >= 0.35 {
            return localization.text(.analysisCompareInsightMid)
        }
        return localization.text(.analysisCompareInsightLow)
    }

    private var generatedInsight: GeneratedInsight {
        cachedGeneratedInsight
    }

    private func computeGeneratedInsight() -> GeneratedInsight {
        let ineffectiveTotal = filteredExpenses
            .filter { EmotionGrouping.isEmotional($0, customEmotions: customEmotionOptions) }
            .reduce(0) { $0 + $1.amount }
        let ineffectiveRatio = totalExpense > 0 ? ineffectiveTotal / totalExpense : 0
        let prescription = patternPrescriptionAdvice(for: ineffectiveRatio)

        guard !filteredExpenses.isEmpty else {
            return GeneratedInsight(
                badges: [],
                ineffectiveRatio: 0,
                prescriptionAdvice: localization.text(.analysisPatternEmptyTip),
                isEmpty: true,
                isSparseSample: false
            )
        }

        var candidates: [(badge: InsightFeatureBadge, score: Int)] = []
        let totalCount = filteredExpenses.count

        let weekdayCount = Dictionary(grouping: filteredExpenses, by: {
            calendarForAnalysisGrid.component(.weekday, from: $0.createdAt)
        })
        if let topWeekday = weekdayCount.max(by: { $0.value.count < $1.value.count }),
           isHighConfidence(topWeekday.value.count, total: totalCount) {
            let name = localizedWeekdayName(index: topWeekday.key)
            candidates.append((
                badge: InsightFeatureBadge(
                    id: "weekday-\(topWeekday.key)",
                    systemImage: "calendar",
                    label: localizedTemplate(.analysisPatternBadgeWeekday, name),
                    count: topWeekday.value.count
                ),
                score: topWeekday.value.count
            ))
        }

        let timeCount = Dictionary(grouping: filteredExpenses, by: {
            timeBucket(for: $0.createdAt)
        })
        if let topTime = timeCount.max(by: { $0.value.count < $1.value.count }),
           isHighConfidence(topTime.value.count, total: totalCount) {
            let name = localizedTimeBucketName(topTime.key)
            candidates.append((
                badge: InsightFeatureBadge(
                    id: "time-\(topTime.key)",
                    systemImage: patternTimeBucketIcon(topTime.key),
                    label: localizedTemplate(.analysisPatternBadgeTime, name),
                    count: topTime.value.count
                ),
                score: topTime.value.count
            ))
        }

        let categoryCount = Dictionary(grouping: filteredExpenses, by: \.categoryKey)
        if let topCategory = categoryCount.max(by: { $0.value.count < $1.value.count }),
           isHighConfidence(topCategory.value.count, total: totalCount),
           let sample = topCategory.value.first {
            let categoryName = localizedCategoryDisplayName(for: sample)
            candidates.append((
                badge: InsightFeatureBadge(
                    id: "category-\(topCategory.key)",
                    systemImage: "fork.knife",
                    label: localizedTemplate(.analysisPatternBadgeCategory, categoryName),
                    count: topCategory.value.count
                ),
                score: topCategory.value.count
            ))
        }

        let badges = candidates
            .sorted { $0.score > $1.score }
            .prefix(2)
            .map(\.badge)

        if badges.isEmpty {
            let sparseAdvice = totalCount < 3
                ? localization.text(.analysisPatternTip)
                : localization.text(.analysisPatternFallback)
            return GeneratedInsight(
                badges: [],
                ineffectiveRatio: ineffectiveRatio,
                prescriptionAdvice: sparseAdvice,
                isEmpty: false,
                isSparseSample: true
            )
        }

        return GeneratedInsight(
            badges: badges,
            ineffectiveRatio: ineffectiveRatio,
            prescriptionAdvice: prescription,
            isEmpty: false,
            isSparseSample: false
        )
    }

    private func localizedCategoryDisplayName(for record: TransactionRecord) -> String {
        record.resolvedCategoryForRetrospectiveDisplay(localizedText: { localization.text($0) })
    }

    private func patternPrescriptionAdvice(for ineffectiveRatio: Double) -> String {
        if ineffectiveRatio >= 0.55 {
            return localization.text(.analysisPatternPrescriptionPause)
        }
        if ineffectiveRatio >= 0.3 {
            return localization.text(.analysisPatternPrescriptionMid)
        }
        return localization.text(.analysisPatternPrescriptionLow)
    }

    private func patternTimeBucketIcon(_ bucket: TimeBucket) -> String {
        switch bucket {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "moon.stars.fill"
        case .night: return "moon.zzz.fill"
        }
    }

    private func localizedWeekdayName(index: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = localization.locale
        let symbols = formatter.weekdaySymbols ?? []
        guard index > 0 && index <= symbols.count else { return "\(index)" }
        return symbols[index - 1]
    }

    private func timeBucket(for date: Date) -> TimeBucket {
        timeBucket(for: date, calendar: .current)
    }

    private func timeBucket(for date: Date, calendar: Calendar) -> TimeBucket {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<12: return TimeBucket.morning
        case 12..<18: return TimeBucket.afternoon
        case 18..<23: return TimeBucket.evening
        default: return TimeBucket.night
        }
    }

    private func localizedTimeBucketName(_ bucket: TimeBucket) -> String {
        switch bucket {
        case .morning: localization.text(.analysisTimeMorning)
        case .afternoon: localization.text(.analysisTimeAfternoon)
        case .evening: localization.text(.analysisTimeEvening)
        case .night: localization.text(.analysisTimeNight)
        }
    }

    private func localizedTemplate(_ key: LKey, _ args: CVarArg...) -> String {
        String(format: localization.text(key), locale: localization.locale, arguments: args)
    }

    private func isHighConfidence(_ count: Int, total: Int) -> Bool {
        guard total > 0 else { return false }
        let ratio = Double(count) / Double(total)
        return count >= appSettings.patternMinCount && ratio >= appSettings.patternMinRatio
    }

}

// MARK: - Correlation chart → bill list

private struct CorrelationInspectSession: Identifiable {
    let bucketStart: Date
    let records: [TransactionRecord]

    var id: String { "\(bucketStart.timeIntervalSince1970)" }
}

// MARK: - Emotion insight (spending patterns)

private struct EmotionInsightCard: View {
    let insight: GeneratedInsight
    let ineffectiveShareLabel: String
    let motto: String
    let countSuffix: (Int) -> String

    private var ineffectivePercent: Int {
        Int((insight.ineffectiveRatio * 100).rounded())
    }

    private var ineffectiveAccent: Color {
        if insight.ineffectiveRatio >= 0.55 { return AppTheme.accentRisk }
        if insight.ineffectiveRatio >= 0.3 { return AppTheme.accentInsight }
        return AppTheme.accentSecondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if insight.isEmpty || insight.isSparseSample {
                EmotionInsightSoulPrescriptionBox(
                    advice: insight.prescriptionAdvice,
                    motto: motto,
                    accent: ineffectiveAccent
                )
            } else {
                if !insight.badges.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(insight.badges) { badge in
                                EmotionInsightFeatureBadge(
                                    badge: badge,
                                    countSuffix: countSuffix(badge.count)
                                )
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(ineffectiveShareLabel)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                        Text("\(ineffectivePercent)%")
                            .font(.system(.title3, design: .rounded).bold())
                            .monospacedDigit()
                            .foregroundStyle(ineffectiveAccent)
                    }

                    GeometryReader { proxy in
                        let width = max(0, proxy.size.width * CGFloat(insight.ineffectiveRatio))
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.06))
                            Capsule()
                                .fill(ineffectiveAccent.opacity(0.45))
                                .frame(width: width)
                        }
                    }
                    .frame(height: 3)
                }

                EmotionInsightSoulPrescriptionBox(
                    advice: insight.prescriptionAdvice,
                    motto: motto,
                    accent: ineffectiveAccent
                )
            }
        }
    }
}

private struct EmotionInsightFeatureBadge: View {
    let badge: InsightFeatureBadge
    let countSuffix: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: badge.systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.actionBlue.opacity(0.85))
            HStack(spacing: 0) {
                Text(badge.label)
                Text(" · ")
                    .foregroundStyle(Color.secondary.opacity(0.7))
                Text(countSuffix)
                    .monospacedDigit()
            }
            .font(.system(size: 13))
            .foregroundStyle(AppTheme.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.04))
        .clipShape(Capsule())
    }
}

private struct EmotionInsightSoulPrescriptionBox: View {
    let advice: String
    let motto: String
    var accent: Color = AppTheme.accentInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 6) {
                Text("💡")
                    .font(.system(size: 13))
                Text(advice)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary.opacity(0.9))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(motto)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                DashboardWatercolorBackground(
                    cornerRadius: 12,
                    palette: .emotion,
                    layout: .metricDefault
                )
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(0.14),
                                accent.opacity(0.04),
                                Color.clear,
                            ],
                            center: UnitPoint(x: 0.12, y: 0.2),
                            startRadius: 0,
                            endRadius: 160
                        )
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Mind balance (effective vs emotional spending)

private struct MindBalanceView: View {
    let effectiveHeading: String
    let ineffectiveHeading: String
    let effectiveAmount: String
    let ineffectiveAmount: String
    let effectiveRatioLabel: String
    let ineffectiveRatioLabel: String
    let effectiveRatio: Double
    let ineffectiveRatio: Double
    let insightPrimary: String
    let insightSecondary: String

    private let barHeight: CGFloat = 8
    private let barGap: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    MindBalanceCategoryLabel(
                        title: effectiveHeading,
                        systemImage: "leaf.fill",
                        tint: AppTheme.accentSecondary,
                        alignment: .leading
                    )
                    Text(effectiveAmount)
                        .font(.system(size: 20, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(effectiveRatioLabel)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 6) {
                    MindBalanceCategoryLabel(
                        title: ineffectiveHeading,
                        systemImage: "bolt.heart.fill",
                        tint: AppTheme.accentInsight,
                        alignment: .trailing
                    )
                    Text(ineffectiveAmount)
                        .font(.system(size: 20, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(ineffectiveRatioLabel)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            MindBalanceBar(
                effectiveRatio: effectiveRatio,
                ineffectiveRatio: ineffectiveRatio,
                height: barHeight,
                gap: barGap
            )

            MindBalanceInsightPanel(
                primary: insightPrimary,
                secondary: insightSecondary
            )
        }
    }
}

private struct EmotionTrendInsightPanel: View {
    let text: String
    var accent: Color = AppTheme.accentInsight

    var body: some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .foregroundStyle(AppTheme.textPrimary.opacity(0.9))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    DashboardWatercolorBackground(
                        cornerRadius: 12,
                        palette: .emotion,
                        layout: .metricDefault
                    )
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    accent.opacity(0.18),
                                    accent.opacity(0.05),
                                    Color.clear,
                                ],
                                center: UnitPoint(x: 0.1, y: 0.4),
                                startRadius: 0,
                                endRadius: 170
                            )
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct MindBalanceInsightPanel: View {
    let primary: String
    let secondary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !primary.isEmpty {
                Text(primary)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.textPrimary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(secondary)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            DashboardWatercolorBackground(
                cornerRadius: 12,
                palette: .emotion,
                layout: .metricDefault
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct MindBalanceCategoryLabel: View {
    let title: String
    let systemImage: String
    let tint: Color
    let alignment: HorizontalAlignment

    var body: some View {
        HStack(spacing: 5) {
            if alignment == .trailing {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.trailing)
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.hierarchical)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.hierarchical)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : .leading)
    }
}

private struct MindBalanceBar: View {
    let effectiveRatio: Double
    let ineffectiveRatio: Double
    let height: CGFloat
    let gap: CGFloat

    private var effectiveFill: Color {
        AppTheme.accentSecondary.opacity(0.88)
    }

    private var ineffectiveFill: LinearGradient {
        LinearGradient(
            colors: [AppTheme.accentRisk, AppTheme.accentInsight],
            startPoint: .trailing,
            endPoint: .leading
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let hasBoth = effectiveRatio > 0 && ineffectiveRatio > 0
            let reservedGap = hasBoth ? gap : 0
            let effectiveWidth = max(
                effectiveRatio > 0 ? height : 0,
                width * CGFloat(effectiveRatio) - (hasBoth ? reservedGap / 2 : 0)
            )
            let ineffectiveWidth = max(
                ineffectiveRatio > 0 ? height : 0,
                width * CGFloat(ineffectiveRatio) - (hasBoth ? reservedGap / 2 : 0)
            )

            ZStack {
                Capsule()
                    .fill(Color.primary.opacity(0.06))

                HStack(spacing: hasBoth ? gap : 0) {
                    Capsule()
                        .fill(effectiveFill)
                        .frame(width: effectiveWidth)
                    Spacer(minLength: 0)
                    Capsule()
                        .fill(ineffectiveFill)
                        .frame(width: ineffectiveWidth)
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Emotion time bubble heatmap

private struct EmotionTimeHeatmapView: View {
    let weekLabels: [String]
    let timeLabels: [String]
    let cells: [EmotionHeatmapCell]
    let periodMode: PeriodMode
    let dataSignature: String
    let animationEpoch: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.analysisChartMotionMode) private var chartMotionMode
    @State private var revealedCellIDs: Set<String> = []
    @State private var revealGeneration = 0

    private let baseStaggerStep: Double = 0.032
    private let compactStaggerStep: Double = 0.02
    private let compactStaggerThreshold = 12

    private var cellLookup: [String: EmotionHeatmapCell] {
        Dictionary(uniqueKeysWithValues: cells.map { ("\($0.weekdayLabel)|\($0.timeLabel)", $0) })
    }

    private var revealKey: String {
        "\(periodMode.rawValue)|\(dataSignature)|\(animationEpoch)"
    }

    private var consumptiveCellsInDisplayOrder: [EmotionHeatmapCell] {
        var ordered: [EmotionHeatmapCell] = []
        for week in weekLabels {
            for time in timeLabels {
                guard let cell = cellLookup["\(week)|\(time)"], cell.hasConsumption else { continue }
                ordered.append(cell)
            }
        }
        return ordered
    }

    private var usesLiveTimeline: Bool {
        !reduceMotion && chartMotionMode == .live
    }

    var body: some View {
        Group {
            if usesLiveTimeline {
                TimelineView(.animation(minimumInterval: 1.0 / 20)) { timeline in
                    heatmapGrid(animationTime: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                heatmapGrid(animationTime: 0)
            }
        }
        .padding(.vertical, 4)
        .onAppear { playEntrance() }
        .onChange(of: revealKey) { _, _ in
            playEntrance()
        }
        .onChange(of: chartMotionMode) { _, mode in
            if mode == .suspended {
                suspendEntrance()
            }
        }
    }

    private func heatmapGrid(animationTime: TimeInterval) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: 34, height: 1)
                ForEach(timeLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(weekLabels, id: \.self) { week in
                HStack(spacing: 0) {
                    Text(week)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                        .lineLimit(1)
                        .frame(width: 34, alignment: .leading)

                    ForEach(timeLabels, id: \.self) { time in
                        ZStack {
                            if let cell = cellLookup["\(week)|\(time)"] {
                                EmotionTimeHeatmapBubbleView(
                                    cell: cell,
                                    isRevealed: isCellRevealed(cell),
                                    animationTime: animationTime
                                )
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                    }
                }
            }
        }
    }

    private func isCellRevealed(_ cell: EmotionHeatmapCell) -> Bool {
        guard cell.hasConsumption else { return true }
        return reduceMotion || revealedCellIDs.contains(cell.id)
    }

    private func snapEntranceToRevealed() {
        let dataCells = consumptiveCellsInDisplayOrder
        revealedCellIDs = Set(dataCells.map(\.id))
    }

    private func suspendEntrance() {
        revealGeneration += 1
        snapEntranceToRevealed()
    }

    private func playEntrance() {
        let dataCells = consumptiveCellsInDisplayOrder.shuffled()
        guard !dataCells.isEmpty else {
            revealedCellIDs = []
            return
        }
        guard !reduceMotion else {
            snapEntranceToRevealed()
            return
        }
        guard chartMotionMode == .live else {
            snapEntranceToRevealed()
            return
        }

        revealGeneration += 1
        let generation = revealGeneration
        revealedCellIDs = []

        let staggerStep = dataCells.count > compactStaggerThreshold
            ? compactStaggerStep
            : baseStaggerStep
        let stepNanoseconds = UInt64(staggerStep * 1_000_000_000)

        Task { @MainActor in
            await Task.yield()
            var isFirst = true
            for cell in dataCells {
                guard generation == revealGeneration else { return }
                if !isFirst {
                    try? await Task.sleep(nanoseconds: stepNanoseconds)
                }
                isFirst = false
                guard generation == revealGeneration else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = false
                transaction.animation = .spring(response: 0.46, dampingFraction: 0.82)
                withTransaction(transaction) {
                    _ = revealedCellIDs.insert(cell.id)
                }
            }
        }
    }
}

private struct EmotionTimeHeatmapBubbleView: View {
    let cell: EmotionHeatmapCell
    let isRevealed: Bool
    let animationTime: TimeInterval

    var body: some View {
        ZStack {
            if cell.hasConsumption {
                let breathing = 0.92 + 0.08 * sin(animationTime * 2 * .pi / 3.8 + cell.phaseOffset)
                bubbleCircle(breathingScale: breathing)
                .scaleEffect(isRevealed ? 1 : 0.001)
                .opacity(isRevealed ? 1 : 0)
            } else {
                Circle()
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: 1, height: 1)
            }
        }
        .frame(width: 28, height: 28)
    }

    private func bubbleCircle(breathingScale: CGFloat) -> some View {
        Circle()
            .fill(cell.dominantEmotionColor.opacity(0.8))
            .frame(width: cell.bubbleDiameter, height: cell.bubbleDiameter)
            .scaleEffect(breathingScale)
            .blur(radius: 1)
    }
}

private enum TimeBucket: Hashable {
    case morning
    case afternoon
    case evening
    case night
}

private enum AnalysisScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    AnalysisView()
        .environmentObject(LocalizationManager())
        .environmentObject(AppSettings())
        .environmentObject(NotificationCenterStore())
        .environmentObject(AnalysisTabMetricsStore())
        .environmentObject(RootTabCoordinator())
        .environmentObject(AnalysisScrollActivityTracker())
        .modelContainer(for: [TransactionRecord.self, CustomOption.self], inMemory: true)
}
