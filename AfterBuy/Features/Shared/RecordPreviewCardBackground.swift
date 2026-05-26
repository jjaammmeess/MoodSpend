import SwiftUI

/// Compact metric-card watercolor for record preview rows (delete confirm, etc.).
struct RecordPreviewCardBackground: View {
    let record: TransactionRecord

    private static let glowScale: CGFloat = 0.7
    private static let accentOpacityScale: Double = 0.65

    private var bucket: EmotionBucket {
        if let snap = record.emotionBucketRaw, let resolved = EmotionBucket(rawValue: snap) {
            return resolved
        }
        if let emotion = EmotionTag.from(raw: record.emotionRaw) {
            switch emotion {
            case .pamper, .ritual:
                return .effective
            case .necessity:
                return .necessary
            case .impulse, .stress, .social:
                return .emotional
            }
        }
        return .emotional
    }

    private var watercolorPalette: DashboardWatercolorPalette {
        EmotionExpenseDetailPresentation.homeBucket(bucket).watercolorPalette
    }

    var body: some View {
        let radius = AppTheme.metricDashboardCornerRadius
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let accent = record.emotionColor
        let accentScale = Self.accentOpacityScale

        ZStack {
            DashboardWatercolorBackground(
                cornerRadius: radius,
                palette: watercolorPalette,
                glowExtentScale: Self.glowScale
            )

            shape.fill(
                RadialGradient(
                    colors: [
                        accent.opacity(0.22 * accentScale),
                        accent.opacity(0.07 * accentScale),
                        Color.clear,
                    ],
                    center: UnitPoint(x: 0.88, y: 0.38),
                    startRadius: 0,
                    endRadius: 90
                )
            )

            shape.fill(
                RadialGradient(
                    colors: [
                        accent.opacity(0.14 * accentScale),
                        accent.opacity(0.04 * accentScale),
                        Color.clear,
                    ],
                    center: UnitPoint(x: 0.10, y: 0.94),
                    startRadius: 0,
                    endRadius: 77
                )
            )
        }
    }
}
