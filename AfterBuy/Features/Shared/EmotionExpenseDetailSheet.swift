import SwiftData
import SwiftUI

// MARK: - Presentation

struct EmotionExpenseDetailPresentation: Equatable {
    let heroSubtitleKey: LKey
    let accentColor: Color
    let watercolorPalette: DashboardWatercolorPalette

    static func homeBucket(_ bucket: EmotionBucket) -> Self {
        switch bucket {
        case .effective:
            return .init(
                heroSubtitleKey: .homeHeroBucketDetailHeroSubtitleEffective,
                accentColor: Color(hex: "69B7CE"),
                watercolorPalette: .spending
            )
        case .emotional:
            return .init(
                heroSubtitleKey: .homeHeroBucketDetailHeroSubtitleEmotional,
                accentColor: AppTheme.accentRisk,
                watercolorPalette: .emotion
            )
        case .necessary:
            return .init(
                heroSubtitleKey: .homeHeroBucketDetailHeroSubtitleNecessary,
                accentColor: AppTheme.actionBlue,
                watercolorPalette: .spending
            )
        }
    }

    static func analysisDashboard(_ kind: AnalysisDashboardDetailKind) -> Self {
        switch kind {
        case .distress:
            return .init(
                heroSubtitleKey: .analysisDashboardDetailHeroSubtitleDistress,
                accentColor: AppTheme.accentInsight,
                watercolorPalette: .emotion
            )
        case .fulfillment:
            return .init(
                heroSubtitleKey: .analysisDashboardDetailHeroSubtitleFulfillment,
                accentColor: Color(hex: "69B7CE"),
                watercolorPalette: .spending
            )
        }
    }
}

// MARK: - Sheet

/// Shared bill-list sheet for home hero buckets and analysis dashboard metrics.
struct EmotionExpenseDetailSheet: View {
    let navigationTitle: String
    let records: [TransactionRecord]
    let periodTotalExpense: Double
    let emptyStateTitle: String
    let shareOfPeriodFormatKey: LKey?
    let scopeNote: String?
    let footerNote: String?
    let presentation: EmotionExpenseDetailPresentation

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

    private var recordsTotal: Double {
        sortedRecords.reduce(0) { $0 + $1.amount }
    }

    private var shareOfPeriodRatio: Double {
        guard periodTotalExpense > 0, !sortedRecords.isEmpty else { return 0 }
        return min(max(recordsTotal / periodTotalExpense, 0), 1)
    }

    private var emotionBreakdownRows: [(title: String, color: Color, amount: Double)] {
        let grouped = Dictionary(grouping: sortedRecords, by: \.emotionRaw)
        let rows: [(title: String, color: Color, amount: Double)] = grouped.compactMap { raw, values in
            guard let first = values.first else { return nil }
            let amount = values.reduce(0) { $0 + $1.amount }
            let title: String
            if let preset = EmotionTag.from(raw: raw) {
                title = localization.text(preset.key)
            } else {
                title = first.safeEmotionName
            }
            return (title, first.emotionColor, amount)
        }
        return rows.sorted { $0.amount > $1.amount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroMetricCard

                    if let scopeNote, !scopeNote.isEmpty {
                        Text(scopeNote)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !emotionBreakdownRows.isEmpty {
                        emotionEnergyBarsCard
                    }

                    if let footerNote, !footerNote.isEmpty {
                        Text(footerNote)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if sortedRecords.isEmpty {
                        EmptyStateBlock(
                            title: emptyStateTitle,
                            systemImage: "tray"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    } else {
                        transactionListSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(AppTheme.pageBackground)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localization.text(.commonCancel)) {
                        dismiss()
                    }
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

    // MARK: - Hero

    private var heroMetricCard: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(localization.text(presentation.heroSubtitleKey))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                Text(moneyText(recordsTotal))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .monospacedDigit()

                if let shareKey = shareOfPeriodFormatKey,
                   periodTotalExpense > 0,
                   !sortedRecords.isEmpty {
                    let share = Int((shareOfPeriodRatio * 100).rounded())
                    Text(
                        String(
                            format: localization.text(shareKey),
                            locale: localization.locale,
                            arguments: ["\(share)"] as [CVarArg]
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .monospacedDigit()
                }
            }

            Spacer(minLength: 12)

            EmotionDetailMiniCountRing(
                progress: shareOfPeriodRatio,
                countLabel: countRingLabel,
                accentColor: presentation.accentColor
            )
        }
        .padding(18)
        .background { heroMetricWatercolorBackground }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.metricDashboardCornerRadius, style: .continuous))
    }

    private var heroMetricWatercolorBackground: some View {
        let radius = AppTheme.metricDashboardCornerRadius
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return ZStack {
            DashboardWatercolorBackground(
                cornerRadius: radius,
                palette: presentation.watercolorPalette,
                layout: .metricDefault
            )

            shape.fill(
                RadialGradient(
                    colors: [
                        presentation.accentColor.opacity(0.22),
                        presentation.accentColor.opacity(0.07),
                        Color.clear,
                    ],
                    center: UnitPoint(x: 0.88, y: 0.38),
                    startRadius: 0,
                    endRadius: 128
                )
            )

            shape.fill(
                RadialGradient(
                    colors: [
                        presentation.accentColor.opacity(0.14),
                        presentation.accentColor.opacity(0.04),
                        Color.clear,
                    ],
                    center: UnitPoint(x: 0.10, y: 0.94),
                    startRadius: 0,
                    endRadius: 110
                )
            )
        }
    }

    private var countRingLabel: String {
        "\(sortedRecords.count) \(localization.text(.analysisDashboardEntries))"
    }

    // MARK: - Emotion bars

    private var emotionEnergyBarsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localization.text(.homeHeroBucketDetailEmotionBreakdown))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)

            ForEach(Array(emotionBreakdownRows.enumerated()), id: \.offset) { _, row in
                EmotionEnergyBarRow(
                    title: row.title,
                    amountText: moneyText(row.amount),
                    color: row.color,
                    progress: recordsTotal > 0 ? row.amount / recordsTotal : 0
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Transactions

    private var transactionListSection: some View {
        VStack(spacing: 12) {
            ForEach(sortedRecords) { record in
                EmotionExpenseDetailRecordCard(record: record)
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
    }

    private func moneyText(_ amount: Double) -> String {
        AppFormatter.moneyString(from: amount, locale: localization.locale)
    }
}

// MARK: - Mini ring

private struct EmotionDetailMiniCountRing: View {
    let progress: Double
    let countLabel: String
    let accentColor: Color

    private let ringSize: CGFloat = 76
    private let lineWidth: CGFloat = 5

    var body: some View {
        ZStack {
            Circle()
                .stroke(accentColor.opacity(0.16), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    accentColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text(countLabel)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .monospacedDigit()
                .minimumScaleFactor(0.75)
                .lineLimit(1)
                .padding(.horizontal, 6)
        }
        .frame(width: ringSize, height: ringSize)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(countLabel)
    }
}

// MARK: - Energy bar row

private struct EmotionEnergyBarRow: View {
    let title: String
    let amountText: String
    let color: Color
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(amountText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                let width = max(proxy.size.width * CGFloat(min(max(progress, 0), 1)), progress > 0 ? 4 : 0)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.18))
                    Capsule()
                        .fill(color)
                        .frame(width: width)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Record card

private struct EmotionExpenseDetailRecordCard: View {
    @EnvironmentObject private var localization: LocalizationManager
    let record: TransactionRecord

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            CategoryIconBadge(
                categoryKey: record.categoryKey,
                iconSymbolOverride: record.categoryIconSymbolRaw,
                backgroundColor: record.emotionColor,
                size: 44,
                cornerRadius: 22,
                iconSize: 17,
                backgroundOpacity: 0.14
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(displayCategory)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(AppFormatter.dayTimeString(from: record.createdAt, locale: localization.locale))
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.85))
                        .monospacedDigit()
                        .lineLimit(1)

                    if RecordAttachmentIndicators.hasContent(record) {
                        RecordAttachmentIndicators(record: record)
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text(amountText)
                    .font(.system(size: 19, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(record.type == .expense ? AppTheme.textPrimary : AppTheme.actionBlue)

                EmotionTagCapsule(
                    title: displayEmotion,
                    record: record
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 3)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border.opacity(0.35), lineWidth: 0.5)
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
