import SwiftUI
import UIKit

// MARK: - Model

struct BillListDashboardModel {
    let totalSpentTitle: String
    let totalExpenseAmount: Double
    let expenseDeltaText: String?
    let expenseDeltaTrend: MetricTrendDeltaCapsule.Trend
    let frequencyTitle: String
    let entryCount: Int
    let entriesLabel: String
    let frequencyDeltaText: String?
    let frequencyDeltaTrend: MetricTrendDeltaCapsule.Trend
}

// MARK: - Dashboard

struct BillListMetricDashboard: View {
    let model: BillListDashboardModel
    var onExpenseTap: (() -> Void)?
    var onFrequencyTap: (() -> Void)?

    @EnvironmentObject private var currencyManager: CurrencyManager
    @EnvironmentObject private var localization: LocalizationManager

    private var expenseAccessibilityHint: String {
        onExpenseTap == nil ? "" : localization.text(.billsMetricDetailDashboardExpenseA11yHint)
    }

    private var frequencyAccessibilityHint: String {
        onFrequencyTap == nil ? "" : localization.text(.billsMetricDetailDashboardFrequencyA11yHint)
    }

    private let expenseMajorSize: CGFloat = 26
    private let expenseMinorSize: CGFloat = 14
    private let columnHorizontalPadding: CGFloat = 24

    var body: some View {
        MetricDashboardWidthContainer { availableWidth in
            twinColumnRow(totalWidth: availableWidth)
        }
        .padding(AppTheme.metricDashboardPadding)
        .background {
            DashboardWatercolorBackground(palette: .spending)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.metricDashboardCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func twinColumnRow(totalWidth: CGFloat) -> some View {
        let columns = MetricDashboardTwoColumnLayout.columnWidths(
            totalWidth: totalWidth,
            trailingContentIdealWidth: trailingContentIdealWidth(),
            leadingPrimaryIdealWidth: leadingContentIdealWidth()
        )
        let moneyScale = MetricDashboardTwoColumnLayout.leadingMoneyScale(
            columnWidth: columns.leading,
            contentIdealWidth: leadingMoneyIdealWidth(),
            horizontalPadding: columnHorizontalPadding
        )

        HStack(alignment: .top, spacing: 0) {
            expenseViewport(moneyScale: moneyScale)
                .frame(width: columns.leading > 0 ? columns.leading : nil)

            MetricDashboardSeparator()

            frequencyViewport
                .frame(width: columns.trailing > 0 ? columns.trailing : nil)
        }
    }

    private func expenseViewport(moneyScale: CGFloat) -> some View {
        dashboardTapButton(action: onExpenseTap) {
            VStack(alignment: .center, spacing: AppTheme.metricDashboardRowSpacing) {
                Text(model.totalSpentTitle)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                expenseMoneyText(scale: moneyScale)
                    .frame(maxWidth: .infinity, alignment: .center)

                deltaCapsule(text: model.expenseDeltaText, trend: model.expenseDeltaTrend)
            }
        }
        .padding(.horizontal, 12)
        .accessibilityHint(expenseAccessibilityHint)
    }

    private var frequencyViewport: some View {
        dashboardTapButton(action: onFrequencyTap) {
            VStack(alignment: .center, spacing: AppTheme.metricDashboardRowSpacing) {
                Text(model.frequencyTitle)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(model.entryCount)")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .monospacedDigit()
                    Text(model.entriesLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .monospacedDigit()
                }
                .lineLimit(1)
                .minimumScaleFactor(0.9)

                deltaCapsule(text: model.frequencyDeltaText, trend: model.frequencyDeltaTrend)
            }
        }
        .padding(.horizontal, 12)
        .accessibilityHint(frequencyAccessibilityHint)
    }

    @ViewBuilder
    private func dashboardTapButton<Content: View>(
        action: (() -> Void)?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if let action {
            Button(action: action) {
                content()
                    .frame(maxWidth: .infinity, alignment: .top)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            content()
                .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private func expenseMoneyText(scale: CGFloat) -> some View {
        let clampedScale = max(scale, MetricDashboardTwoColumnLayout.minLeadingMoneyScale)
        let majorSize = expenseMajorSize * clampedScale
        let minorSize = expenseMinorSize * clampedScale
        let minScale: CGFloat = clampedScale < 0.999 ? 1 : 0.6
        let content = expenseMoneyAttributedString(majorSize: majorSize, minorSize: minorSize)

        return Text(content)
            .lineLimit(1)
            .minimumScaleFactor(minScale)
            .allowsTightening(true)
            .scaledToFit()
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
    }

    private func expenseMoneyAttributedString(majorSize: CGFloat, minorSize: CGFloat) -> AttributedString {
        let parts = model.totalExpenseAmount.moneyDisplayParts(
            currencyManager: currencyManager,
            locale: localization.locale
        )
        var result = AttributedString(parts.major)
        result.font = .system(size: majorSize, weight: .semibold).monospacedDigit()
        result.foregroundColor = AppTheme.textPrimary

        if !parts.minor.isEmpty {
            var minor = AttributedString(parts.minor)
            minor.font = .system(size: minorSize, weight: .semibold).monospacedDigit()
            minor.foregroundColor = AppTheme.textPrimary.opacity(0.82)
            result.append(minor)
        }
        return result
    }

    private func leadingMoneyIdealWidth() -> CGFloat {
        let parts = model.totalExpenseAmount.moneyDisplayParts(
            currencyManager: currencyManager,
            locale: localization.locale
        )
        let majorFont = UIFont.monospacedDigitSystemFont(ofSize: expenseMajorSize, weight: .semibold)
        let minorFont = UIFont.monospacedDigitSystemFont(ofSize: expenseMinorSize, weight: .semibold)
        let majorWidth = MetricDashboardTwoColumnLayout.singleLineTextWidth(parts.major, font: majorFont)
        let minorWidth = parts.minor.isEmpty
            ? 0
            : MetricDashboardTwoColumnLayout.singleLineTextWidth(parts.minor, font: minorFont)
        return majorWidth + minorWidth + 2
    }

    private func trailingContentIdealWidth() -> CGFloat {
        let titleFont = UIFont.systemFont(ofSize: 12, weight: .bold)
        let titleWidth = MetricDashboardTwoColumnLayout.singleLineTextWidth(
            model.frequencyTitle,
            font: titleFont
        )
        let frequencyWidth = MetricDashboardTwoColumnLayout.frequencyRowWidth(
            count: model.entryCount,
            entriesLabel: model.entriesLabel
        )
        let deltaWidth: CGFloat = {
            guard let text = model.frequencyDeltaText else { return 0 }
            return MetricDashboardTwoColumnLayout.deltaCapsuleWidth(for: text)
        }()
        return max(titleWidth, frequencyWidth, deltaWidth)
    }

    private func leadingContentIdealWidth() -> CGFloat {
        max(
            leadingMoneyIdealWidth(),
            MetricDashboardTwoColumnLayout.deltaCapsuleWidth(for: model.expenseDeltaText)
        )
    }

    @ViewBuilder
    private func deltaCapsule(text: String?, trend: MetricTrendDeltaCapsule.Trend) -> some View {
        if let text {
            MetricTrendDeltaCapsule(text: text, trend: trend)
        } else {
            Color.clear
                .frame(height: AppTheme.metricDashboardDeltaRowHeight)
        }
    }
}

#Preview("Dashboard") {
    BillListMetricDashboard(
        model: BillListDashboardModel(
            totalSpentTitle: "本月总支出",
            totalExpenseAmount: 1_028_400,
            expenseDeltaText: "↑ 较上月 +15%",
            expenseDeltaTrend: .up,
            frequencyTitle: "本月消费频次",
            entryCount: 30,
            entriesLabel: "笔",
            frequencyDeltaText: "↑ 较上月 +29笔",
            frequencyDeltaTrend: .up
        )
    )
    .environmentObject(CurrencyManager())
    .environmentObject(LocalizationManager())
    .padding()
    .background(AppTheme.pageBackground)
}
