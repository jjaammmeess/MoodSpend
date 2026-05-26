import SwiftUI
import UIKit

struct AnalysisEmotionDashboardModel {
    let distressTitle: String
    let distressExpenseAmount: Double
    let distressShareText: String?
    let distressShareTrend: MetricTrendDeltaCapsule.Trend
    let distressShareA11y: String
    let fulfillmentTitle: String
    let fulfillmentEntryCount: Int
    let entriesLabel: String
    let positiveRateDeltaText: String?
    let positiveRateDeltaTrend: MetricTrendDeltaCapsule.Trend
}

struct AnalysisEmotionDashboard: View {
    let model: AnalysisEmotionDashboardModel
    var openDetailAccessibilityHint: String = ""
    var onDistressTap: (() -> Void)?
    var onFulfillmentTap: (() -> Void)?

    @EnvironmentObject private var currencyManager: CurrencyManager
    @EnvironmentObject private var localization: LocalizationManager

    private let distressMajorSize: CGFloat = 24
    private let distressMinorSize: CGFloat = 14
    private let columnHorizontalPadding: CGFloat = 24

    var body: some View {
        MetricDashboardWidthContainer { availableWidth in
            twinColumnRow(totalWidth: availableWidth)
        }
        .padding(AppTheme.metricDashboardPadding)
        .background {
            DashboardWatercolorBackground(palette: .emotion)
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
            dashboardTapButton(action: onDistressTap) {
                distressViewport(moneyScale: moneyScale)
            }
            .frame(width: columns.leading > 0 ? columns.leading : nil)

            MetricDashboardSeparator()
                .allowsHitTesting(false)

            dashboardTapButton(action: onFulfillmentTap) {
                fulfillmentViewport
            }
            .frame(width: columns.trailing > 0 ? columns.trailing : nil)
        }
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
        }
    }

    private func distressViewport(moneyScale: CGFloat) -> some View {
        VStack(alignment: .center, spacing: AppTheme.metricDashboardRowSpacing) {
            Text(model.distressTitle)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            distressMoneyText(scale: moneyScale)
                .frame(maxWidth: .infinity, alignment: .center)

            deltaCapsule(text: model.distressShareText, trend: model.distressShareTrend)
                .accessibilityLabel(model.distressShareA11y)
        }
        .padding(.horizontal, 12)
        .accessibilityHint(Text(openDetailAccessibilityHint))
    }

    private var fulfillmentViewport: some View {
        VStack(alignment: .center, spacing: AppTheme.metricDashboardRowSpacing) {
            Text(model.fulfillmentTitle)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(model.fulfillmentEntryCount)")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .monospacedDigit()
                Text(model.entriesLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .monospacedDigit()
            }
            .lineLimit(1)
            .minimumScaleFactor(0.9)

            deltaCapsule(text: model.positiveRateDeltaText, trend: model.positiveRateDeltaTrend)
        }
        .padding(.horizontal, 12)
        .accessibilityHint(Text(openDetailAccessibilityHint))
    }

    private func distressMoneyText(scale: CGFloat) -> some View {
        let clampedScale = max(scale, MetricDashboardTwoColumnLayout.minLeadingMoneyScale)
        let majorSize = distressMajorSize * clampedScale
        let minorSize = distressMinorSize * clampedScale
        let minScale: CGFloat = clampedScale < 0.999 ? 1 : 0.6
        let content = distressMoneyAttributedString(majorSize: majorSize, minorSize: minorSize)

        return Text(content)
            .lineLimit(1)
            .minimumScaleFactor(minScale)
            .allowsTightening(true)
            .scaledToFit()
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
    }

    private func distressMoneyAttributedString(majorSize: CGFloat, minorSize: CGFloat) -> AttributedString {
        let parts = model.distressExpenseAmount.moneyDisplayParts(
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
        let parts = model.distressExpenseAmount.moneyDisplayParts(
            currencyManager: currencyManager,
            locale: localization.locale
        )
        let majorFont = UIFont.monospacedDigitSystemFont(ofSize: distressMajorSize, weight: .semibold)
        let minorFont = UIFont.monospacedDigitSystemFont(ofSize: distressMinorSize, weight: .semibold)
        let majorWidth = MetricDashboardTwoColumnLayout.singleLineTextWidth(parts.major, font: majorFont)
        let minorWidth = parts.minor.isEmpty
            ? 0
            : MetricDashboardTwoColumnLayout.singleLineTextWidth(parts.minor, font: minorFont)
        return majorWidth + minorWidth + 2
    }

    private func trailingContentIdealWidth() -> CGFloat {
        let titleFont = UIFont.systemFont(ofSize: 12, weight: .bold)
        let titleWidth = MetricDashboardTwoColumnLayout.singleLineTextWidth(
            model.fulfillmentTitle,
            font: titleFont
        )
        let frequencyWidth = MetricDashboardTwoColumnLayout.frequencyRowWidth(
            count: model.fulfillmentEntryCount,
            entriesLabel: model.entriesLabel,
            countFontSize: 24,
            labelFontSize: 12
        )
        let deltaWidth: CGFloat = {
            guard let text = model.positiveRateDeltaText else { return 0 }
            return MetricDashboardTwoColumnLayout.deltaCapsuleWidth(for: text)
        }()
        return max(titleWidth, frequencyWidth, deltaWidth)
    }

    private func leadingContentIdealWidth() -> CGFloat {
        max(
            leadingMoneyIdealWidth(),
            MetricDashboardTwoColumnLayout.deltaCapsuleWidth(for: model.distressShareText)
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

#Preview {
    AnalysisEmotionDashboard(
        model: AnalysisEmotionDashboardModel(
            distressTitle: "情绪内耗",
            distressExpenseAmount: 10_001_472,
            distressShareText: "本期占比 100%",
            distressShareTrend: .up,
            distressShareA11y: "情绪内耗占本期支出 100%",
            fulfillmentTitle: "内心充实",
            fulfillmentEntryCount: 8,
            entriesLabel: "笔",
            positiveRateDeltaText: "↑ 正向率较上月 +27%",
            positiveRateDeltaTrend: .up
        )
    )
    .environmentObject(CurrencyManager())
    .environmentObject(LocalizationManager())
    .padding()
    .background(AppTheme.pageBackground)
}
