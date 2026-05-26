import SwiftData
import SwiftUI

/// Standalone sheet wrapper (e.g. from Analysis tab notifications).
struct RecordRetrospectiveSheet: View {
    let record: TransactionRecord

    var body: some View {
        NavigationStack {
            RecordRetrospectiveForm(record: record)
        }
    }
}

/// Retrospective form — push inside an existing `NavigationStack` or embed in `RecordRetrospectiveSheet`.
struct RecordRetrospectiveForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var notificationStore: NotificationCenterStore

    let record: TransactionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(localization.text(.retrospectivePrompt))
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            VStack(alignment: .leading, spacing: 10) {
                Text(record.resolvedCategoryForRetrospectiveDisplay(localizedText: localization.text))
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                if !record.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(record.note.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(displayEmotion)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)

                Text(AppFormatter.moneyString(from: record.amount, locale: localization.locale))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .monospacedDigit()

                Text(AppFormatter.dayString(from: record.createdAt, locale: localization.locale))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))

            VStack(spacing: 12) {
                worthButton(.worthIt, .retrospectiveWorthIt, AppTheme.accentSecondary)
                worthButton(.neutral, .retrospectiveNeutral, AppTheme.textSecondary)
                worthButton(.regret, .retrospectiveRegret, AppTheme.accentRisk)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle(localization.text(.retrospectiveTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(localization.text(.commonCancel)) {
                    dismiss()
                }
            }
        }
    }

    private var displayEmotion: String {
        if let preset = EmotionTag.from(raw: record.emotionRaw) {
            return localization.text(preset.key)
        }
        return record.safeEmotionName
    }

    private func worthButton(_ worth: RetrospectiveWorth, _ key: LKey, _ tint: Color) -> some View {
        Button {
            record.retrospectiveWorth = worth
            notificationStore.removeRetrospectiveTask(for: record)
            try? modelContext.save()
            dismiss()
        } label: {
            Text(localization.text(key))
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(worth == .regret ? Color.white : AppTheme.textPrimary)
                .background(worth == .regret ? tint : tint.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
