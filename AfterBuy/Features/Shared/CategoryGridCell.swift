import SwiftUI

/// Layout for 4 fixed columns: scales orb, type, and gaps when grid width is narrow (e.g. iPhone SE).
struct CategoryGridLayoutMetrics: Equatable {
    /// Selected category / emotion orb scales from `orbSize` up toward this factor; clamped to column `slot` so neighbors are not overlapped.
    static let selectedOrbScale: CGFloat = 1.35

    let orbSize: CGFloat
    /// Fixed layout box for the category or emotion orb (>= `orbSize`); selected orb grows to this without exceeding the column slot.
    let orbLayoutCap: CGFloat
    let iconFontSize: CGFloat
    let titleFontSize: CGFloat
    let columnSpacing: CGFloat
    let rowSpacing: CGFloat
    let iconTextSpacing: CGFloat
    let cellVerticalPadding: CGFloat
    let ringWidthSelected: CGFloat
    let ringWidthNormal: CGFloat

    /// `width` is the inner width of the 4-column grid (after horizontal padding).
    static func forGridWidth(_ width: CGFloat) -> CategoryGridLayoutMetrics {
        guard width > 8 else { return .defaultLargePhone }
        let colGap: CGFloat = width < 304 ? 6 : 10
        let slot = (width - colGap * 3) / 4
        let orbUncapped = min(52, max(34, slot - 4))
        let orb = min(orbUncapped, slot)
        let orbLayoutCap = min(orb * Self.selectedOrbScale, slot)
        let s = orb / 52
        return CategoryGridLayoutMetrics(
            orbSize: orb,
            orbLayoutCap: orbLayoutCap,
            iconFontSize: max(14, 22 * s),
            titleFontSize: max(9, min(11, 11 * s)),
            columnSpacing: colGap,
            rowSpacing: max(7, 12 * s),
            iconTextSpacing: max(4, 8 * s),
            cellVerticalPadding: max(3, 6 * s),
            ringWidthSelected: max(1.5, 2 * s),
            ringWidthNormal: max(0.75, 1 * s)
        )
    }

    /// Fallback before first layout measurement (≈ regular iPhone content width).
    static let defaultLargePhone = CategoryGridLayoutMetrics(
        orbSize: 52,
        orbLayoutCap: min(52 * selectedOrbScale, 80),
        iconFontSize: 22,
        titleFontSize: 11,
        columnSpacing: 10,
        rowSpacing: 12,
        iconTextSpacing: 8,
        cellVerticalPadding: 6,
        ringWidthSelected: 2,
        ringWidthNormal: 1
    )
}

/// Vertical category picker: icon in a circle, label below; selected state tints icon and ring.
struct CategoryGridCell: View {
    let title: String
    let categoryKey: String
    /// When set (custom categories), overrides `CategoryVisualStyle.iconName`.
    var iconSymbolOverride: String? = nil
    let isSelected: Bool
    var metrics: CategoryGridLayoutMetrics = .defaultLargePhone
    let action: () -> Void

    private var accent: Color {
        CategoryVisualStyle.selectionAccentColor(for: categoryKey)
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

    private var iconPointSize: CGFloat {
        max(14, metrics.iconFontSize * orbScaleRatio)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: metrics.iconTextSpacing) {
                ZStack {
                    Circle()
                        .fill(isSelected ? accent.opacity(0.14) : AppTheme.divider.opacity(0.4))
                        .frame(width: orbDiameter, height: orbDiameter)
                    Circle()
                        .strokeBorder(
                            isSelected ? accent : AppTheme.border.opacity(0.72),
                            lineWidth: isSelected ? ringWidthSelected : ringWidthNormal
                        )
                        .frame(width: orbDiameter, height: orbDiameter)
                    Image(systemName: iconSymbolOverride ?? CategoryVisualStyle.iconName(for: categoryKey))
                        .font(.system(size: iconPointSize, weight: .semibold))
                        .foregroundStyle(CategoryVisualStyle.gridIconForeground(isSelected: isSelected, accent: accent))
                        .symbolRenderingMode(.monochrome)
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
        CategoryGridCell(
            title: "餐饮",
            categoryKey: LKey.categoryFood.rawValue,
            isSelected: true,
            action: {}
        )
        CategoryGridCell(
            title: "交通",
            categoryKey: LKey.categoryTransport.rawValue,
            isSelected: false,
            action: {}
        )
    }
    .padding()
}
