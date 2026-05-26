import SwiftUI

struct CategoryIconBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    let categoryKey: String
    var iconSymbolOverride: String? = nil
    let backgroundColor: Color
    var size: CGFloat = 42
    var cornerRadius: CGFloat = 12
    var iconSize: CGFloat = 18
    var backgroundOpacity: Double = 0.14

    private var effectiveBackgroundOpacity: Double {
        AppTheme.categoryIconBadgeBackgroundOpacity(for: colorScheme, baseOpacity: backgroundOpacity)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(backgroundColor.opacity(effectiveBackgroundOpacity))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: resolvedIconName)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(
                        CategoryVisualStyle.listBadgeIconForeground(
                            for: categoryKey,
                            colorScheme: colorScheme
                        )
                    )
            )
    }

    private var resolvedIconName: String {
        if let iconSymbolOverride, !iconSymbolOverride.isEmpty {
            return CustomIconCatalog.normalizedCategorySymbol(iconSymbolOverride)
        }
        return CategoryVisualStyle.iconName(for: categoryKey)
    }
}
