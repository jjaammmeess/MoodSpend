import SwiftUI

/// Trailing grid slot for “add custom” flows: matches category/emotion orb layout but does not participate in selection scaling.
struct GridAddSlotCell: View {
    let title: String
    let accessibilityLabel: String
    var metrics: CategoryGridLayoutMetrics = .defaultLargePhone
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: metrics.iconTextSpacing) {
                ZStack {
                    Circle()
                        .fill(AppTheme.divider.opacity(0.4))
                        .frame(width: metrics.orbSize, height: metrics.orbSize)
                    Image(systemName: "plus")
                        .font(.system(size: metrics.iconFontSize, weight: .semibold))
                        .foregroundStyle(AppTheme.actionBlue)
                        .symbolRenderingMode(.monochrome)
                    Circle()
                        .strokeBorder(AppTheme.border.opacity(0.72), lineWidth: metrics.ringWidthNormal)
                        .frame(width: metrics.orbSize, height: metrics.orbSize)
                }
                .frame(width: metrics.orbLayoutCap, height: metrics.orbLayoutCap)

                Text(title)
                    .font(.system(size: metrics.titleFontSize, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, metrics.cellVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
