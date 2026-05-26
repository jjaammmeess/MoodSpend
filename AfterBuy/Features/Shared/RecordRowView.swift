import SwiftUI

struct RecordRowView: View {
    private static let iconColumnWidth: CGFloat = 36
    private static let iconTextSpacing: CGFloat = 12
    static var separatorLeadingInset: CGFloat { iconColumnWidth + iconTextSpacing }

    @EnvironmentObject private var localization: LocalizationManager
    let record: TransactionRecord
    var showsBottomSeparator: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            rowContent
                .padding(.vertical, 12)

            if showsBottomSeparator {
                Rectangle()
                    .fill(Color.primary.opacity(0.05))
                    .frame(height: 1)
                    .padding(.leading, Self.separatorLeadingInset)
            }
        }
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: Self.iconTextSpacing) {
            CategoryIconBadge(
                categoryKey: record.categoryKey,
                iconSymbolOverride: record.categoryIconSymbolRaw,
                backgroundColor: record.emotionColor,
                size: Self.iconColumnWidth,
                cornerRadius: 10,
                iconSize: 15
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(displayCategory)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)

                HStack(spacing: 5) {
                    Text(AppFormatter.dayTimeString(from: record.createdAt, locale: localization.locale))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary)
                        .opacity(0.65)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    if RecordAttachmentIndicators.hasContent(record) {
                        RecordAttachmentIndicators(record: record)
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text(amountText)
                    .font(.system(size: 18, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(record.type == .expense ? AppTheme.textPrimary : AppTheme.actionBlue)

                EmotionTagCapsule(
                    title: displayEmotion,
                    record: record
                )
            }
        }
    }

    private var amountText: String {
        let sign = record.type == .expense ? "-" : "+"
        let money = AppFormatter.moneyString(from: record.amount, locale: localization.locale)
        return "\(sign)\(money)"
    }

    private var displayCategory: String {
        if let key = LKey(rawValue: record.categoryKey) {
            return localization.text(key)
        }
        return record.safeCategoryName
    }

    private var displayEmotion: String {
        if let preset = EmotionTag.from(raw: record.emotionRaw) {
            return localization.text(preset.key)
        }
        return record.safeEmotionName
    }

}
