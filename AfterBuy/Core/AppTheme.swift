import SwiftUI
import UIKit

enum AppTheme {
    static let pageBackground = Color.dynamic(lightHex: "F5F8F8", darkHex: "12171A")
    static let cardBackground = Color.dynamic(lightHex: "FFFFFF", darkHex: "1A2024")
    static let textPrimary = Color.dynamic(lightHex: "253035", darkHex: "EEF2F4")
    static let textSecondary = Color.dynamic(lightHex: "5E6A71", darkHex: "A9B2B8")
    static let border = Color.dynamic(lightHex: "D6DFE3", darkHex: "2B343A")
    static let divider = Color.dynamic(lightHex: "EAF0F2", darkHex: "283037")
    static let actionBlue = Color.dynamic(lightHex: "3F6F76", darkHex: "69B7CE")
    static let accentSecondary = Color.dynamic(lightHex: "69B7CE", darkHex: "7FC4D8")
    static let accentWarning = Color.dynamic(lightHex: "F4CE4B", darkHex: "E0BD4E")
    static let accentRisk = Color.dynamic(lightHex: "C65840", darkHex: "D57663")
    static let accentInsight = Color.dynamic(lightHex: "62496F", darkHex: "8C76A1")
    static let cornerRadius: CGFloat = 8
    static let smallCornerRadius: CGFloat = 6
    static let cardPadding: CGFloat = 16
    static let cardShadow = Color.dynamic(
        lightHex: "3F6F76",
        darkHex: "000000",
        lightAlpha: 0.09,
        darkAlpha: 0.2
    )

    // MARK: - Tab bar floating “+” (squircle)
    /// Gradient start for the quick-record squircle (dark fill, distinct from `actionBlue`).
    static let fabSquircleGradientStart = Color.dynamic(lightHex: "1C2838", darkHex: "1E2630")
    /// Gradient end (bottom-trailing).
    static let fabSquircleGradientEnd = Color.dynamic(lightHex: "0A0E14", darkHex: "080C12")
    /// Subtle rim on the squircle.
    static let fabSquircleStroke = Color.dynamic(
        lightHex: "FFFFFF",
        darkHex: "FFFFFF",
        lightAlpha: 0.2,
        darkAlpha: 0.14
    )
    /// Primary drop shadow under the squircle.
    static let fabSquircleDropShadow = Color.dynamic(
        lightHex: "000000",
        darkHex: "000000",
        lightAlpha: 0.32,
        darkAlpha: 0.42
    )
    /// Tight highlight above the squircle.
    static let fabSquircleInnerHighlight = Color.dynamic(
        lightHex: "FFFFFF",
        darkHex: "FFFFFF",
        lightAlpha: 0.05,
        darkAlpha: 0.06
    )
    /// `+` symbol on the squircle.
    static let fabSquircleIcon = Color.dynamic(lightHex: "FFFFFF", darkHex: "F5F8F8")

    // MARK: - Mine (settings) surface
    /// Settings cards: softer corners than generic `cornerRadius`.
    static let mineCardCornerRadius: CGFloat = 16
    /// Softer elevation than `cardShadow` for stacked settings cards.
    static let mineCardShadowColor = Color.dynamic(
        lightHex: "1C3036",
        darkHex: "000000",
        lightAlpha: 0.07,
        darkAlpha: 0.32
    )
    static let mineIconWellSize: CGFloat = 40
    static let mineIconWellCornerRadius: CGFloat = 11
    /// Hero header: soft cool wash (light) / subtle cool glow (dark).
    static let mineHeroWashA = Color.dynamic(lightHex: "B8E0EB", darkHex: "3A5A68")
    static let mineHeroWashB = Color.dynamic(lightHex: "D8D2F0", darkHex: "4A4558")
    /// Profile edit badge on avatar.
    static let mineHeroEditBadgeFill = Color.dynamic(lightHex: "1C2838", darkHex: "2A3842")
    /// Dark promo-style strip (reference “Upgrade” card).
    static let mineHeroStripGradientStart = Color.dynamic(lightHex: "1A2C36", darkHex: "121A22")
    static let mineHeroStripGradientEnd = Color.dynamic(lightHex: "2A4550", darkHex: "1E2A32")
    /// “Log out”-style pill for destructive secondary actions.
    static let mineDestructivePillFill = Color.dynamic(lightHex: "FCE8EA", darkHex: "3A2528")

    // MARK: - Home mood reflection dialogue card
    static let moodReflectionCornerRadius: CGFloat = 16
    static let moodReflectionFill = Color.dynamic(lightHex: "F9FBFC", darkHex: "1C2328")
    static let moodReflectionIconWellFill = Color.dynamic(
        lightHex: "FFFFFF",
        darkHex: "FFFFFF",
        lightAlpha: 1.0,
        darkAlpha: 0.12
    )

    // MARK: - Metric dashboard cards (bills list, emotion review)
    static let metricDashboardCornerRadius: CGFloat = 16
    /// Same family as `moodReflectionFill` — lifts off `pageBackground`.
    static let metricDashboardFill = Color.dynamic(lightHex: "F9FBFC", darkHex: "1C2328")
    static let metricDashboardPadding: CGFloat = 16
    static let metricDashboardRowSpacing: CGFloat = 6
    /// Reserved row height when a delta capsule is absent (keeps columns aligned).
    static let metricDashboardDeltaRowHeight: CGFloat = 22

    // MARK: - Filled tag / chip label contrast

    /// Label on a solid emotion-color pill. Uses fixed dark/light ink — not `textPrimary` (which is light in dark mode).
    static func labelOnFilledSwatch(hex: String, lightThreshold: Double = 0.52) -> Color {
        guard let luminance = hexRelativeLuminance(hex) else { return .white }
        return luminance > lightThreshold ? Color(hex: "253035") : .white
    }

    /// Label on a tinted emotion capsule (`emotionColor` at ~22% opacity).
    /// Light mode: light swatches → darkened ink; dark swatches → saturated brand color.
    /// Dark mode: lightened brand ink (bright swatches use a stronger lighten mix; never dark ink on tinted capsules).
    static func labelOnTintedSwatch(
        hex: String,
        colorScheme: ColorScheme,
        lightThreshold: Double = 0.52,
        darkenFactor: Double = 0.42,
        darkModeLightenMix: Double = 0.38,
        darkModeBrightSwatchThreshold: Double = 0.72,
        darkModeBrightSwatchLightenMix: Double = 0.48
    ) -> Color {
        guard let normalized = normalizedHex(hex) else {
            return colorScheme == .dark ? Color(hex: "EEF2F4") : Color(hex: "253035")
        }
        guard let luminance = hexRelativeLuminance(normalized) else {
            return colorScheme == .dark ? Color(hex: "EEF2F4") : Color(hex: "253035")
        }

        switch colorScheme {
        case .dark:
            let mix = luminance > darkModeBrightSwatchThreshold
                ? darkModeBrightSwatchLightenMix
                : darkModeLightenMix
            return lightenedColor(hex: normalized, mixTowardWhite: mix)
                ?? Color(hex: "EEF2F4")
        default:
            if luminance > lightThreshold {
                return darkenedColor(hex: normalized, factor: darkenFactor) ?? Color(hex: "253035")
            }
            return Color(hex: normalized)
        }
    }

    /// Tint opacity for `CategoryIconBadge` — stronger in dark mode so the emotion-tinted well reads on `pageBackground`.
    static func categoryIconBadgeBackgroundOpacity(
        for colorScheme: ColorScheme,
        baseOpacity: Double
    ) -> Double {
        colorScheme == .dark ? max(baseOpacity, 0.22) : baseOpacity
    }

    /// Tint opacity for `EmotionTagCapsule` background — stronger in dark mode; brighter swatches get a bit more fill.
    static func emotionTagCapsuleTintOpacity(for colorScheme: ColorScheme, hex: String? = nil) -> Double {
        switch colorScheme {
        case .dark:
            if let hex,
               let luminance = hexRelativeLuminance(hex),
               luminance > 0.72 {
                return 0.36
            }
            return 0.28
        default:
            return 0.22
        }
    }

    /// Legacy constant; prefer `emotionTagCapsuleTintOpacity(for:)`.
    static let emotionTagCapsuleTintOpacity: Double = 0.22

    static func hexRelativeLuminance(_ hex: String) -> Double? {
        guard let normalized = normalizedHex(hex),
              let value = UInt64(normalized, radix: 16)
        else { return nil }
        let r = Double((value >> 16) & 0xFF)
        let g = Double((value >> 8) & 0xFF)
        let b = Double(value & 0xFF)
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255
    }

    static func darkenedColor(hex: String, factor: Double) -> Color? {
        guard let normalized = normalizedHex(hex),
              let value = UInt64(normalized, radix: 16)
        else { return nil }
        let clamp: (Double) -> UInt64 = { channel in
            UInt64(max(0, min(255, (channel * factor).rounded())))
        }
        let r = clamp(Double((value >> 16) & 0xFF))
        let g = clamp(Double((value >> 8) & 0xFF))
        let b = clamp(Double(value & 0xFF))
        return Color(hex: String(format: "%02X%02X%02X", r, g, b))
    }

    static func lightenedColor(hex: String, mixTowardWhite: Double) -> Color? {
        guard let normalized = normalizedHex(hex),
              let value = UInt64(normalized, radix: 16)
        else { return nil }
        let mix: (Double) -> UInt64 = { channel in
            UInt64(max(0, min(255, (channel + (255 - channel) * mixTowardWhite).rounded())))
        }
        let r = mix(Double((value >> 16) & 0xFF))
        let g = mix(Double((value >> 8) & 0xFF))
        let b = mix(Double(value & 0xFF))
        return Color(hex: String(format: "%02X%02X%02X", r, g, b))
    }

    private static func normalizedHex(_ hex: String) -> String? {
        let clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard clean.count == 6 else { return nil }
        return clean.uppercased()
    }
}

extension Color {
    static func dynamic(
        lightHex: String,
        darkHex: String,
        lightAlpha: Double = 1.0,
        darkAlpha: Double = 1.0
    ) -> Color {
        Color(
            UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(hex: darkHex, alpha: darkAlpha)
                }
                return UIColor(hex: lightHex, alpha: lightAlpha)
            }
        )
    }

    init(hex: String, alpha: Double = 1.0) {
        let clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let red = Double((int >> 16) & 0xFF) / 255.0
        let green = Double((int >> 8) & 0xFF) / 255.0
        let blue = Double(int & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension View {
    func appCardStyle() -> some View {
        self
            .padding(AppTheme.cardPadding)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: AppTheme.cardShadow, radius: 6, x: 0, y: 2)
    }

    func appChipStyle(selected: Bool) -> some View {
        self
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(selected ? AppTheme.actionBlue.opacity(0.2) : AppTheme.cardBackground)
            .foregroundStyle(selected ? AppTheme.actionBlue : AppTheme.textSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius)
                    .stroke(selected ? AppTheme.actionBlue.opacity(0.35) : AppTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius))
    }

    /// Shared period capsules (账单列表 / 情绪复盘): high-contrast fill when selected.
    func periodFilterCapsuleStyle(selected: Bool) -> some View {
        self
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(selected ? AppTheme.cardBackground : AppTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selected ? AppTheme.textPrimary : AppTheme.cardBackground)
            .clipShape(Capsule())
            .lineLimit(1)
            .minimumScaleFactor(0.78)
    }

    /// Softer selected state for in-card trend pickers (毛玻璃 / 淡烟熏).
    func softPeriodFilterCapsuleStyle(selected: Bool) -> some View {
        self
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                ZStack {
                    Capsule()
                        .fill(AppTheme.cardBackground)
                    if selected {
                        Capsule()
                            .fill(.ultraThinMaterial)
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                    }
                }
            }
            .clipShape(Capsule())
            .overlay {
                if selected {
                    Capsule()
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.78)
    }

    /// Circular sibling to period capsules: neutral fill, no selected state.
    func periodFilterCircleIconStyle() -> some View {
        self
            .frame(width: 40, height: 40)
            .background(AppTheme.cardBackground)
            .clipShape(Circle())
    }

    /// Hides scroll edge effects on iOS 26+; no-op on iOS 18–25 (API unavailable).
    @ViewBuilder
    func scrollEdgeEffectHiddenIfAvailable(_ hidden: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectHidden(hidden, for: .all)
        } else {
            self
        }
    }

    /// Mine tab grouped rows: white card, soft shadow, light rim (glass-adjacent).
    func mineSettingsCardChrome(
        watercolor palette: DashboardWatercolorPalette? = nil,
        watercolorGlowScale: CGFloat = 1.45
    ) -> some View {
        self
            .background {
                if let palette {
                    DashboardWatercolorBackground(
                        cornerRadius: AppTheme.mineCardCornerRadius,
                        palette: palette,
                        glowExtentScale: watercolorGlowScale
                    )
                } else {
                    AppTheme.cardBackground
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.mineCardCornerRadius, style: .continuous))
            .shadow(color: AppTheme.mineCardShadowColor, radius: 14, x: 0, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.mineCardCornerRadius, style: .continuous)
                    .stroke(AppTheme.border.opacity(0.4), lineWidth: 0.5)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: AppTheme.mineCardCornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.42),
                                Color.white.opacity(0.06),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    .mask(
                        LinearGradient(
                            colors: [.black, .black.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.22)
                        )
                    )
                    .allowsHitTesting(false)
            }
    }
}

private extension UIColor {
    convenience init(hex: String, alpha: Double = 1.0) {
        let clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let red = CGFloat((int >> 16) & 0xFF) / 255.0
        let green = CGFloat((int >> 8) & 0xFF) / 255.0
        let blue = CGFloat(int & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
