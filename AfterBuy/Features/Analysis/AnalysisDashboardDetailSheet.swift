import SwiftUI

enum AnalysisDashboardDetailKind: String, Identifiable {
    case distress
    case fulfillment

    var id: String { rawValue }
}

struct AnalysisDashboardDetailSession: Identifiable {
    let kind: AnalysisDashboardDetailKind
    var id: String { kind.rawValue }
}

struct AnalysisDashboardDetailSheet: View {
    let kind: AnalysisDashboardDetailKind
    let periodExpenses: [TransactionRecord]
    let periodTotalExpense: Double
    let customEmotions: [CustomOption]
    let periodMode: PeriodMode
    let fulfillmentFooterNote: String?

    @EnvironmentObject private var localization: LocalizationManager

    private var filteredRecords: [TransactionRecord] {
        switch kind {
        case .distress:
            return periodExpenses.filter {
                AnalysisChartMetrics.isDistressRecord($0, customEmotions: customEmotions)
            }
        case .fulfillment:
            return periodExpenses.filter {
                AnalysisChartMetrics.isFulfillmentRecord($0, customEmotions: customEmotions)
            }
        }
    }

    private var navigationTitle: String {
        let metricName = localization.text(
            kind == .distress ? .analysisDashboardDistressTitle : .analysisDashboardFulfillmentTitle
        )
        let periodLabel = localization.text(periodLabelKey)
        return String(
            format: localization.text(.analysisDashboardDetailTitle),
            locale: localization.locale,
            arguments: [metricName, periodLabel]
        )
    }

    private var periodLabelKey: LKey {
        switch periodMode {
        case .day: return .analysisDashboardDetailPeriodDay
        case .week: return .analysisDashboardDetailPeriodWeek
        case .month: return .analysisDashboardDetailPeriodMonth
        case .year: return .analysisDashboardDetailPeriodYear
        case .custom: return .analysisDashboardDetailPeriodCustom
        }
    }

    private var emptyStateKey: LKey {
        kind == .distress
            ? .analysisDashboardDetailEmptyDistress
            : .analysisDashboardDetailEmptyFulfillment
    }

    private var scopeNoteText: String? {
        switch kind {
        case .distress:
            return localization.text(.analysisDashboardDetailDistressScopeNote)
        case .fulfillment:
            return localization.text(.analysisDashboardDetailFulfillmentScopeNote)
        }
    }

    var body: some View {
        EmotionExpenseDetailSheet(
            navigationTitle: navigationTitle,
            records: filteredRecords,
            periodTotalExpense: periodTotalExpense,
            emptyStateTitle: localization.text(emptyStateKey),
            shareOfPeriodFormatKey: kind == .distress ? .analysisDashboardDetailShareOfPeriod : nil,
            scopeNote: scopeNoteText,
            footerNote: kind == .fulfillment ? fulfillmentFooterNote : nil,
            presentation: .analysisDashboard(kind)
        )
    }
}
