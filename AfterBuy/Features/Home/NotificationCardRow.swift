import SwiftData
import SwiftUI

struct NotificationCardRow: View {
    let item: AppNotificationItem
    let relativeTimeText: String

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var localization: LocalizationManager

    private var isRetrospective: Bool {
        item.action == .openRecordRetrospective
    }

    private var accentBarColor: Color {
        isRetrospective ? Color(hex: "69B7CE") : Color(hex: "C65840")
    }

    private var linkedRecord: TransactionRecord? {
        guard isRetrospective else { return nil }
        return RetrospectiveReviewService.linkedRecord(for: item, modelContext: modelContext)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            leftColumn
            Spacer(minLength: 10)
            rightColumn
        }
        .padding(.leading, 22)
        .padding(.trailing, 14)
        .padding(.vertical, 14)
        .background(AppTheme.cardBackground)
        .overlay(alignment: .leading) {
            Capsule()
                .fill(accentBarColor)
                .frame(width: 3)
                .padding(.vertical, 14)
                .padding(.leading, 12)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    item.isRead ? Color.primary.opacity(0.04) : accentBarColor.opacity(0.22),
                    lineWidth: 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            if isRetrospective {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 12)
                    .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Left column

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleRow

            if isRetrospective {
                retrospectiveDetailRow
            }

            Text(footerText)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleRow: some View {
        HStack(spacing: 6) {
            Text(item.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)

            if item.isPinned {
                Text(localization.text(.notificationPinned))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.actionBlue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.actionBlue.opacity(0.12))
                    .clipShape(Capsule())
            }

            if !item.isRead {
                Circle()
                    .fill(AppTheme.accentRisk)
                    .frame(width: 6, height: 6)
            }
        }
    }

    @ViewBuilder
    private var retrospectiveDetailRow: some View {
        if let record = linkedRecord {
            HStack(spacing: 8) {
                CategoryIconBadge(
                    categoryKey: record.categoryKey,
                    iconSymbolOverride: record.categoryIconSymbolRaw,
                    backgroundColor: Color.primary,
                    size: 28,
                    cornerRadius: 8,
                    iconSize: 13,
                    backgroundOpacity: 0.06
                )

                Text(record.resolvedCategoryForRetrospectiveDisplay(localizedText: localization.text))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                EmotionTagCapsule(
                    title: emotionLabel(for: record),
                    record: record
                )
            }
        } else if let parsed = parsedRetrospectiveLines(from: item.message) {
            HStack(spacing: 8) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(parsed.destination)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                if let mood = parsed.emotionLabel {
                    Text(mood)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.textSecondary.opacity(0.12))
                        .foregroundStyle(AppTheme.textSecondary)
                        .clipShape(Capsule())
                        .lineLimit(1)
                }
            }
        }
    }

    private var footerText: String {
        if isRetrospective {
            return localization.text(.notificationRetrospectivePrompt)
        }
        return item.message
    }

    // MARK: - Right column

    private var rightColumn: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(relativeTimeText)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .monospacedDigit()

            if let amountText = trailingAmountText {
                Text(amountText)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .monospacedDigit()
            }
        }
        .padding(.bottom, isRetrospective ? 14 : 0)
    }

    private var trailingAmountText: String? {
        if let record = linkedRecord {
            return AppFormatter.moneyString(from: record.amount, locale: localization.locale)
        }
        if isRetrospective, let parsed = parsedRetrospectiveLines(from: item.message), let amount = parsed.amountText {
            return amount
        }
        if item.type == .warning, let amount = item.warningAmount, amount > 0 {
            return AppFormatter.moneyString(from: amount, locale: localization.locale)
        }
        return nil
    }

    // MARK: - Helpers

    private func emotionLabel(for record: TransactionRecord) -> String {
        if let preset = EmotionTag.from(raw: record.emotionRaw) {
            return localization.text(preset.key)
        }
        return record.safeEmotionName
    }

    private struct ParsedRetrospectiveLines {
        let destination: String
        let emotionLabel: String?
        let amountText: String?
    }

    private func parsedRetrospectiveLines(from message: String) -> ParsedRetrospectiveLines? {
        let lines = message.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count >= 2 else { return nil }

        var destination = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["消费去向：", "消費去向：", "Where it went: "] {
            if destination.hasPrefix(prefix) {
                destination = String(destination.dropFirst(prefix.count))
                break
            }
        }

        let middle = lines[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = middle.split(separator: "·", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let emotion = parts.first.flatMap { $0.isEmpty ? nil : $0 }
        let amount = parts.count > 1 ? parts[1] : nil

        return ParsedRetrospectiveLines(
            destination: destination,
            emotionLabel: emotion,
            amountText: amount
        )
    }
}
