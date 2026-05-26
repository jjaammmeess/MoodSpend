import SwiftUI

/// Flat contrast capsule for dashboard deltas (bills, emotion review, etc.).
struct MetricTrendDeltaCapsule: View {
    enum Trend {
        case up
        case down
        case flat
        case neutral
    }

    let text: String
    let trend: Trend

    private var backgroundColor: Color {
        switch trend {
        case .up:
            return Color(hex: "F5D6D3")
        case .down:
            return Color(hex: "D4EBDF")
        case .flat, .neutral:
            return Color.primary.opacity(0.06)
        }
    }

    private var foregroundColor: Color {
        switch trend {
        case .up:
            return Color(hex: "B84A3F")
        case .down:
            return Color(hex: "3A7A55")
        case .flat, .neutral:
            return AppTheme.textSecondary
        }
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .clipShape(Capsule())
    }
}
