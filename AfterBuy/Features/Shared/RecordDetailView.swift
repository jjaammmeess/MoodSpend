import SwiftData
import SwiftUI
import UIKit

private enum RecordDetailRoute: Hashable {
    case edit
    case retrospective
}

struct RecordDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var appSettings: AppSettings
    @EnvironmentObject private var notificationStore: NotificationCenterStore

    let record: TransactionRecord

    @State private var route: RecordDetailRoute?
    @State private var showDeleteConfirm = false
    @State private var showImagePreview = false
    @State private var previewImageIndex = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    emotionHeaderOrb
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    summaryCard
                    retrospectiveCard
                    attachmentCardsRow
                    deleteButton
                }
                .padding(16)
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationTitle(localization.text(.recordDetailTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localization.text(.commonCancel)) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localization.text(.billsEdit)) {
                        route = .edit
                    }
                }
            }
            .navigationDestination(item: $route) { destination in
                switch destination {
                case .edit:
                    RecordSheetView(editingRecord: record)
                        .environmentObject(localization)
                        .environmentObject(appSettings)
                case .retrospective:
                    RecordRetrospectiveForm(record: record)
                        .environmentObject(localization)
                        .environmentObject(notificationStore)
                }
            }
        }
        .fullScreenCover(isPresented: $showImagePreview) {
            imagePreview
        }
        .sheet(isPresented: $showDeleteConfirm) {
            RecordDeleteConfirmSheet(
                record: record,
                onDelete: {
                    RetrospectiveReviewService.deleteRecord(
                        record,
                        modelContext: modelContext,
                        notificationStore: notificationStore
                    )
                    showDeleteConfirm = false
                    dismiss()
                },
                onCancel: {
                    showDeleteConfirm = false
                }
            )
            .environmentObject(localization)
            .appDestructiveConfirmSheetStyle(height: 388)
        }
    }

    private static let headerOrbDiameter: CGFloat = 72

    @ViewBuilder
    private var emotionHeaderOrb: some View {
        let d = Self.headerOrbDiameter
        let accent = record.emotionColor
        let style = appSettings.emotionIconStyle
        ZStack {
            if let raster = EmotionIconPresentation.rasterAssetName(for: record, style: style) {
                Image(raster)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: d, height: d)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(accent.opacity(0.14))
                    .frame(width: d, height: d)
                Image(systemName: EmotionIconPresentation.symbolName(for: record))
                    .font(.system(size: d * 0.38, weight: .semibold))
                    .foregroundStyle(accent)
                    .symbolRenderingMode(.monochrome)
            }
            Circle()
                .strokeBorder(accent.opacity(0.38), lineWidth: 2)
                .frame(width: d, height: d)
        }
        .accessibilityLabel(displayEmotion)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            detailRow(
                icon: "banknote",
                title: localization.text(.recordDetailAmount),
                value: AppFormatter.moneyString(from: record.amount, locale: localization.locale)
            )
            detailRow(
                icon: "square.grid.2x2",
                title: localization.text(.recordDetailCategory),
                value: displayCategory
            )
            emotionDetailRow
            detailRow(
                icon: "calendar",
                title: localization.text(.recordDetailTime),
                value: AppFormatter.dayTimeString(from: record.createdAt, locale: localization.locale)
            )
        }
        .softGlowCardStyle(glowTint: record.emotionColor, intensity: .recordSummary)
    }

    @ViewBuilder
    private var retrospectiveCard: some View {
        if record.type == .expense {
            if let worth = record.retrospectiveWorth {
                VStack(alignment: .leading, spacing: 6) {
                    Text(retrospectiveWorthLabel(worth))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCardStyle()
            } else if retrospectiveEligible {
                VStack(alignment: .leading, spacing: 10) {
                    Text(localization.text(.recordDetailRetrospectiveAdd))
                        .font(.headline)
                    Text(localization.text(.recordDetailRetrospectiveHint))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Button {
                        route = .retrospective
                    } label: {
                        Text(localization.text(.recordDetailRetrospectiveButton))
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(AppTheme.textPrimary)
                            .background(AppTheme.actionBlue.opacity(0.16))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .contentShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .appCardStyle()
            }
        }
    }

    private var retrospectiveEligible: Bool {
        record.type == .expense
            && record.retrospectiveWorthRaw == nil
            && Date().timeIntervalSince(record.createdAt) >= AnalysisChartMetrics.retrospectiveMinAge
    }

    private func retrospectiveWorthLabel(_ worth: RetrospectiveWorth) -> String {
        let key: LKey
        switch worth {
        case .worthIt: key = .retrospectiveWorthIt
        case .neutral: key = .retrospectiveNeutral
        case .regret: key = .retrospectiveRegret
        }
        return String(
            format: localization.text(.recordDetailRetrospectiveResult),
            locale: localization.locale,
            arguments: [localization.text(key)]
        )
    }

    private var attachmentCardsRow: some View {
        VStack(alignment: .leading, spacing: RecordDetailLayout.compactCardSpacing) {
            noteCompactCard
            receiptCompactCard
        }
    }

    private var noteCompactCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            compactCardHeader(
                icon: "note.text",
                title: localization.text(.recordDetailNote)
            )
            if record.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(localization.text(.recordDetailNoNote))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(record.note)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(4)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle()
    }

    private var receiptCompactCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            compactCardHeader(
                icon: "photo.on.rectangle.angled",
                title: localization.text(.recordDetailReceipt)
            )
            if !receiptImages.isEmpty {
                if receiptImages.count == 1, let image = receiptImages.first {
                    Button {
                        previewImageIndex = 0
                        showImagePreview = true
                    } label: {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: RecordDetailLayout.receiptImagePreviewMaxHeight)
                            .frame(minHeight: RecordDetailLayout.receiptImagePreviewMinHeight)
                            .background(AppTheme.divider.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(AppTheme.border.opacity(0.38), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(localization.text(.recordDetailReceipt)))
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(receiptImages.enumerated()), id: \.offset) { index, image in
                                Button {
                                    previewImageIndex = index
                                    showImagePreview = true
                                } label: {
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 108, height: 108)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .strokeBorder(AppTheme.border.opacity(0.38), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .accessibilityLabel(Text(localization.text(.recordDetailReceipt)))
                }
            } else {
                Text(localization.text(.recordDetailNoReceipt))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle()
    }

    private func compactCardHeader(icon: String, title: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.actionBlue)
                .frame(width: 30, height: 30)
                .background(AppTheme.actionBlue.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
    }

    private var deleteButton: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                Text(localization.text(.commonDelete))
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(AppTheme.accentRisk)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.mineDestructivePillFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.accentRisk.opacity(colorScheme == .dark ? 0.32 : 0.22), lineWidth: 1)
            }
            .shadow(
                color: AppTheme.accentRisk.opacity(colorScheme == .dark ? 0.14 : 0.10),
                radius: 10,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private var emotionDetailRow: some View {
        let style = appSettings.emotionIconStyle
        return HStack(alignment: .top, spacing: 8) {
            Group {
                if let raster = EmotionIconPresentation.rasterAssetName(for: record, style: style) {
                    Image(raster)
                        .renderingMode(.original)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: 18, height: 18)
                        .clipShape(Circle())
                } else {
                    Image(systemName: EmotionIconPresentation.symbolName(for: record))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(record.emotionColor)
                        .symbolRenderingMode(.monochrome)
                }
            }
            .frame(width: 18, alignment: .leading)

            Text(localization.text(.recordDetailEmotion))
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text(displayEmotion)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 18, alignment: .leading)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if !receiptImages.isEmpty {
                TabView(selection: $previewImageIndex) {
                    ForEach(Array(receiptImages.enumerated()), id: \.offset) { index, image in
                        image
                            .resizable()
                            .scaledToFit()
                            .padding()
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: receiptImages.count > 1 ? .automatic : .never))
            }
            Button {
                showImagePreview = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(20)
            }
        }
    }

    private var receiptImages: [Image] {
        record.resolvedImageAttachments.compactMap { data in
            guard let uiImage = UIImage(data: data) else { return nil }
            return Image(uiImage: uiImage)
        }
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

private enum RecordDetailLayout {
    static let compactCardSpacing: CGFloat = 12
    /// Caps preview height so tall portraits show more without dominating the screen.
    static let receiptImagePreviewMaxHeight: CGFloat = 260
    static let receiptImagePreviewMinHeight: CGFloat = 140
}
