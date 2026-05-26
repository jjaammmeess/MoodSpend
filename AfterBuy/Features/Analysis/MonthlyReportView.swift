import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct MonthlyReportView: View {
    private struct SharePosterImageItem: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    private struct AlertMessage: Identifiable {
        let id = UUID()
        let text: String
    }

    private struct EmotionHighlight: Identifiable {
        let id: String
        let emotionRaw: String
        let title: String
        let color: Color
        let colorHex: String
        let ratio: Int
        let ratioText: String
    }

    let records: [TransactionRecord]
    let scope: EmotionReportScope

    @Query(
        filter: #Predicate<CustomOption> { $0.deletedAt == nil },
        sort: \CustomOption.createdAt,
        order: .reverse
    ) private var customOptions: [CustomOption]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var appSettings: AppSettings

    @State private var exportDocument = TextFileDocument(text: "")
    @State private var showExporter = false
    @State private var sharePosterImageItem: SharePosterImageItem?
    @State private var alertMessage: AlertMessage?

    private var reportExportFilename: String {
        "\(localization.text(.analysisReportFilenameBase))-\(scope.exportFilenameSuffix)-\(AppFormatter.exportDateStamp())"
    }

    private var customEmotionOptions: [CustomOption] {
        customOptions.filter { $0.kind == .emotion }
    }

    private var reportData: MonthlyReportData {
        MonthlyReportService.generate(
            records: records,
            locale: localization.locale,
            text: localization.text,
            appSettings: appSettings,
            customEmotions: customEmotionOptions
        )
    }

    private var emotionHighlights: [EmotionHighlight] {
        let breakdown = EmotionShareCalculator.breakdown(from: records)
        return EmotionShareCalculator.topItems(from: breakdown, limit: 3).compactMap { item in
            guard let first = records.first(where: { $0.emotionRaw == item.emotionRaw }) else { return nil }
            let title: String
            if let preset = EmotionTag.from(raw: item.emotionRaw) {
                title = localization.text(preset.key)
            } else {
                title = first.safeEmotionName
            }
            return EmotionHighlight(
                id: item.emotionRaw,
                emotionRaw: item.emotionRaw,
                title: title,
                color: first.emotionColor,
                colorHex: first.displayEmotionColorHex,
                ratio: item.sharePercent,
                ratioText: "\(item.sharePercent)%"
            )
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                MonthlyReportContentView(
                    model: reportContentModel,
                    presentation: .interactive
                )
            }
            .scrollIndicators(.hidden)
            .background(ReportShareTheme.navigationBarBackground.ignoresSafeArea())
            .navigationTitle(scope.navigationBarTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(ReportShareTheme.navigationBarBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localization.text(.commonCancel)) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(localization.text(.analysisReportExport)) {
                            exportReport()
                        }
                        Button(localization.text(.analysisReportShareImage)) {
                            sharePosterImage()
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .plainText,
            defaultFilename: reportExportFilename
        ) { _ in }
        .sheet(item: $sharePosterImageItem) { item in
            ShareSheet(items: [item.image])
        }
        .alert(item: $alertMessage) { item in
            Alert(
                title: Text(scope.title),
                message: Text(item.text),
                dismissButton: .default(Text(localization.text(.commonCancel)))
            )
        }
    }

    // MARK: - Content model

    private var reportContentModel: MonthlyReportContentModel {
        let total = AppFormatter.moneyString(from: reportData.totalExpense, locale: localization.locale)
        let ratio = "\(Int(reportData.effectiveRatio * 100))%"
        let effectiveLine = "\(localization.text(.analysisReportEffectiveRatio))：\(ratio)（\(localization.text(.analysisReportHeroMetricEffectiveRatioHint))）"
        let generatedAt = AppFormatter.dayString(from: reportData.generatedAt, locale: localization.locale)
        let generatedLine = String(
            format: localization.text(.analysisReportPosterGeneratedAt),
            locale: localization.locale,
            arguments: [generatedAt] as [CVarArg]
        )

        return MonthlyReportContentModel(
            productName: AppBranding.productName(for: localization.language),
            reportTitle: scope.posterTitle,
            reportSubtitle: localization.text(.analysisReportPosterSubtitle),
            generatedAtText: generatedLine,
            periodRangeLabel: scope.periodLabel,
            expenseLabel: localization.text(scope.expenseLabelKey),
            totalExpenseText: total,
            totalCountText: "\(localization.text(.analysisReportTotalCount))：\(reportData.totalCount)",
            topEmotionText: "\(localization.text(.analysisReportTopEmotion))：\(reportData.topEmotionName)",
            effectiveRatioText: effectiveLine,
            emotionPaletteTitle: localization.text(.analysisReportEmotionPalette),
            emotionPaletteFootnote: emotionPaletteFootnoteText,
            rulesTitle: localization.text(.analysisReportRulesTitle),
            patternLines: reportData.patternLines,
            warmTipTitle: localization.text(.analysisReportWarmTipTitle),
            warmTipBody: reportData.warmTip,
            footerTagline: posterFooterTagline,
            appStoreLabel: localization.text(.analysisReportPosterAppStore),
            noDataText: scope.noDataMessage,
            emotionHighlights: emotionHighlights.map {
                MonthlyReportContentModel.EmotionHighlight(
                    id: $0.id,
                    title: $0.title,
                    emotionRaw: $0.emotionRaw,
                    color: $0.color,
                    colorHex: $0.colorHex,
                    ratioText: $0.ratioText
                )
            }
        )
    }

    private var emotionPaletteFootnoteText: String? {
        guard reportData.otherEmotionSharePercent > 0 else { return nil }
        return String(
            format: localization.text(.analysisReportEmotionPaletteFootnote),
            locale: localization.locale,
            arguments: ["\(reportData.otherEmotionSharePercent)%"] as [CVarArg]
        )
    }

    private var posterFooterTagline: String {
        let raw = localization.text(.aboutAppBrandSubtitle).trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("—") {
            return String(raw.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if raw.hasPrefix("-") {
            return String(raw.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return raw
    }

    // MARK: - Export / share

    private func exportReport() {
        let text = MonthlyReportService.buildReportText(
            data: reportData,
            locale: localization.locale,
            text: localization.text,
            title: scope.title,
            expenseLabelKey: scope.expenseLabelKey
        )
        exportDocument = TextFileDocument(text: text)
        showExporter = true
    }

    @MainActor
    private func sharePosterImage() {
        if let image = renderPosterImage() {
            sharePosterImageItem = SharePosterImageItem(image: image)
            return
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            if let image = renderPosterImage() {
                sharePosterImageItem = SharePosterImageItem(image: image)
            } else {
                alertMessage = AlertMessage(text: localization.text(.analysisReportShareFailed))
            }
        }
    }

    @MainActor
    private func renderPosterImage() -> UIImage? {
        let renderer = ImageRenderer(
            content: MonthlyReportContentView(
                model: reportContentModel,
                presentation: .exportSnapshot
            )
            .fixedSize(horizontal: false, vertical: true)
        )
        renderer.scale = displayScale
        renderer.proposedSize = ProposedViewSize(width: 390, height: nil)
        guard let image = renderer.uiImage else { return nil }
        guard image.size.width > 1, image.size.height > 1 else { return nil }
        return image
    }
}

#Preview {
    MonthlyReportView(
        records: [],
        scope: EmotionReportScope(
            periodMode: .month,
            interval: DateInterval(start: .now, duration: 86400),
            periodLabel: "2026年5月",
            posterTitle: "本月情绪消费报告",
            navigationBarTitle: "2026年5月",
            title: "2026年5月 情绪消费报告",
            heroCaption: "2026年5月 情绪资金变动",
            noDataMessage: "2026年5月 暂无支出记录，记一笔后即可生成报告。",
            exportFilenameSuffix: "2026y5m"
        )
    )
    .environmentObject(LocalizationManager())
    .environmentObject(AppSettings())
    .modelContainer(for: [CustomOption.self], inMemory: true)
}
