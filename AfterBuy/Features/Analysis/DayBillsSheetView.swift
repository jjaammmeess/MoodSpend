import SwiftData
import SwiftUI

/// Period bill drill-down (calendar day or correlation bucket): gallery header + integrated card.
enum DayBillsSheetHeaderMode {
    /// Single day: `2026年5月` + `13日 · 周三`.
    case day
    /// Month bucket (year chart): `2026年` + `5月`.
    case month
}

struct DayBillsSheetView: View {
    let selectedDate: Date?
    let records: [TransactionRecord]
    var headerMode: DayBillsSheetHeaderMode = .day

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var appSettings: AppSettings
    @EnvironmentObject private var notificationStore: NotificationCenterStore

    @State private var detailRecord: TransactionRecord?
    @State private var editingRecord: TransactionRecord?
    @State private var recordPendingDelete: TransactionRecord?

    private var sortedRecords: [TransactionRecord] {
        records.sorted { $0.createdAt > $1.createdAt }
    }

    private var dayTotal: Double {
        sortedRecords.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    galleryStyleHeader

                    if sortedRecords.isEmpty {
                        EmptyStateBlock(
                            title: localization.text(.analysisDayBillsEmpty),
                            systemImage: "calendar.badge.exclamationmark"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        billsIntegratedCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .background(AppTheme.pageBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localization.text(.commonCancel)) {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .medium))
                }
            }
            .navigationDestination(item: $editingRecord) { record in
                RecordSheetView(editingRecord: record)
                    .environmentObject(localization)
                    .environmentObject(appSettings)
            }
        }
        .sheet(item: $detailRecord) { record in
            RecordDetailView(record: record)
                .environmentObject(localization)
                .environmentObject(appSettings)
                .environmentObject(notificationStore)
        }
        .recordDeleteConfirmation(item: $recordPendingDelete)
    }

    // MARK: - Gallery header

    private var galleryStyleHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(galleryCaptionLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(galleryHeadlineLine)
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Spacer(minLength: 8)

            Text(gallerySummaryLine)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var galleryCaptionLine: String {
        guard let selectedDate else { return "" }
        switch headerMode {
        case .day:
            return AppFormatter.galleryYearMonthString(from: selectedDate, locale: localization.locale)
        case .month:
            return AppFormatter.galleryYearOnlyString(from: selectedDate, locale: localization.locale)
        }
    }

    private var galleryHeadlineLine: String {
        guard let selectedDate else { return "" }
        switch headerMode {
        case .day:
            var line = AppFormatter.galleryDayWeekdayString(from: selectedDate, locale: localization.locale)
            if Calendar.current.isDateInToday(selectedDate) {
                line += " · \(localization.text(.commonToday))"
            }
            return line
        case .month:
            return AppFormatter.galleryMonthOnlyString(from: selectedDate, locale: localization.locale)
        }
    }

    private var gallerySummaryLine: String {
        let count = sortedRecords.count
        let totalText = dayTotalAmountText
        return String(
            format: localization.text(.analysisDayBillsGallerySummary),
            locale: localization.locale,
            arguments: [count, totalText]
        )
    }

    private var dayTotalAmountText: String {
        guard !sortedRecords.isEmpty else {
            let zero = AppFormatter.moneyString(from: 0, locale: localization.locale)
            return "-\(zero)"
        }
        let sign = sortedRecords.allSatisfy { $0.type == .expense } ? "-" : ""
        let money = AppFormatter.moneyString(from: dayTotal, locale: localization.locale)
        return "\(sign)\(money)"
    }

    // MARK: - Integrated card

    private var billsIntegratedCard: some View {
        VStack(spacing: 0) {
            ForEach(sortedRecords) { record in
                DayBillRecordRow(record: record)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        detailRecord = record
                    }
                    .contextMenu {
                        Button(localization.text(.billsEdit)) {
                            editingRecord = record
                        }
                        Button(role: .destructive) {
                            recordPendingDelete = record
                        } label: {
                            Label(localization.text(.commonDelete), systemImage: "trash")
                        }
                    }
            }
        }
        .background(Color.primary.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Record row (inside integrated card)

private struct DayBillRecordRow: View {
    @EnvironmentObject private var localization: LocalizationManager
    let record: TransactionRecord

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CategoryIconBadge(
                categoryKey: record.categoryKey,
                iconSymbolOverride: record.categoryIconSymbolRaw,
                backgroundColor: Color.primary,
                size: 40,
                cornerRadius: 20,
                iconSize: 16,
                backgroundOpacity: 0.03
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(displayCategory)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text(AppFormatter.timeString(from: record.createdAt, locale: localization.locale))
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.58))
                        .monospacedDigit()

                    if RecordAttachmentIndicators.hasContent(record) {
                        DayBillAttachmentIndicators(record: record)
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text(amountText)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(record.type == .expense ? AppTheme.textPrimary : AppTheme.actionBlue)

                EmotionTagCapsule(
                    title: displayEmotion,
                    record: record
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
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

// MARK: - Compact attachment icons

private struct DayBillAttachmentIndicators: View {
    let record: TransactionRecord

    var body: some View {
        HStack(spacing: 4) {
            if hasNote {
                Image(systemName: "note.text")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.55))
            }
            if hasPhoto {
                Image(systemName: "photo")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.actionBlue.opacity(0.7))
            }
        }
    }

    private var hasNote: Bool {
        !record.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasPhoto: Bool {
        record.hasImageAttachments
    }
}
