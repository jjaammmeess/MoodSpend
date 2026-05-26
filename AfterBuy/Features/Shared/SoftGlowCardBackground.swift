import SwiftUI

enum SoftGlowCardIntensity {
    /// Home mood reflection dialogue — slightly stronger glow.
    case dialogue
    /// Record detail summary — softer, read-first.
    case recordSummary
}

struct SoftGlowCardBackground: View {
    let glowTint: Color
    var cornerRadius: CGFloat = AppTheme.moodReflectionCornerRadius
    var intensity: SoftGlowCardIntensity = .dialogue

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(AppTheme.moodReflectionFill)

            shape.fill(
                RadialGradient(
                    colors: [
                        glowTint.opacity(primaryGlowOpacity),
                        glowTint.opacity(primaryGlowMidOpacity),
                        glowTint.opacity(primaryGlowOuterOpacity),
                        .clear,
                    ],
                    center: UnitPoint(x: 0.06, y: 0.94),
                    startRadius: 0,
                    endRadius: primaryGlowEndRadius
                )
            )

            if showsCoreGlow {
                shape.fill(
                    RadialGradient(
                        colors: [
                            glowTint.opacity(primaryCoreGlowOpacity),
                            glowTint.opacity(primaryCoreGlowOpacity * 0.45),
                            .clear,
                        ],
                        center: UnitPoint(x: 0.1, y: 0.9),
                        startRadius: 0,
                        endRadius: primaryCoreGlowEndRadius
                    )
                )
            }

            shape.fill(
                RadialGradient(
                    colors: [
                        AppTheme.accentInsight.opacity(secondaryGlowOpacity),
                        .clear,
                    ],
                    center: .topTrailing,
                    startRadius: 8,
                    endRadius: 150
                )
            )

            shape.stroke(AppTheme.border.opacity(strokeOpacity), lineWidth: 0.5)
        }
        .accessibilityHidden(true)
    }

    private var showsCoreGlow: Bool {
        true
    }

    private var primaryGlowOpacity: Double {
        switch intensity {
        case .dialogue:
            return colorScheme == .dark ? 0.42 : 0.30
        case .recordSummary:
            return colorScheme == .dark ? 0.38 : 0.24
        }
    }

    private var primaryGlowMidOpacity: Double {
        primaryGlowOpacity * 0.55
    }

    private var primaryGlowOuterOpacity: Double {
        primaryGlowOpacity * 0.28
    }

    private var primaryGlowEndRadius: CGFloat {
        128
    }

    private var primaryCoreGlowOpacity: Double {
        switch intensity {
        case .dialogue:
            return colorScheme == .dark ? 0.24 : 0.14
        case .recordSummary:
            return colorScheme == .dark ? 0.20 : 0.12
        }
    }

    private var primaryCoreGlowEndRadius: CGFloat {
        82
    }

    private var secondaryGlowOpacity: Double {
        switch intensity {
        case .dialogue:
            return colorScheme == .dark ? 0.12 : 0.06
        case .recordSummary:
            return colorScheme == .dark ? 0.10 : 0.05
        }
    }

    private var strokeOpacity: Double {
        colorScheme == .dark ? 0.28 : 0.32
    }
}

extension View {
    func softGlowCardStyle(
        glowTint: Color,
        cornerRadius: CGFloat = AppTheme.moodReflectionCornerRadius,
        intensity: SoftGlowCardIntensity = .dialogue,
        padding: CGFloat = AppTheme.cardPadding
    ) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                SoftGlowCardBackground(
                    glowTint: glowTint,
                    cornerRadius: cornerRadius,
                    intensity: intensity
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
