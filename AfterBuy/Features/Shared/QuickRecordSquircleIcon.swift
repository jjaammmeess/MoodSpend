import SwiftUI

enum QuickRecordSquircleMetrics {
    static let tabBarSquircleSize: CGFloat = 48
    static let tabBarHitSide: CGFloat = 56
    static let tabBarCornerRadius: CGFloat = 14
    static let tabBarPlusSize: CGFloat = 26

    static let onboardingSquircleSize: CGFloat = 76
    static let onboardingPlusSize: CGFloat = 41

    static func cornerRadius(forSquircleSize size: CGFloat) -> CGFloat {
        size * (tabBarCornerRadius / tabBarSquircleSize)
    }

    static func plusSize(forSquircleSize size: CGFloat) -> CGFloat {
        size * (tabBarPlusSize / tabBarSquircleSize)
    }
}

/// Tab-bar and onboarding hero glyph for quick record (dark squircle + white plus).
struct QuickRecordSquircleIcon: View {
    let squircleSize: CGFloat
    var hitSide: CGFloat?
    var showsAmbientGlow: Bool = false

    private var cornerRadius: CGFloat {
        QuickRecordSquircleMetrics.cornerRadius(forSquircleSize: squircleSize)
    }

    private var plusSize: CGFloat {
        QuickRecordSquircleMetrics.plusSize(forSquircleSize: squircleSize)
    }

    private var frameSide: CGFloat {
        hitSide ?? squircleSize
    }

    var body: some View {
        ZStack {
            if showsAmbientGlow {
                RoundedRectangle(cornerRadius: cornerRadius + 6, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: squircleSize + 28, height: squircleSize + 28)
                    .blur(radius: 20)
            }

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.fabSquircleGradientStart,
                            AppTheme.fabSquircleGradientEnd
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: squircleSize, height: squircleSize)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(AppTheme.fabSquircleStroke, lineWidth: 1)
                }
                .shadow(color: AppTheme.fabSquircleDropShadow, radius: 12, x: 0, y: 8)
                .shadow(color: AppTheme.fabSquircleInnerHighlight, radius: 2, x: 0, y: -1)

            Image(systemName: "plus")
                .font(.system(size: plusSize, weight: .medium))
                .foregroundStyle(AppTheme.fabSquircleIcon)
        }
        .frame(width: frameSide, height: frameSide)
        .accessibilityHidden(true)
    }
}

struct QuickRecordSquircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
