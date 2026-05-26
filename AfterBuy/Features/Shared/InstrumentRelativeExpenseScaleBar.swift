import SwiftUI

/// Ten vertical ticks; fill level follows `progressRatio`. Warning tint when ratio crosses `warningThreshold`.
struct InstrumentRelativeExpenseScaleBar: View {
    let progressRatio: Double
    var tickCount: Int = 10
    /// Bills: `1.0` with `warningUsesInclusive == false` (only above 100%). Analysis distress share: `0.9` inclusive.
    var warningThreshold: Double = 1.0
    var warningUsesInclusive: Bool = false

    private var isWarningState: Bool {
        if warningUsesInclusive {
            return progressRatio >= warningThreshold
        }
        return progressRatio > warningThreshold
    }

    private var activeTickColor: Color {
        if isWarningState {
            return AppTheme.accentRisk.opacity(0.88)
        }
        return AppTheme.actionBlue
    }

    private var dimTickColor: Color {
        AppTheme.textPrimary.opacity(0.12)
    }

    private func isTickLit(index: Int) -> Bool {
        if isWarningState {
            return true
        }
        guard tickCount > 0 else { return false }
        return Double(index) / Double(tickCount) <= progressRatio
    }

    private let tickWidth: CGFloat = 3
    private let tickHeight: CGFloat = 7
    private let tickSpacing: CGFloat = 6

    var body: some View {
        HStack(spacing: tickSpacing) {
            ForEach(0..<tickCount, id: \.self) { index in
                Capsule()
                    .fill(isTickLit(index: index) ? activeTickColor : dimTickColor)
                    .frame(width: tickWidth, height: tickHeight)
            }
        }
        .animation(.easeOut(duration: 0.28), value: progressRatio)
    }
}
