import SwiftUI
import UIKit

/// Home-dashboard bucket chips for custom mood「统计归类」.
struct EmotionBucketTagPicker: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Binding var selection: EmotionBucket

    @State private var containerWidth: CGFloat = 0

    private let tagSpacing: CGFloat = 8
    private let rowSpacing: CGFloat = 8
    private let tagVerticalPadding: CGFloat = 9
    private let tagHorizontalPadding: CGFloat = 14
    /// Extra slack so wrap decisions match rendered pill width (Dynamic Type / stroke).
    private let widthFudge: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(Array(bucketRows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: tagSpacing) {
                    ForEach(row, id: \.self) { bucket in
                        tagButton(for: bucket)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: contentMinHeight, alignment: .leading)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { updateContainerWidth(proxy.size.width) }
                    .onChange(of: proxy.size.width) { _, newValue in
                        updateContainerWidth(newValue)
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selection)
        .animation(.easeInOut(duration: 0.2), value: bucketRows.count)
    }

    /// Before width is known, assume wrapped (2 rows) so nothing is clipped on first paint.
    private var bucketRows: [[EmotionBucket]] {
        let all = Array(EmotionBucket.allCases)
        guard containerWidth > 1, fitsSingleRow(buckets: all, width: containerWidth) else {
            return [[.effective, .emotional], [.necessary]]
        }
        return [all]
    }

    private var contentMinHeight: CGFloat {
        let rowCount = bucketRows.count
        let lineHeight = tagLineHeight
        return CGFloat(rowCount) * lineHeight + CGFloat(max(0, rowCount - 1)) * rowSpacing
    }

    private var tagLineHeight: CGFloat {
        let font = Self.tagUIFont(selected: true)
        return ceil(font.lineHeight) + tagVerticalPadding * 2
    }

    private func fitsSingleRow(buckets: [EmotionBucket], width: CGFloat) -> Bool {
        var total: CGFloat = 0
        for (index, bucket) in buckets.enumerated() {
            if index > 0 { total += tagSpacing }
            total += tagWidth(for: bucket)
        }
        return total + widthFudge <= width
    }

    private func tagWidth(for bucket: EmotionBucket) -> CGFloat {
        Self.measuredTagWidth(
            title: localization.text(Self.titleKey(for: bucket)),
            horizontalPadding: tagHorizontalPadding
        )
    }

    private func updateContainerWidth(_ width: CGFloat) {
        guard width > 0.5, abs(containerWidth - width) > 0.5 else { return }
        containerWidth = width
    }

    private func tagButton(for bucket: EmotionBucket) -> some View {
        let isSelected = selection == bucket
        let accent = Self.accentColor(for: bucket)
        let title = localization.text(Self.titleKey(for: bucket))

        return Button {
            selection = bucket
        } label: {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? accent : AppTheme.textSecondary)
                .lineLimit(1)
                .padding(.horizontal, tagHorizontalPadding)
                .padding(.vertical, tagVerticalPadding)
                .background {
                    Capsule()
                        .fill(isSelected ? accent.opacity(0.2) : AppTheme.divider.opacity(0.38))
                }
                .overlay {
                    Capsule()
                        .strokeBorder(
                            isSelected ? accent.opacity(0.48) : AppTheme.border.opacity(0.72),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(title)
    }

    static func measuredTagWidth(title: String, horizontalPadding: CGFloat) -> CGFloat {
        let font = tagUIFont(selected: true)
        let textWidth = (title as NSString).size(withAttributes: [.font: font]).width
        return ceil(textWidth) + horizontalPadding * 2
    }

    static func tagUIFont(selected: Bool) -> UIFont {
        let metrics = UIFontMetrics(forTextStyle: .subheadline)
        let base = UIFont.systemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize,
            weight: selected ? .semibold : .medium
        )
        return metrics.scaledFont(for: base)
    }

    static func accentColor(for bucket: EmotionBucket) -> Color {
        switch bucket {
        case .effective: AppTheme.accentSecondary
        case .emotional: AppTheme.accentRisk
        case .necessary: AppTheme.accentWarning
        }
    }

    private static func titleKey(for bucket: EmotionBucket) -> LKey {
        switch bucket {
        case .effective: .homeEffectiveSpend
        case .emotional: .homeEmotionalSpend
        case .necessary: .homeNecessarySpend
        }
    }
}
