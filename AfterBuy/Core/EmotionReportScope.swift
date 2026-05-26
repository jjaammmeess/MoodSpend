import Foundation

/// Report scope aligned with the active `AppPeriodContext` interval (not calendar-relative `DateFilter`).
struct EmotionReportScope: Equatable, Identifiable {
    var id: String {
        "\(periodMode.rawValue)|\(interval.start.timeIntervalSince1970)|\(interval.end.timeIntervalSince1970)"
    }
    let periodMode: PeriodMode
    let interval: DateInterval
    let periodLabel: String
    /// Share-poster headline without the date range (range shown beside generated-at).
    let posterTitle: String
    /// Navigation bar title (period-only for custom; CJK period-only; short English suffix otherwise).
    let navigationBarTitle: String
    let title: String
    let heroCaption: String
    let noDataMessage: String
    let exportFilenameSuffix: String

    var expenseLabelKey: LKey {
        switch periodMode {
        case .day: return .analysisMetricExpenseTitleDay
        case .week: return .analysisMetricExpenseTitleWeek
        case .month: return .analysisMetricExpenseTitleMonth
        case .year: return .analysisMetricExpenseTitleYear
        case .custom: return .analysisReportTotalExpense
        }
    }
}

extension AppPeriodContext {
    /// Builds report metadata for the currently selected period; `nil` when custom range is unset.
    func makeEmotionReportScope(
        localize: (LKey) -> String,
        locale: Locale
    ) -> EmotionReportScope? {
        guard let interval = dateInterval else { return nil }

        let periodLabel: String
        switch selectedPeriod {
        case .custom:
            guard let range = customRange else { return nil }
            periodLabel = Self.insightRangeLabel(
                for: range.normalized,
                localize: localize,
                locale: locale
            )
        default:
            periodLabel = navigationTitle(localize: localize, locale: locale)
        }

        let navigationBarTitle: String
        switch selectedPeriod {
        case .custom:
            // Custom range labels are already long (e.g. "2026 · 3–5"); omit English suffix.
            navigationBarTitle = periodLabel
        default:
            navigationBarTitle = String(
                format: localize(.analysisReportNavTitleForPeriod),
                locale: locale,
                arguments: [periodLabel]
            )
        }
        let title = String(
            format: localize(.analysisReportTitleForPeriod),
            locale: locale,
            arguments: [periodLabel]
        )
        let heroCaption = String(
            format: localize(.analysisReportHeroCaptionForPeriod),
            locale: locale,
            arguments: [periodLabel]
        )
        let noDataMessage = String(
            format: localize(.analysisReportNoDataForPeriod),
            locale: locale,
            arguments: [periodLabel]
        )

        return EmotionReportScope(
            periodMode: selectedPeriod,
            interval: interval,
            periodLabel: periodLabel,
            posterTitle: Self.posterTitle(for: selectedPeriod, localize: localize),
            navigationBarTitle: navigationBarTitle,
            title: title,
            heroCaption: heroCaption,
            noDataMessage: noDataMessage,
            exportFilenameSuffix: Self.exportFilenameSuffix(
                periodMode: selectedPeriod,
                periodLabel: periodLabel
            )
        )
    }

    private static func posterTitle(for mode: PeriodMode, localize: (LKey) -> String) -> String {
        switch mode {
        case .day: return localize(.analysisReportTitleDay)
        case .week: return localize(.analysisReportTitleWeek)
        case .month: return localize(.analysisReportTitle)
        case .year: return localize(.analysisReportTitleYear)
        case .custom: return localize(.analysisReportPosterTitleCustom)
        }
    }

    private static func exportFilenameSuffix(periodMode: PeriodMode, periodLabel: String) -> String {
        let sanitized = periodLabel
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "年", with: "y")
            .replacingOccurrences(of: "月", with: "m")
        if sanitized.isEmpty {
            return periodMode.rawValue
        }
        return sanitized
    }
}
