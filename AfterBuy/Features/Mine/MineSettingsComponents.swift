import SwiftUI

// MARK: - Shared mine / settings chrome

struct MineSettingsGroupHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(AppTheme.textPrimary.opacity(0.92))
            .padding(.leading, 2)
    }
}

struct MineSettingsCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .mineSettingsCardChrome()
    }
}

/// Footnote-style note with soft watercolor wash (analysis insight / about brand family).
struct MineSettingsTipCard: View {
    let text: String
    var palette: DashboardWatercolorPalette = .spending

    private let cornerRadius: CGFloat = 12

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(AppTheme.textSecondary)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                DashboardWatercolorBackground(
                    cornerRadius: cornerRadius,
                    palette: palette,
                    layout: .metricDefault
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.border.opacity(0.28), lineWidth: 0.5)
            }
    }
}

struct MineSettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.divider.opacity(0.95))
            .frame(height: 0.5)
            .padding(.leading, 16 + AppTheme.mineIconWellSize + 12)
    }
}

struct MineSettingsIconWell: View {
    let systemIcon: String

    var body: some View {
        Image(systemName: systemIcon)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(MineSettingsIconStyle.tint(for: systemIcon))
            .frame(width: AppTheme.mineIconWellSize, height: AppTheme.mineIconWellSize)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.mineIconWellCornerRadius, style: .continuous)
                    .fill(MineSettingsIconStyle.fill(for: systemIcon))
            )
    }
}

enum MineSettingsIconStyle {
    static func fill(for icon: String) -> Color {
        switch icon {
        case "globe", "clock.arrow.circlepath", "arrow.triangle.2.circlepath":
            return AppTheme.accentSecondary.opacity(0.18)
        case "paintpalette", "calendar":
            return AppTheme.accentInsight.opacity(0.16)
        case "bell.badge", "sparkles", "info.circle.fill":
            return AppTheme.accentInsight.opacity(0.14)
        case "exclamationmark.triangle":
            return AppTheme.accentWarning.opacity(0.18)
        case "coloncurrencysign.circle.fill":
            return Color(red: 0.18, green: 0.72, blue: 0.55).opacity(0.18)
        case "externaldrive", "doc.text", "doc.text.fill", "arrow.clockwise.circle", "icloud", "tray.full", "slider.horizontal.3", "book.pages.fill", "envelope.fill", "hand.raised.fill", "square.and.arrow.up.fill", "star.fill", "number.circle.fill":
            return AppTheme.actionBlue.opacity(0.14)
        default:
            return AppTheme.actionBlue.opacity(0.12)
        }
    }

    static func tint(for icon: String) -> Color {
        switch icon {
        case "globe", "clock.arrow.circlepath", "arrow.triangle.2.circlepath":
            return AppTheme.accentSecondary
        case "paintpalette", "calendar":
            return AppTheme.accentInsight
        case "coloncurrencysign.circle.fill":
            return Color(red: 0.12, green: 0.58, blue: 0.44)
        case "externaldrive", "doc.text", "doc.text.fill", "arrow.clockwise.circle", "icloud", "tray.full", "slider.horizontal.3", "book.pages.fill", "envelope.fill", "hand.raised.fill", "square.and.arrow.up.fill", "star.fill", "number.circle.fill":
            return AppTheme.actionBlue
        case "bell.badge", "sparkles", "info.circle.fill":
            return AppTheme.accentInsight
        case "exclamationmark.triangle":
            return AppTheme.accentWarning
        case "trash", "trash.fill":
            return AppTheme.accentRisk
        default:
            return AppTheme.actionBlue
        }
    }
}

struct MineSettingsActionRow: View {
    let icon: String
    let title: String
    var value: String = ""
    var valueColor: Color = AppTheme.textSecondary
    var titleColor: Color = AppTheme.textPrimary
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            MineSettingsIconWell(systemIcon: icon)
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(titleColor)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 15))
                    .foregroundStyle(valueColor)
                    .multilineTextAlignment(.trailing)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.68))
            }
        }
        .frame(minHeight: 58)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

struct MineSettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            MineSettingsIconWell(systemIcon: icon)
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AppTheme.actionBlue)
        }
        .frame(minHeight: 58)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

struct MineRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Explanation tip (soft glow + icon)

struct MineSettingsExplanationTipCard<Content: View>: View {
    let icon: String
    let glowTint: Color
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColors.icon)
                .symbolRenderingMode(colorScheme == .dark ? .monochrome : .hierarchical)
                .frame(width: AppTheme.mineIconWellSize, height: AppTheme.mineIconWellSize)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.mineIconWellCornerRadius, style: .continuous)
                        .fill(iconColors.well)
                )
                .accessibilityHidden(true)

            content()
                .font(.footnote)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .softGlowCardStyle(glowTint: glowTint, intensity: .dialogue, padding: 14)
    }

    private var iconColors: (well: Color, icon: Color) {
        if colorScheme == .dark {
            return (glowTint.opacity(0.28), Color.white.opacity(0.92))
        }
        return (AppTheme.moodReflectionIconWellFill, glowTint)
    }
}
