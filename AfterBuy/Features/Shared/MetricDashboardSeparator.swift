import SwiftUI

/// Vertical rule between twin-metric dashboard columns (bills list, emotion review).
struct MetricDashboardSeparator: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(separatorColor)
            .frame(width: 1, height: 68)
    }

    private var separatorColor: Color {
        if colorScheme == .dark {
            // `border` on `metricDashboardFill` is too low-contrast in dark mode.
            return AppTheme.textSecondary.opacity(0.52)
        }
        return AppTheme.border.opacity(0.60)
    }
}
