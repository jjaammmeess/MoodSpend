import SwiftUI

/// Emotion picker aligned with **category** grid style: orb + label below; selected state tints icon and ring using `colorHex`.
struct EmotionGridCell: View {
    let title: String
    let iconName: String
    /// When set, shows this bundle image instead of `iconName` SF Symbol.
    var rasterAssetName: String? = nil
    let colorHex: String
    let isSelected: Bool
    var metrics: CategoryGridLayoutMetrics = .defaultLargePhone
    let action: () -> Void

    private var accent: Color {
        let h = colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        return Color(hex: h.isEmpty ? EmotionTag.necessity.colorHex : h)
    }

    private var orbLayoutCap: CGFloat { metrics.orbLayoutCap }

    private var orbDiameter: CGFloat {
        isSelected ? orbLayoutCap : metrics.orbSize
    }

    private var orbScaleRatio: CGFloat { orbDiameter / metrics.orbSize }

    private var ringWidthSelected: CGFloat {
        max(1.5, metrics.ringWidthSelected * orbScaleRatio)
    }

    private var ringWidthNormal: CGFloat {
        max(0.75, metrics.ringWidthNormal * orbScaleRatio)
    }

    private var sfSymbolPointSize: CGFloat {
        max(14, metrics.iconFontSize * orbScaleRatio)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: metrics.iconTextSpacing) {
                ZStack {
                    if let raster = rasterAssetName {
                        Image(raster)
                            .renderingMode(.original)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFill()
                            .frame(width: orbDiameter, height: orbDiameter)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(isSelected ? accent.opacity(0.14) : AppTheme.divider.opacity(0.4))
                            .frame(width: orbDiameter, height: orbDiameter)
                        Image(systemName: iconName)
                            .font(.system(size: sfSymbolPointSize, weight: .semibold))
                            .foregroundStyle(isSelected ? accent : AppTheme.textSecondary)
                            .symbolRenderingMode(.monochrome)
                    }

                    Circle()
                        .strokeBorder(
                            isSelected ? accent : AppTheme.border.opacity(0.72),
                            lineWidth: isSelected ? ringWidthSelected : ringWidthNormal
                        )
                        .frame(width: orbDiameter, height: orbDiameter)
                }
                .frame(width: orbLayoutCap, height: orbLayoutCap)
                .animation(.spring(response: 0.34, dampingFraction: 0.78), value: isSelected)

                Text(title)
                    .font(.system(size: metrics.titleFontSize, weight: isSelected ? .semibold : .medium))
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
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
        EmotionGridCell(
            title: "取悦自己",
            iconName: "sparkles",
            colorHex: EmotionTag.pamper.colorHex,
            isSelected: true,
            action: {}
        )
        EmotionGridCell(
            title: "刚需",
            iconName: "checkmark.seal",
            colorHex: EmotionTag.necessity.colorHex,
            isSelected: false,
            action: {}
        )
    }
    .padding()
}
