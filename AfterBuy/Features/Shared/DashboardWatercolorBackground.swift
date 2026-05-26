import SwiftUI

/// Metric cards & mood-spectrum guide: cool base with soft teal / purple / warm washes.
enum WatercolorGlowLayout {
    /// Bills / emotion dashboard: primary wash from bottom-leading.
    case metricDefault
    /// Record sheet sections: primary wash from bottom-trailing.
    case recordSheetSection
}

struct DashboardWatercolorBackground: View {
    var cornerRadius: CGFloat = AppTheme.metricDashboardCornerRadius
    var palette: DashboardWatercolorPalette = .spending
    var layout: WatercolorGlowLayout = .metricDefault
    /// Scales radial reach for tall record-sheet cards (`max(w,h) / 160`).
    var glowExtentScale: CGFloat = 1

    @Environment(\.colorScheme) private var colorScheme

    private var effectiveGlowScale: CGFloat { max(glowExtentScale, 1) }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let anchors = layoutAnchors
        let scale = effectiveGlowScale
        ZStack {
            shape.fill(AppTheme.metricDashboardFill)

            if layout == .recordSheetSection {
                shape.fill(
                    LinearGradient(
                        colors: [
                            trailingAccent.opacity(recordAmbientTopLeadingOpacity),
                            AppTheme.accentSecondary.opacity(recordAmbientMidOpacity),
                            primaryGlow.opacity(recordAmbientBottomTrailingOpacity),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                shape.fill(
                    RadialGradient(
                        colors: [
                            AppTheme.accentSecondary.opacity(recordAmbientCenterOpacity),
                            Color.clear,
                        ],
                        center: UnitPoint(x: 0.52, y: 0.38),
                        startRadius: 0,
                        endRadius: 220 * scale
                    )
                )
            }

            shape.fill(
                RadialGradient(
                    colors: [
                        primaryGlow.opacity(primaryWashOpacity),
                        primaryGlow.opacity(primaryWashMidOpacity),
                        primaryGlow.opacity(primaryWashOuterOpacity),
                        .clear,
                    ],
                    center: anchors.primary,
                    startRadius: 0,
                    endRadius: 136 * scale
                )
            )

            shape.fill(
                RadialGradient(
                    colors: [
                        AppTheme.accentSecondary.opacity(secondaryWashOpacity),
                        AppTheme.accentSecondary.opacity(secondaryWashMidOpacity),
                        .clear,
                    ],
                    center: anchors.secondary,
                    startRadius: 0,
                    endRadius: 112 * scale
                )
            )

            shape.fill(
                RadialGradient(
                    colors: [
                        primaryGlow.opacity(tertiaryWashOpacity),
                        .clear,
                    ],
                    center: anchors.tertiary,
                    startRadius: 4,
                    endRadius: 88 * scale
                )
            )

            shape.fill(
                RadialGradient(
                    colors: [
                        primaryGlow.opacity(coreWashOpacity),
                        primaryGlow.opacity(coreWashOpacity * 0.45),
                        .clear,
                    ],
                    center: anchors.core,
                    startRadius: 0,
                    endRadius: 56 * scale
                )
            )

            shape.fill(
                RadialGradient(
                    colors: [
                        trailingAccent.opacity(trailingAccentOpacity),
                        trailingAccent.opacity(trailingAccentOpacity * 0.35),
                        .clear,
                    ],
                    center: anchors.trailing,
                    startRadius: 8,
                    endRadius: 140 * scale
                )
            )

        }
        .accessibilityHidden(true)
    }

    private var layoutAnchors: (primary: UnitPoint, secondary: UnitPoint, tertiary: UnitPoint, core: UnitPoint, trailing: UnitPoint) {
        switch layout {
        case .metricDefault:
            return (
                UnitPoint(x: 0.08, y: 0.96),
                UnitPoint(x: 0.52, y: 1.02),
                UnitPoint(x: 0.22, y: 0.88),
                UnitPoint(x: 0.12, y: 0.94),
                .topTrailing
            )
        case .recordSheetSection:
            return (
                UnitPoint(x: 0.92, y: 0.96),
                UnitPoint(x: 0.48, y: 1.02),
                UnitPoint(x: 0.78, y: 0.88),
                UnitPoint(x: 0.88, y: 0.94),
                .topLeading
            )
        }
    }

    private var primaryGlow: Color {
        switch palette {
        case .spending:
            return AppTheme.actionBlue
        case .emotion, .spectrum:
            return AppTheme.accentInsight
        }
    }

    private var trailingAccent: Color {
        switch palette {
        case .spectrum:
            return AppTheme.accentWarning
        case .spending, .emotion:
            return AppTheme.accentInsight
        }
    }

    private var isDark: Bool { colorScheme == .dark }

    private var primaryWashOpacity: Double {
        switch palette {
        case .spectrum:
            return isDark ? 0.28 : 0.16
        case .spending, .emotion:
            return isDark ? 0.34 : 0.22
        }
    }

    private var primaryWashMidOpacity: Double { primaryWashOpacity * 0.55 }
    private var primaryWashOuterOpacity: Double {
        guard layout == .recordSheetSection else { return primaryWashOpacity * 0.24 }
        return primaryWashOpacity * (isDark ? 0.30 : 0.26)
    }

    private var secondaryWashOpacity: Double {
        switch palette {
        case .spectrum:
            return isDark ? 0.22 : 0.14
        case .spending, .emotion:
            return isDark ? 0.26 : 0.16
        }
    }

    private var secondaryWashMidOpacity: Double { secondaryWashOpacity * 0.48 }

    private var tertiaryWashOpacity: Double { isDark ? 0.16 : 0.10 }
    private var coreWashOpacity: Double { isDark ? 0.20 : 0.12 }

    private var trailingAccentOpacity: Double {
        switch (palette, layout) {
        case (_, .recordSheetSection):
            return isDark ? 0.11 : 0.085
        case (.spectrum, _):
            return isDark ? 0.09 : 0.045
        case (.spending, _), (.emotion, _):
            return isDark ? 0.10 : 0.05
        }
    }

    private var recordAmbientTopLeadingOpacity: Double { isDark ? 0.042 : 0.024 }
    private var recordAmbientMidOpacity: Double { isDark ? 0.03 : 0.016 }
    private var recordAmbientBottomTrailingOpacity: Double { isDark ? 0.038 : 0.021 }
    private var recordAmbientCenterOpacity: Double { isDark ? 0.048 : 0.028 }
}

enum DashboardWatercolorPalette {
    /// Bills list: action blue washes.
    case spending
    /// Emotion review: insight purple primary, still shares secondary teal mist.
    case emotion
    /// Mood spectrum guide: insight purple + teal mist + faint warm highlight.
    case spectrum
}
