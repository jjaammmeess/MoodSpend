import SwiftUI
import UIKit

// MARK: - Kind

enum BillListMetricDetailKind: String, Identifiable {
    case expense
    case frequency

    var id: String { rawValue }
}

// MARK: - Model

struct BillListMetricsDetailModel {
    let necessaryTotal: Double
    let emotionalPremiumTotal: Double
    let necessarySharePercent: Int
    let stabilityKey: LKey
    let topExpenses: [TopExpenseItem]

    let averageTicket: Double
    let averageTicketStyleKey: LKey
    let peakTimeWindowText: String?
    let entryCount: Int

    struct TopExpenseItem: Identifiable {
        let id: UUID
        let record: TransactionRecord
        let rank: Int
        let amount: Double
        let categoryTitle: String
        let emotionTitle: String
    }

    static func build(
        kind: BillListMetricDetailKind,
        records: [TransactionRecord],
        totalExpense: Double,
        customEmotions: [CustomOption],
        calendar: Calendar,
        categoryTitle: (String) -> String,
        emotionTitle: (String) -> String
    ) -> BillListMetricsDetailModel {
        let necessaryTotal = records
            .filter { EmotionGrouping.isNecessary($0, customEmotions: customEmotions) }
            .reduce(0) { $0 + $1.amount }
        let premium = max(0, totalExpense - necessaryTotal)
        let sharePercent: Int = {
            guard totalExpense > 0 else { return 0 }
            return Int((necessaryTotal / totalExpense * 100).rounded())
        }()
        let stabilityKey: LKey = sharePercent >= 50
            ? .billsMetricDetailStabilitySolid
            : .billsMetricDetailStabilityTrim

        let top = records
            .sorted { $0.amount > $1.amount }
            .prefix(3)
            .enumerated()
            .map { index, record in
                TopExpenseItem(
                    id: record.publicId,
                    record: record,
                    rank: index + 1,
                    amount: record.amount,
                    categoryTitle: categoryTitle(record.categoryKey),
                    emotionTitle: emotionTitle(record.emotionRaw)
                )
            }

        let count = records.count
        let average: Double = count > 0 ? totalExpense / Double(count) : 0
        let avgStyleKey: LKey = {
            if average < 40 { return .billsMetricDetailAvgTicketMicro }
            if average <= 180 { return .billsMetricDetailAvgTicketSteady }
            return .billsMetricDetailAvgTicketLarge
        }()

        return BillListMetricsDetailModel(
            necessaryTotal: necessaryTotal,
            emotionalPremiumTotal: premium,
            necessarySharePercent: sharePercent,
            stabilityKey: stabilityKey,
            topExpenses: Array(top),
            averageTicket: average,
            averageTicketStyleKey: avgStyleKey,
            peakTimeWindowText: peakTwoHourWindow(records: records, calendar: calendar),
            entryCount: count
        )
    }

    /// 2-hour sliding window: [start, start+2) on the clock, e.g. 14:00 – 16:00.
    private static func peakTwoHourWindow(
        records: [TransactionRecord],
        calendar: Calendar
    ) -> String? {
        guard !records.isEmpty else { return nil }

        var bestStart = 0
        var bestCount = 0

        for start in 0..<24 {
            let count = records.filter { record in
                let hour = calendar.component(.hour, from: record.createdAt)
                return hour == start || hour == (start + 1) % 24
            }.count
            if count > bestCount {
                bestCount = count
                bestStart = start
            }
        }

        guard bestCount > 0 else { return nil }

        let endHour = (bestStart + 2) % 24
        return String(format: "%02d:00 – %02d:00", bestStart, endHour)
    }
}

// MARK: - Sheet

struct BillListMetricsDetailSheet: View {
    let kind: BillListMetricDetailKind
    let model: BillListMetricsDetailModel
    var onSelectRecord: ((TransactionRecord) -> Void)?

    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var currencyManager: CurrencyManager
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showPaywall = false

    private var inkPrimary: Color {
        colorScheme == .dark ? Color(hex: "E8EDF0") : Color(hex: "1A2328")
    }

    private var inkSecondary: Color {
        colorScheme == .dark ? Color(hex: "8A959C") : Color(hex: "5C6670")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MetricsInsightSpectrumBackdrop(reduceMotion: reduceMotion)
                    .ignoresSafeArea()

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    sheetHeader

                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            switch kind {
                            case .expense:
                                expenseContent
                            case .frequency:
                                frequencyContent
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.fraction(0.48)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(source: .billTopExpense)
                .environmentObject(localization)
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        Text(navigationTitle)
            .font(.system(size: 22, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(inkPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 6)
    }

    private var navigationTitle: String {
        switch kind {
        case .expense:
            return localization.text(.billsMetricDetailTitleExpense)
        case .frequency:
            return localization.text(.billsMetricDetailTitleFrequency)
        }
    }

    // MARK: - Expense

    private var expenseContent: some View {
        VStack(alignment: .leading, spacing: 32) {
            necessarySection
            topThreeSection
        }
    }

    private var necessarySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionLabel(localization.text(.billsMetricDetailNecessaryTitle))

            MetricDashboardWidthContainer { availableWidth in
                let moneyScale = pairedSummaryMoneyScale(availableWidth: availableWidth)
                HStack(alignment: .top, spacing: 14) {
                    necessaryMetricColumn(moneyScale: moneyScale)
                    emotionalMetricColumn(moneyScale: moneyScale)
                }
            }

            Text(localization.text(model.stabilityKey))
                .font(.footnote)
                .foregroundStyle(inkSecondary)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func pairedSummaryMoneyScale(availableWidth: CGFloat) -> CGFloat {
        let columnWidth = max((availableWidth - MetricsInsightLayout.summaryColumnSpacing) / 2, 0)
        let necessaryIdeal = MetricsInsightMoneyText.idealWidth(
            for: model.necessaryTotal,
            majorSize: MetricsInsightLayout.summaryMajorSize,
            minorSize: MetricsInsightLayout.summaryMinorSize,
            currencyManager: currencyManager,
            locale: localization.locale
        )
        let premiumIdeal = MetricsInsightMoneyText.idealWidth(
            for: model.emotionalPremiumTotal,
            majorSize: MetricsInsightLayout.summaryMajorSize,
            minorSize: MetricsInsightLayout.summaryMinorSize,
            currencyManager: currencyManager,
            locale: localization.locale
        )
        return MetricDashboardTwoColumnLayout.leadingMoneyScale(
            columnWidth: columnWidth,
            contentIdealWidth: max(necessaryIdeal, premiumIdeal),
            horizontalPadding: 0
        )
    }

    private func necessaryMetricColumn(moneyScale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MetricsInsightMoneyText(
                amount: model.necessaryTotal,
                majorSize: MetricsInsightLayout.summaryMajorSize,
                minorSize: MetricsInsightLayout.summaryMinorSize,
                foreground: MetricsInsightPalette.necessary,
                moneyScale: moneyScale
            )

            HStack(spacing: 6) {
                MetricsInsightGlowIcon(
                    systemName: "bag.fill",
                    tint: MetricsInsightPalette.necessary,
                    reduceMotion: reduceMotion
                )
                Text(localization.text(.billsMetricDetailNecessaryLabel))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(inkSecondary)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func emotionalMetricColumn(moneyScale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MetricsInsightMoneyText(
                amount: model.emotionalPremiumTotal,
                majorSize: MetricsInsightLayout.summaryMajorSize,
                minorSize: MetricsInsightLayout.summaryMinorSize,
                foreground: MetricsInsightPalette.premium,
                moneyScale: moneyScale
            )

            HStack(spacing: 6) {
                MetricsInsightGlowIcon(
                    systemName: "circle.hexagongrid.fill",
                    tint: MetricsInsightPalette.premium,
                    reduceMotion: reduceMotion
                )
                Text(localization.text(.billsMetricDetailPremiumLabel))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(inkSecondary)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var topThreeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel(localization.text(.billsMetricDetailTop3Title))

            if model.topExpenses.isEmpty {
                Text(localization.text(.billsMetricDetailTop3Empty))
                    .font(.footnote)
                    .foregroundStyle(inkSecondary)
                    .lineSpacing(5)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(model.topExpenses) { item in
                            topExpenseStreamCard(item, cardWidth: topThreeCardWidth)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private var topThreeCardWidth: CGFloat {
        let amounts = model.topExpenses.map(\.amount)
        let moneyIdeal = MetricsInsightMoneyText.idealWidth(
            forAmounts: amounts,
            majorSize: MetricsInsightLayout.topCardMajorSize,
            minorSize: MetricsInsightLayout.topCardMinorSize,
            currencyManager: currencyManager,
            locale: localization.locale
        )
        let contentWidth = moneyIdeal + MetricsInsightLayout.topCardPadding * 2
        return min(
            MetricsInsightLayout.topCardMaxWidth,
            max(MetricsInsightLayout.topCardMinWidth, contentWidth)
        )
    }

    /// Plan A: free users see TOP 1 only; TOP 2 and TOP 3 require Pro.
    private func isTopExpenseRankLocked(_ rank: Int) -> Bool {
        !subscriptionManager.isPro && rank >= 2
    }

    @ViewBuilder
    private func topExpenseStreamCard(
        _ item: BillListMetricsDetailModel.TopExpenseItem,
        cardWidth: CGFloat
    ) -> some View {
        let isLocked = isTopExpenseRankLocked(item.rank)

        Button {
            if isLocked {
                showPaywall = true
            } else {
                dismiss()
                onSelectRecord?(item.record)
            }
        } label: {
            ZStack {
                topExpenseCardBody(item)

                if isLocked {
                    topExpenseProVeil
                }
            }
            .frame(width: cardWidth)
            .clipShape(RoundedRectangle(cornerRadius: MetricsInsightLayout.topCardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func topExpenseCardBody(_ item: BillListMetricsDetailModel.TopExpenseItem) -> some View {
        let isLocked = isTopExpenseRankLocked(item.rank)

        return VStack(alignment: .leading, spacing: 10) {
            Text(
                String(
                    format: localization.text(.billsMetricDetailTopRank),
                    locale: localization.locale,
                    Int64(item.rank)
                )
            )
            .font(.caption2.weight(.heavy))
            .foregroundStyle(inkSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.55))
            }

            MetricsInsightMoneyText(
                amount: item.amount,
                majorSize: MetricsInsightLayout.topCardMajorSize,
                minorSize: MetricsInsightLayout.topCardMinorSize,
                foreground: inkPrimary
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.categoryTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(inkPrimary)
                    .lineLimit(1)

                Text(item.emotionTitle)
                    .font(.caption2)
                    .foregroundStyle(inkSecondary)
                    .lineLimit(1)
            }
        }
        .padding(MetricsInsightLayout.topCardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: MetricsInsightLayout.topCardRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: MetricsInsightLayout.topCardRadius, style: .continuous)
                        .stroke(
                            MetricsInsightPalette.cardRimGradient,
                            lineWidth: 0.8
                        )
                }
        }
        .blur(radius: isLocked ? 9 : 0)
    }

    private var topExpenseProVeil: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.62)

            VStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(inkPrimary)
                    .shadow(color: MetricsInsightPalette.premium.opacity(0.45), radius: 8)

                Text(localization.text(.billsMetricDetailProLockHint))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(inkSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 10)
            }
        }
    }

    // MARK: - Frequency

    private var frequencyContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            averageTicketSection
            peakTimeSection
        }
    }

    private var averageTicketSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel(localization.text(.billsMetricDetailAvgTicketTitle))

            if model.entryCount == 0 {
                Text(localization.text(.billsMetricDetailFrequencyEmpty))
                    .font(.footnote)
                    .foregroundStyle(inkSecondary)
                    .lineSpacing(5)
            } else {
                Text(money(model.averageTicket))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(inkPrimary)
                    .monospacedDigit()

                Text(localization.text(model.averageTicketStyleKey))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.actionBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        Capsule()
                            .fill(AppTheme.actionBlue.opacity(0.14))
                    }
            }
        }
    }

    private var peakTimeSection: some View {
        HStack(alignment: .top, spacing: 12) {
            MetricsInsightGlowIcon(
                systemName: "clock.fill",
                tint: AppTheme.actionBlue,
                reduceMotion: reduceMotion
            )

            VStack(alignment: .leading, spacing: 8) {
                sectionLabel(localization.text(.billsMetricDetailPeakTimeTitle))

                if let window = model.peakTimeWindowText {
                    Text(
                        String(
                            format: localization.text(.billsMetricDetailPeakTimeBody),
                            locale: localization.locale,
                            window
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(inkPrimary)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(localization.text(.billsMetricDetailPeakTimeUnavailable))
                        .font(.footnote)
                        .foregroundStyle(inkSecondary)
                        .lineSpacing(5)
                }
            }
        }
    }

    // MARK: - Chrome

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .tracking(0.6)
            .foregroundStyle(inkSecondary)
    }

    private func money(_ amount: Double) -> String {
        AppFormatter.moneyString(from: amount, locale: localization.locale)
    }
}

// MARK: - Money text (aligned with `BillListMetricDashboard`)

private struct MetricsInsightMoneyText: View {
    let amount: Double
    let majorSize: CGFloat
    let minorSize: CGFloat
    let foreground: Color
    var moneyScale: CGFloat = 1

    @EnvironmentObject private var currencyManager: CurrencyManager
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        let clampedScale = max(moneyScale, MetricDashboardTwoColumnLayout.minLeadingMoneyScale)
        let scaledMajor = majorSize * clampedScale
        let scaledMinor = minorSize * clampedScale
        let floorScale: CGFloat = moneyScale < 0.999 ? 1 : MetricsInsightLayout.moneyMinimumScaleFactor

        Text(attributedString(majorSize: scaledMajor, minorSize: scaledMinor))
            .lineLimit(1)
            .minimumScaleFactor(floorScale)
            .allowsTightening(true)
            .scaledToFit()
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private func attributedString(majorSize: CGFloat, minorSize: CGFloat) -> AttributedString {
        let parts = amount.moneyDisplayParts(
            currencyManager: currencyManager,
            locale: localization.locale
        )
        var result = AttributedString(parts.major)
        result.font = .system(size: majorSize, weight: .bold, design: .rounded).monospacedDigit()
        result.foregroundColor = foreground

        if !parts.minor.isEmpty {
            var minor = AttributedString(parts.minor)
            minor.font = .system(size: minorSize, weight: .bold, design: .rounded).monospacedDigit()
            minor.foregroundColor = foreground.opacity(0.88)
            result.append(minor)
        }
        return result
    }

    static func idealWidth(
        for amount: Double,
        majorSize: CGFloat,
        minorSize: CGFloat,
        currencyManager: CurrencyManager,
        locale: Locale
    ) -> CGFloat {
        idealWidth(
            forAmounts: [amount],
            majorSize: majorSize,
            minorSize: minorSize,
            currencyManager: currencyManager,
            locale: locale
        )
    }

    static func idealWidth(
        forAmounts amounts: [Double],
        majorSize: CGFloat,
        minorSize: CGFloat,
        currencyManager: CurrencyManager,
        locale: Locale
    ) -> CGFloat {
        let majorFont = UIFont.monospacedDigitSystemFont(ofSize: majorSize, weight: .bold)
        let minorFont = UIFont.monospacedDigitSystemFont(ofSize: minorSize, weight: .bold)
        var widest: CGFloat = 0
        for amount in amounts {
            let parts = amount.moneyDisplayParts(currencyManager: currencyManager, locale: locale)
            let majorWidth = MetricDashboardTwoColumnLayout.singleLineTextWidth(parts.major, font: majorFont)
            let minorWidth = parts.minor.isEmpty
                ? 0
                : MetricDashboardTwoColumnLayout.singleLineTextWidth(parts.minor, font: minorFont)
            widest = max(widest, majorWidth + minorWidth + 2)
        }
        return widest
    }
}

// MARK: - Visual system

private enum MetricsInsightLayout {
    static let topCardMinWidth: CGFloat = 184
    static let topCardMaxWidth: CGFloat = 208
    static let topCardPadding: CGFloat = 16
    static let topCardRadius: CGFloat = 18
    static let topCardMajorSize: CGFloat = 26
    static let topCardMinorSize: CGFloat = 14

    static let summaryMajorSize: CGFloat = 30
    static let summaryMinorSize: CGFloat = 14
    static let summaryColumnSpacing: CGFloat = 14

    static let moneyMinimumScaleFactor: CGFloat = 0.55
}

private enum MetricsInsightPalette {
    static let spectrumColors: [Color] = [
        Color(hex: "C65840"),
        Color(hex: "E8B84A"),
        Color(hex: "5F9E7A"),
        Color(hex: "69B7CE"),
        Color(hex: "8C76A1"),
    ]

    static let necessary = Color(hex: "5F9E7A")
    static let premium = Color(hex: "C65840")

    static var spectrumLinear: LinearGradient {
        LinearGradient(
            stops: MoodSpectrumGradient.stops(from: spectrumColors),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var cardRimGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.55),
                Color.white.opacity(0.08),
                spectrumColors[2].opacity(0.35),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct MetricsInsightSpectrumBackdrop: View {
    let reduceMotion: Bool

    var body: some View {
        Group {
            if reduceMotion {
                staticSpectrum
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 24)) { timeline in
                    let phase = timeline.date.timeIntervalSinceReferenceDate
                    animatedSpectrum(phase: phase)
                }
            }
        }
    }

    private var staticSpectrum: some View {
        GeometryReader { proxy in
            spectrumLayer(shift: 0, height: proxy.size.height)
        }
    }

    private func animatedSpectrum(phase: TimeInterval) -> some View {
        GeometryReader { proxy in
            let drift = CGFloat(sin(phase * 0.55) * 0.07 + cos(phase * 0.31) * 0.04)
            spectrumLayer(shift: drift, height: proxy.size.height)
        }
    }

    private func spectrumLayer(shift: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            MetricsInsightPalette.spectrumLinear
                .opacity(0.5)
                .blur(radius: 28)
                .frame(height: height * 0.62)
                .offset(y: height * 0.14)
                .mask {
                    LinearGradient(
                        colors: [.clear, .white, .white.opacity(0.35)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

            LinearGradient(
                stops: MoodSpectrumGradient.stops(from: MetricsInsightPalette.spectrumColors),
                startPoint: UnitPoint(x: -0.12 + shift, y: 0.92),
                endPoint: UnitPoint(x: 1.08 - shift, y: 0.42)
            )
            .opacity(0.38)
            .frame(height: height * 0.48)
            .offset(y: height * 0.22)
            .blur(radius: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

private struct MetricsInsightGlowIcon: View {
    let systemName: String
    let tint: Color
    let reduceMotion: Bool

    var body: some View {
        Group {
            if reduceMotion {
                iconBody(pulse: 0.7)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 20)) { timeline in
                    let phase = timeline.date.timeIntervalSinceReferenceDate
                    let pulse = 0.45 + 0.35 * (sin(phase * 2 * .pi / 2.2) + 1) / 2
                    iconBody(pulse: pulse)
                }
            }
        }
    }

    private func iconBody(pulse: Double) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(tint)
            .shadow(color: tint.opacity(pulse), radius: 6)
            .frame(width: 22, height: 22)
    }
}

#Preview("Expense") {
    let localization = LocalizationManager()
    let currency = CurrencyManager()
    currency.lock(to: .USD)
    return BillListMetricsDetailSheet(
        kind: .expense,
        model: BillListMetricsDetailModel(
            necessaryTotal: 575.6,
            emotionalPremiumTotal: 6125,
            necessarySharePercent: 27,
            stabilityKey: .billsMetricDetailStabilityTrim,
            topExpenses: [],
            averageTicket: 0,
            averageTicketStyleKey: .billsMetricDetailAvgTicketSteady,
            peakTimeWindowText: nil,
            entryCount: 0
        ),
    )
    .environmentObject(localization)
    .environmentObject(currency)
}
