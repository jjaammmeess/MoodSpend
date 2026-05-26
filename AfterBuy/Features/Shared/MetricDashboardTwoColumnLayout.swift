import SwiftUI
import UIKit

/// Twin-metric dashboard (bills list, emotion review): reserve the trailing column first so it stays on one line.
enum MetricDashboardTwoColumnLayout {
    static let separatorWidth: CGFloat = 1
    static let minTrailingColumnWidth: CGFloat = 112
    static let minLeadingColumnWidth: CGFloat = 72
    static let columnHorizontalPadding: CGFloat = 24
    static let minLeadingMoneyScale: CGFloat = 0.5

    /// Leading = expense / primary amount; trailing = frequency / secondary.
    /// When the leading amount and trailing column both fit within half width, split 50/50;
    /// otherwise reserve the trailing column first and give the remainder to the leading column.
    static func columnWidths(
        totalWidth: CGFloat,
        trailingContentIdealWidth: CGFloat,
        leadingPrimaryIdealWidth: CGFloat
    ) -> (leading: CGFloat, trailing: CGFloat) {
        let available = max(totalWidth - separatorWidth, 0)
        let half = available / 2
        let leadingMoneyReserve = leadingPrimaryIdealWidth + columnHorizontalPadding
        let trailingReserve = max(
            minTrailingColumnWidth,
            trailingContentIdealWidth + columnHorizontalPadding
        )
        let leadingFitsHalf = leadingMoneyReserve <= half
        let trailingFitsHalf = trailingReserve <= half

        if leadingFitsHalf, trailingFitsHalf {
            return (half, half)
        }

        if available >= trailingReserve + minLeadingColumnWidth {
            return (available - trailingReserve, trailingReserve)
        }

        if trailingReserve <= available {
            return (max(available - trailingReserve, 0), trailingReserve)
        }

        return (0, available)
    }

    static func leadingMoneyScale(
        columnWidth: CGFloat,
        contentIdealWidth: CGFloat,
        horizontalPadding: CGFloat = 24
    ) -> CGFloat {
        let contentWidth = max(columnWidth - horizontalPadding, 0)
        guard contentIdealWidth > 0 else { return 1 }
        if contentWidth >= contentIdealWidth {
            return 1
        }
        return max(contentWidth / contentIdealWidth, minLeadingMoneyScale)
    }

    static func singleLineTextWidth(
        _ text: String,
        font: UIFont
    ) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    static func frequencyRowWidth(
        count: Int,
        entriesLabel: String,
        countFontSize: CGFloat = 26,
        labelFontSize: CGFloat = 12
    ) -> CGFloat {
        let countFont = UIFont.monospacedDigitSystemFont(ofSize: countFontSize, weight: .semibold)
        let labelFont = UIFont.systemFont(ofSize: labelFontSize, weight: .medium)
        let countWidth = singleLineTextWidth("\(count)", font: countFont)
        let labelWidth = singleLineTextWidth(entriesLabel, font: labelFont)
        return countWidth + 4 + labelWidth
    }

    /// Width of a single-line delta capsule (`MetricTrendDeltaCapsule` horizontal padding included).
    static func deltaCapsuleWidth(for text: String?) -> CGFloat {
        guard let text, !text.isEmpty else { return 0 }
        let font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        return singleLineTextWidth(text, font: font) + 16
    }
}

/// Supplies horizontal space for twin-column layout without expanding vertical space in pinned headers.
///
/// Avoid `GeometryReader` in `.background` here — inside `safeAreaInset` it steals all offered height
/// and creates a large ghost gap above the metric card.
struct MetricDashboardWidthContainer<Columns: View>: View {
    @State private var availableWidth: CGFloat = 0
    @ViewBuilder var columns: (CGFloat) -> Columns

    var body: some View {
        columns(availableWidth)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { _, newWidth in
                guard newWidth > 0, abs(newWidth - availableWidth) > 0.5 else { return }
                availableWidth = newWidth
            }
    }
}
