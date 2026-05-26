import SwiftUI

struct BillListCategorySpendChip: Identifiable {
    let id: String
    let title: String
    let percent: Int
    let systemImage: String
    let iconTint: Color
}

struct BillListCategoryCapsuleRow: View {
    let allChipTitle: String
    let chips: [BillListCategorySpendChip]
    /// Single-select on the list row; parent may still hold multi-select from the filter sheet.
    @Binding var selectedCategoryKey: String?

    private let selectedFill = Color(hex: "3F6F76")

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                allCategoryCapsule
                ForEach(chips) { chip in
                    categoryCapsule(chip)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.pageBackground)
    }

    private var allCategoryCapsule: some View {
        let isSelected = selectedCategoryKey == nil
        return Button {
            selectedCategoryKey = nil
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : AppTheme.textSecondary)
                Text(allChipTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : AppTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? selectedFill : Color.primary.opacity(0.03))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .accessibilityLabel(allChipTitle)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func categoryCapsule(_ chip: BillListCategorySpendChip) -> some View {
        let isSelected = selectedCategoryKey == chip.id
        return Button {
            if isSelected {
                selectedCategoryKey = nil
            } else {
                selectedCategoryKey = chip.id
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: chip.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : chip.iconTint)
                Text(chip.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text("\(chip.percent)%")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(isSelected ? Color.white : AppTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? selectedFill : Color.primary.opacity(0.03))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
