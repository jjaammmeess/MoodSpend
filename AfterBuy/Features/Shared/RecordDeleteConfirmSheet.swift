import SwiftData
import SwiftUI

// MARK: - Record delete confirmation

struct RecordDeleteConfirmSheet: View {
    @EnvironmentObject private var localization: LocalizationManager

    let record: TransactionRecord
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        AppDestructiveConfirmSheet(
            title: localization.text(.recordDetailDeleteConfirmTitle),
            message: localization.text(.recordDetailDeleteConfirmMessage),
            systemImage: "trash.fill",
            confirmTitle: localization.text(.commonDelete),
            cancelTitle: localization.text(.commonCancel),
            onConfirm: onDelete,
            onCancel: onCancel
        ) {
            recordPreviewCard
        }
    }

    private var recordPreviewCard: some View {
        HStack(alignment: .center, spacing: 12) {
            CategoryIconBadge(
                categoryKey: record.categoryKey,
                iconSymbolOverride: record.categoryIconSymbolRaw,
                backgroundColor: record.emotionColor,
                size: 40,
                cornerRadius: 11,
                iconSize: 16
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(displayCategory)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Text(AppFormatter.dayTimeString(from: record.createdAt, locale: localization.locale))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text(amountText)
                    .font(.system(size: 17, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(record.type == .expense ? AppTheme.textPrimary : AppTheme.actionBlue)

                EmotionTagCapsule(title: displayEmotion, record: record)
            }
        }
        .padding(14)
        .background {
            RecordPreviewCardBackground(record: record)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.metricDashboardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.metricDashboardCornerRadius, style: .continuous)
                .stroke(AppTheme.border.opacity(0.45), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(recordPreviewAccessibilityLabel)
    }

    private var amountText: String {
        let sign = record.type == .expense ? "-" : "+"
        return "\(sign)\(AppFormatter.moneyString(from: record.amount, locale: localization.locale))"
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

    private var recordPreviewAccessibilityLabel: String {
        "\(displayCategory), \(amountText), \(displayEmotion)"
    }
}

// MARK: - Presentation helper

extension View {
    /// Presents the styled delete confirmation sheet for a pending record.
    func recordDeleteConfirmation(
        item: Binding<TransactionRecord?>,
        onDeleted: (() -> Void)? = nil
    ) -> some View {
        modifier(RecordDeleteConfirmationModifier(item: item, onDeleted: onDeleted))
    }
}

private struct RecordDeleteConfirmationModifier: ViewModifier {
    @Binding var item: TransactionRecord?
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var notificationStore: NotificationCenterStore

    var onDeleted: (() -> Void)?

    func body(content: Content) -> some View {
        content.sheet(item: $item, onDismiss: { item = nil }) { record in
            RecordDeleteConfirmSheet(
                record: record,
                onDelete: {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        RetrospectiveReviewService.deleteRecord(
                            record,
                            modelContext: modelContext,
                            notificationStore: notificationStore
                        )
                    }
                    onDeleted?()
                    item = nil
                },
                onCancel: {
                    item = nil
                }
            )
            .environmentObject(localization)
            .appDestructiveConfirmSheetStyle(height: 388)
        }
    }
}
