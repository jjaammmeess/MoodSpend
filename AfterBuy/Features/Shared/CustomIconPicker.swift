import SwiftUI

/// Single-row or wrapped grid of SF Symbols for custom category / mood pickers.
struct CustomIconPicker: View {
    let symbols: [String]
    @Binding var selection: String
    var columns: Int = 6

    var body: some View {
        let gridItems = Array(repeating: GridItem(.flexible(), spacing: 8), count: columns)
        LazyVGrid(columns: gridItems, spacing: 10) {
            ForEach(symbols, id: \.self) { sym in
                Button {
                    selection = sym
                } label: {
                    Image(systemName: sym)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(selection == sym ? AppTheme.actionBlue : AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selection == sym ? AppTheme.actionBlue.opacity(0.12) : AppTheme.divider.opacity(0.35))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    selection == sym ? AppTheme.actionBlue.opacity(0.45) : AppTheme.border.opacity(0.4),
                                    lineWidth: selection == sym ? 1.5 : 1
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(sym))
                .accessibilityAddTraits(selection == sym ? [.isSelected] : [])
            }
        }
    }
}
