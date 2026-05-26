import Foundation
import SwiftData

/// Resolves preset emotion labels without touching `LocalizationManager` off the main actor.
struct EmotionNameResolver: Sendable {
    private let presetByRaw: [String: String]
    private let shortPresetByRaw: [String: String]

    init(presetByRaw: [String: String], shortPresetByRaw: [String: String]) {
        self.presetByRaw = presetByRaw
        self.shortPresetByRaw = shortPresetByRaw
    }

    @MainActor
    static func make(localization: LocalizationManager) -> EmotionNameResolver {
        var presetByRaw: [String: String] = [:]
        var shortPresetByRaw: [String: String] = [:]
        presetByRaw.reserveCapacity(EmotionTag.allCases.count)
        shortPresetByRaw.reserveCapacity(EmotionTag.allCases.count)
        for tag in EmotionTag.allCases {
            presetByRaw[tag.rawValue] = localization.text(tag.key)
            shortPresetByRaw[tag.rawValue] = localization.text(tag.shortKey)
        }
        return EmotionNameResolver(presetByRaw: presetByRaw, shortPresetByRaw: shortPresetByRaw)
    }

    func resolve(raw: String, fallback: String) -> String {
        presetByRaw[raw] ?? fallback
    }

    func resolveShort(raw: String, fallback: String) -> String {
        shortPresetByRaw[raw] ?? fallback
    }
}

/// Snapshot passed into background period-scoped chart builds.
struct PeriodScopedMetricsBuildInput: @unchecked Sendable {
    let records: [TransactionRecord]
    let customEmotionOptions: [CustomOption]
    let period: PeriodMode
    let periodInterval: DateInterval
    let calendar: Calendar
    let locale: Locale
    let emotionNameResolver: EmotionNameResolver
    let correlationWarmOverlapText: String
    let spectrumInsightTextByPeriodTier: [String: String]

    @MainActor
    static func make(
        records: [TransactionRecord],
        customEmotionOptions: [CustomOption],
        period: PeriodMode,
        periodInterval: DateInterval?,
        calendar: Calendar,
        localization: LocalizationManager
    ) -> PeriodScopedMetricsBuildInput? {
        guard let periodInterval else { return nil }
        var spectrumInsightTextByPeriodTier: [String: String] = [:]
        for periodMode in PeriodMode.allCases {
            for tier in [
                AnalysisChartMetrics.SpectrumInsightTier.elevated,
                .balanced,
                .calm
            ] {
                if let key = AnalysisViewMetricsCache.spectrumInsightKey(period: periodMode, tier: tier) {
                    spectrumInsightTextByPeriodTier[
                        AnalysisViewMetricsCache.spectrumInsightLookupKey(period: periodMode, tier: tier)
                    ] = localization.text(key)
                }
            }
        }
        return PeriodScopedMetricsBuildInput(
            records: records,
            customEmotionOptions: customEmotionOptions,
            period: period,
            periodInterval: periodInterval,
            calendar: calendar,
            locale: localization.locale,
            emotionNameResolver: EmotionNameResolver.make(localization: localization),
            correlationWarmOverlapText: localization.text(.analysisCorrelationWarmOverlap),
            spectrumInsightTextByPeriodTier: spectrumInsightTextByPeriodTier
        )
    }
}

/// Precomputed chart inputs so `AnalysisView.body` does not re-run heavy metrics on every SwiftUI pass.
struct AnalysisViewMetricsCache {
    var heatRingSlices: [AnalysisChartMetrics.HeatRingSlice] = []
    var correlationPoints: [AnalysisChartMetrics.CorrelationDayPoint] = []
    var emotionSpectrumColumns: [AnalysisChartMetrics.SpectrumBucketColumn] = []
    var regretQuadrantPoints: [AnalysisChartMetrics.RegretQuadrantPoint] = []
    var spectrumInsight: AnalysisChartMetrics.SpectrumInsight?
    var correlationWarmTip: String = ""

    static let empty = AnalysisViewMetricsCache()

    @MainActor
    static func build(
        records: [TransactionRecord],
        customEmotionOptions: [CustomOption],
        period: PeriodMode,
        periodInterval: DateInterval?,
        calendar: Calendar,
        localization: LocalizationManager,
        displayEmotionName: (String, String) -> String
    ) -> AnalysisViewMetricsCache {
        guard let input = PeriodScopedMetricsBuildInput.make(
            records: records,
            customEmotionOptions: customEmotionOptions,
            period: period,
            periodInterval: periodInterval,
            calendar: calendar,
            localization: localization
        ) else {
            return AnalysisViewMetricsCache()
        }
        return buildPeriodScoped(input: input)
    }

    /// Heavy normalization / bucketing — safe to call off the main actor.
    static func buildPeriodScoped(input: PeriodScopedMetricsBuildInput) -> AnalysisViewMetricsCache {
        let filtered = input.records.filter { record in
            guard record.type == .expense else { return false }
            return record.createdAt >= input.periodInterval.start
                && record.createdAt < input.periodInterval.end
        }
        var cache = AnalysisViewMetricsCache()
        let interval = input.periodInterval
        let resolveName: (String, String) -> String = { raw, fallback in
            input.emotionNameResolver.resolve(raw: raw, fallback: fallback)
        }
        let resolveShortName: (String, String) -> String = { raw, fallback in
            input.emotionNameResolver.resolveShort(raw: raw, fallback: fallback)
        }

        cache.heatRingSlices = AnalysisChartMetrics.heatRingSlices(
            from: filtered,
            displayName: resolveShortName,
            accessibilityName: resolveName
        )

        cache.correlationPoints = AnalysisChartMetrics.correlationDayPoints(
            expenses: filtered,
            period: input.period,
            calendar: input.calendar,
            locale: input.locale,
            customEmotions: input.customEmotionOptions,
            axisLabel: { date in
                let df = DateFormatter()
                df.locale = input.locale
                df.calendar = input.calendar
                switch input.period {
                case .year:
                    df.setLocalizedDateFormatFromTemplate("MMM")
                case .day, .week, .month, .custom:
                    df.setLocalizedDateFormatFromTemplate("Md")
                }
                return df.string(from: date)
            }
        )

        cache.correlationWarmTip = cache.correlationPoints.count >= 3
            ? input.correlationWarmOverlapText
            : ""

        cache.emotionSpectrumColumns = AnalysisChartMetrics.spectrumColumns(
            expenses: filtered,
            period: input.period,
            interval: interval,
            calendar: input.calendar,
            locale: input.locale
        )

        if !filtered.isEmpty,
           let tier = AnalysisChartMetrics.spectrumInsightTier(
               expenses: filtered,
               customEmotions: input.customEmotionOptions
           ) {
            let lookup = spectrumInsightLookupKey(period: input.period, tier: tier)
            if let text = input.spectrumInsightTextByPeriodTier[lookup] {
                cache.spectrumInsight = AnalysisChartMetrics.SpectrumInsight(tier: tier, text: text)
            }
        }

        let regretScoped = input.records.filter { record in
            guard record.type == .expense, record.retrospectiveWorthRaw != nil else { return false }
            return record.createdAt >= interval.start && record.createdAt < interval.end
        }
        cache.regretQuadrantPoints = AnalysisChartMetrics.regretQuadrantPoints(
            from: regretScoped,
            customEmotions: input.customEmotionOptions,
            displayName: resolveName
        )

        return cache
    }

    static func spectrumInsightLookupKey(
        period: PeriodMode,
        tier: AnalysisChartMetrics.SpectrumInsightTier
    ) -> String {
        "\(period.rawValue)|\(tier)"
    }

    static func spectrumInsightKey(period: PeriodMode, tier: AnalysisChartMetrics.SpectrumInsightTier) -> LKey? {
        switch (period, tier) {
        case (.day, .elevated): return .analysisSpectrumInsightDayElevated
        case (.day, .balanced): return .analysisSpectrumInsightDayBalanced
        case (.day, .calm): return .analysisSpectrumInsightDayCalm
        case (.week, .elevated): return .analysisSpectrumInsightWeekElevated
        case (.week, .balanced): return .analysisSpectrumInsightWeekBalanced
        case (.week, .calm): return .analysisSpectrumInsightWeekCalm
        case (.month, .elevated): return .analysisSpectrumInsightMonthElevated
        case (.month, .balanced): return .analysisSpectrumInsightMonthBalanced
        case (.month, .calm): return .analysisSpectrumInsightMonthCalm
        case (.year, .elevated): return .analysisSpectrumInsightYearElevated
        case (.year, .balanced): return .analysisSpectrumInsightYearBalanced
        case (.year, .calm): return .analysisSpectrumInsightYearCalm
        case (.custom, .elevated): return .analysisSpectrumInsightCustomElevated
        case (.custom, .balanced): return .analysisSpectrumInsightCustomBalanced
        case (.custom, .calm): return .analysisSpectrumInsightCustomCalm
        }
    }
}
