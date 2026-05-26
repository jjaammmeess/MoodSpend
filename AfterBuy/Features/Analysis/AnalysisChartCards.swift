import Charts
import SwiftUI

// MARK: - Chart emotion guide (shared sections)

enum AnalysisChartEmotionGuideLegend {
    static func customItems(in expenses: [TransactionRecord]) -> [MoodSpectrumCustomLegendItem] {
        MoodSpectrumLegend.customItems(in: expenses)
    }
}

struct ChartEmotionGuidePresetSection: View {
    @EnvironmentObject private var localization: LocalizationManager

    var showsOtherLegendRow: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localization.text(.homeMoodSpectrumGuidePresetSection))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            ForEach(EmotionTag.allCases) { tag in
                HStack(spacing: 10) {
                    Circle()
                        .fill(tag.color)
                        .frame(width: 10, height: 10)
                    Text(localization.text(tag.key))
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer(minLength: 0)
                }
            }

            if showsOtherLegendRow {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(hex: "8A96A0"))
                        .frame(width: 10, height: 10)
                    Text(localization.text(.analysisHeatRingOther))
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer(minLength: 0)
                }
            }

            Text(localization.text(.homeMoodSpectrumGuidePresetHint))
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ChartEmotionGuideCustomSection: View {
    @EnvironmentObject private var localization: LocalizationManager

    let items: [MoodSpectrumCustomLegendItem]
    var customNoteKey: LKey = .homeMoodSpectrumGuideCustomNote

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localization.text(.homeMoodSpectrumGuideCustomSection))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            ForEach(items) { item in
                HStack(spacing: 10) {
                    Circle()
                        .strokeBorder(item.color, lineWidth: 1.5)
                        .background(Circle().fill(item.color.opacity(0.35)))
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.displayName)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                        Text(customMetricsText(for: item))
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                            .monospacedDigit()
                    }
                    Spacer(minLength: 0)
                }
            }

            Text(localization.text(customNoteKey))
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func customMetricsText(for item: MoodSpectrumCustomLegendItem) -> String {
        let money = AppFormatter.moneyString(from: item.totalAmount, locale: localization.locale)
        return String(
            format: localization.text(.homeMoodSpectrumGuideCustomMetrics),
            locale: localization.locale,
            arguments: ["\(item.entryCount)", money] as [CVarArg]
        )
    }
}

struct ChartEmotionGuideReadingSection: View {
    let titleKey: LKey
    let bodyKey: LKey

    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localization.text(titleKey))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            Text(localization.text(bodyKey))
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Mood heat ring guide sheet

struct MoodHeatRingGuideSheet: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let periodExpenses: [TransactionRecord]

    private var customLegendItems: [MoodSpectrumCustomLegendItem] {
        AnalysisChartEmotionGuideLegend.customItems(in: periodExpenses)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                guideContentCard
                    .padding(20)
            }
            .background(AppTheme.pageBackground)
            .navigationTitle(localization.text(.analysisHeatRingGuideTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.text(.commonDone)) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var guideContentCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(localization.text(.analysisHeatRingGuideOverview))
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            heatRingGuideSection(
                title: localization.text(.analysisHeatRingGuideSectionRing),
                body: localization.text(.analysisHeatRingGuideRingBody)
            )

            heatRingGuideSection(
                title: localization.text(.analysisHeatRingGuideSectionChips),
                body: localization.text(.analysisHeatRingGuideChipsBody)
            )

            heatRingGuideSection(
                title: localization.text(.analysisHeatRingGuideSectionTopEmotions),
                body: localization.text(.analysisHeatRingGuideTopEmotionsBody)
            )

            ChartEmotionGuidePresetSection(showsOtherLegendRow: true)

            if !customLegendItems.isEmpty {
                ChartEmotionGuideCustomSection(
                    items: customLegendItems,
                    customNoteKey: .analysisChartGuideCustomNote
                )
            }

            ChartEmotionGuideReadingSection(
                titleKey: .analysisHeatRingGuideReadingTitle,
                bodyKey: .analysisHeatRingGuideReadingBody
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            DashboardWatercolorBackground(palette: .emotion)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.metricDashboardCornerRadius, style: .continuous))
    }

    private func heatRingGuideSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            Text(body)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Mood heat ring (amount-share nebula + legend grid)

struct AnalysisChartLoadingPlaceholder: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .accessibilityLabel(Text("Loading"))
    }
}

struct MoodHeatRingCard: View {
    @EnvironmentObject private var localization: LocalizationManager

    let periodExpenses: [TransactionRecord]
    let slices: [AnalysisChartMetrics.HeatRingSlice]
    let totalAmount: Double
    let totalCount: Int
    var showsLoading: Bool = false

    @State private var showGuide = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localization.text(.analysisHeatRingTitle))
                        .font(.headline)
                    Text(localization.text(.analysisHeatRingSubtitle))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    showGuide = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.72))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(localization.text(.analysisHeatRingGuideOpenA11yLabel)))
                .accessibilityHint(Text(localization.text(.analysisHeatRingGuideOpenA11yHint)))
            }

            if showsLoading {
                AnalysisChartLoadingPlaceholder()
            } else if slices.isEmpty {
                EmptyStateBlock(
                    title: localization.text(.commonNoData),
                    hint: localization.text(.analysisDistributionEmptyHint),
                    systemImage: "circle.circle"
                )
            } else {
                EmotionNebulaView(
                    slices: displaySlices,
                    totalAmount: totalAmount,
                    totalCount: totalCount
                )
                .frame(height: 220)

                heatRingLegendGrid
            }
        }
        .appCardStyle()
        .sheet(isPresented: $showGuide) {
            MoodHeatRingGuideSheet(periodExpenses: periodExpenses)
                .environmentObject(localization)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var heatRingLegendGrid: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            LazyVGrid(
                columns: HeatRingLegendLayout.gridColumns,
                alignment: .leading,
                spacing: HeatRingLegendLayout.rowSpacing
            ) {
                ForEach(displaySlices) { slice in
                    HeatRingLegendChip(
                        slice: slice,
                        totalAmount: totalAmount
                    )
                    .environmentObject(localization)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(width: HeatRingLegendLayout.gridContentWidth, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.top, HeatRingLegendLayout.topPadding)
        .padding(.bottom, 4)
    }

    private var displaySlices: [AnalysisChartMetrics.HeatRingSlice] {
        slices.map { slice in
            if slice.id == AnalysisChartMetrics.heatRingOtherKey {
                let otherTitle = localization.text(.analysisHeatRingOther)
                return AnalysisChartMetrics.HeatRingSlice(
                    id: slice.id,
                    title: otherTitle,
                    accessibilityTitle: otherTitle,
                    color: slice.color,
                    amount: slice.amount,
                    count: slice.count
                )
            }
            return slice
        }
    }

}

// MARK: - Heat ring legend layout

private enum HeatRingLegendLayout {
    /// Fixed content width so the two-column block centers under the nebula ring.
    static let gridContentWidth: CGFloat = 280
    static let columnSpacing: CGFloat = 16
    static let rowSpacing: CGFloat = 12
    static let topPadding: CGFloat = 16

    static var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: columnSpacing, alignment: .leading),
            GridItem(.flexible(), spacing: columnSpacing, alignment: .leading),
        ]
    }
}

// MARK: - Heat ring legend item (gallery grid)

private struct HeatRingLegendChip: View {
    @EnvironmentObject private var localization: LocalizationManager

    let slice: AnalysisChartMetrics.HeatRingSlice
    let totalAmount: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Circle()
                    .fill(slice.color)
                    .frame(width: 8, height: 8)
                HStack(spacing: 0) {
                    Text(slice.title)
                    Text("  \(amountShare)%")
                        .monospacedDigit()
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
            }

            Text(secondaryLine)
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var amountShare: Int {
        EmotionShareCalculator.sharePercent(amount: slice.amount, total: totalAmount)
    }

    private var moneyText: String {
        AppFormatter.moneyString(from: slice.amount, locale: localization.locale)
    }

    private var secondaryLine: String {
        let countLabel = String(
            format: localization.text(.analysisHeatRingChipTxnCount),
            locale: localization.locale,
            String(slice.count)
        )
        return String(
            format: localization.text(.analysisHeatRingChipSecondary),
            locale: localization.locale,
            countLabel,
            moneyText
        )
    }

    private var accessibilityText: String {
        String(
            format: localization.text(.analysisHeatRingChipA11y),
            locale: localization.locale,
            arguments: [
                slice.accessibilityTitle,
                String(slice.count),
                moneyText,
                String(amountShare)
            ] as [CVarArg]
        )
    }
}

// MARK: - Emotion nebula (amount-driven diffuse chart)

private struct EmotionNebulaBlob: Identifiable {
    let id: String
    let color: Color
    let title: String
    let amountShare: Double
    let normalizedCenter: CGPoint
    let diameter: CGFloat
    let blurRadius: CGFloat
    let opacity: Double
    let phase: Double
    let isDominant: Bool
}

private enum EmotionNebulaLayout {
    static let containerSize: CGFloat = 220
    private static let goldenAngleRadians = 137.5 * .pi / 180
    private static let coreCenterPushPoints: CGFloat = 8
    static let coreAmountShareThreshold = 0.15

    private static func boostedOpacity(_ base: Double) -> Double {
        min(1, base * 1.1)
    }

    private static func centerPushedFromMiddle(
        _ center: CGPoint,
        extraPoints: CGFloat
    ) -> CGPoint {
        let dx = center.x - 0.5
        let dy = center.y - 0.5
        let distance = sqrt(dx * dx + dy * dy)
        let angle: Double = distance < 0.001 ? -3 * Double.pi / 4 : atan2(dy, dx)
        let delta = extraPoints / containerSize
        return CGPoint(
            x: center.x + CGFloat(cos(angle) * delta),
            y: center.y + CGFloat(sin(angle) * delta)
        )
    }

    static func blobs(
        from slices: [AnalysisChartMetrics.HeatRingSlice],
        totalAmount: Double,
        totalCount: Int
    ) -> [EmotionNebulaBlob] {
        guard totalAmount > 0, !slices.isEmpty else { return [] }

        let sorted = slices.sorted { $0.amount > $1.amount }

        return sorted.enumerated().map { index, slice in
            let amountShare = slice.amount / totalAmount
            let countShare = totalCount > 0 ? Double(slice.count) / Double(totalCount) : 0
            let isDominant = index == 0
            let isCoreAccent = isDominant || amountShare >= coreAmountShareThreshold

            let diameter: CGFloat
            let center: CGPoint
            let blur: CGFloat
            let opacity: Double

            if isDominant {
                let dominantScale = 0.78 + 0.2 * sqrt(amountShare)
                diameter = containerSize * CGFloat(min(0.98, dominantScale))
                center = centerPushedFromMiddle(CGPoint(x: 0.5, y: 0.52), extraPoints: coreCenterPushPoints)
                blur = 36
                opacity = boostedOpacity(0.92)
            } else {
                let satelliteIndex = index - 1
                let angle = -Double.pi / 2 + goldenAngleRadians * Double(satelliteIndex + 1)
                var orbit = 0.36 + 0.03 * Double(satelliteIndex % 2)
                if amountShare >= coreAmountShareThreshold {
                    orbit += Double(coreCenterPushPoints + 2) / Double(containerSize)
                }
                let rawCenter = CGPoint(
                    x: 0.5 + orbit * cos(angle),
                    y: 0.5 + orbit * sin(angle)
                )
                center = isCoreAccent
                    ? centerPushedFromMiddle(rawCenter, extraPoints: coreCenterPushPoints)
                    : rawCenter
                if amountShare < 0.02 {
                    diameter = containerSize * 0.2
                } else {
                    diameter = containerSize * CGFloat(0.22 + 0.3 * sqrt(amountShare))
                }
                blur = amountShare < 0.05 ? 28 : 32
                let baseOpacity = 0.72 + 0.2 * countShare
                opacity = isCoreAccent ? boostedOpacity(baseOpacity) : baseOpacity
            }

            return EmotionNebulaBlob(
                id: slice.id,
                color: slice.color,
                title: slice.title,
                amountShare: amountShare,
                normalizedCenter: center,
                diameter: diameter,
                blurRadius: blur,
                opacity: opacity,
                phase: Double(index) / Double(max(sorted.count, 1)),
                isDominant: isDominant
            )
        }
    }

    static func accessibilitySummary(blobs: [EmotionNebulaBlob], locale: Locale) -> String {
        guard let top = blobs.max(by: { $0.amountShare < $1.amountShare }) else { return "" }
        let pct = Int((top.amountShare * 100).rounded())
        if locale.identifier.lowercased().hasPrefix("zh") {
            return "情绪星云，金额最高为\(top.title)，占\(pct)%"
        }
        return "Emotion nebula, top mood \(top.title), \(pct)% of spend"
    }
}

private struct EmotionNebulaView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.analysisChartMotionMode) private var chartMotionMode
    @Environment(\.colorScheme) private var colorScheme

    let slices: [AnalysisChartMetrics.HeatRingSlice]
    let totalAmount: Double
    let totalCount: Int

    @State private var entranceOpacity: Double = 1

    private var blobs: [EmotionNebulaBlob] {
        EmotionNebulaLayout.blobs(from: slices, totalAmount: totalAmount, totalCount: totalCount)
    }

    private var usesLiveTimeline: Bool {
        !reduceMotion && chartMotionMode == .live
    }

    var body: some View {
        Group {
            if usesLiveTimeline {
                TimelineView(.animation(minimumInterval: 1.0 / 20)) { timeline in
                    nebulaContent(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                nebulaContent(time: 0)
            }
        }
        .frame(width: EmotionNebulaLayout.containerSize, height: EmotionNebulaLayout.containerSize)
        .frame(maxWidth: .infinity)
        .opacity(entranceOpacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            EmotionNebulaLayout.accessibilitySummary(blobs: blobs, locale: .current)
        )
        .onAppear { playEntrance() }
        .onChange(of: slices.map(\.id)) { _, _ in playEntrance() }
        .onChange(of: chartMotionMode) { _, mode in
            if mode == .suspended {
                suspendEntrance()
            }
        }
    }

    private var nebulaCanvasGradient: RadialGradient {
        if colorScheme == .dark {
            return RadialGradient(
                colors: [Color(hex: "2A3238"), Color(hex: "1A2024")],
                center: .center,
                startRadius: 8,
                endRadius: EmotionNebulaLayout.containerSize * 0.55
            )
        }
        return RadialGradient(
            colors: [Color(hex: "EEF1F4"), Color(hex: "D8DEE3")],
            center: .center,
            startRadius: 6,
            endRadius: EmotionNebulaLayout.containerSize * 0.58
        )
    }

    private func nebulaContent(time: TimeInterval) -> some View {
        ZStack {
            Circle()
                .fill(nebulaCanvasGradient)

            ZStack {
                ForEach(blobs) { blob in
                    nebulaBlob(blob, time: time)
                }
            }
            .compositingGroup()
            .clipShape(Circle())

            frostedGlassLens(time: time)
        }
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func nebulaBlob(_ blob: EmotionNebulaBlob, time: TimeInterval) -> some View {
        let breathPeriod = blob.isDominant ? 5.2 : 4.4
        let scaleAmplitude = blob.isDominant ? 0.18 : 0.14
        let scale = 1 + scaleAmplitude * sin(time * 2 * .pi / breathPeriod + blob.phase * .pi * 2)

        let rotationSpeed = blob.isDominant ? 16.0 : 22.0
        let rotation = Angle.degrees(time * rotationSpeed + blob.phase * 48)

        let driftRadius: CGFloat = blob.isDominant ? 14 : 10
        let driftX = driftRadius * CGFloat(cos(time * 0.62 + blob.phase * 5.2))
        let driftY = driftRadius * CGFloat(sin(time * 0.52 + blob.phase * 4.4))

        let blurPulse = blob.blurRadius + (blob.isDominant ? 6 : 4) * CGFloat(sin(time * 0.82 + blob.phase * 3))
        let opacityPulse = blob.opacity * (0.88 + 0.12 * sin(time * 0.78 + blob.phase * 2.6))

        let size = EmotionNebulaLayout.containerSize
        let offsetX = (blob.normalizedCenter.x - 0.5) * size + driftX
        let offsetY = (blob.normalizedCenter.y - 0.5) * size + driftY

        Circle()
            .fill(blob.color.opacity(blobFillOpacity(blob)))
            .frame(width: blob.diameter, height: blob.diameter)
            .blur(radius: blurPulse)
            .opacity(opacityPulse)
            .scaleEffect(scale)
            .rotationEffect(rotation)
            .offset(x: offsetX, y: offsetY)
    }

    private func frostedGlassLens(time: TimeInterval) -> some View {
        let glassBreathPeriod = 4.5
        let breathScale = 0.99 + 0.06 * sin(time * 2 * .pi / glassBreathPeriod)
        let baseOpacity = colorScheme == .dark ? 0.45 : 0.5
        let lensOpacity = baseOpacity * (0.88 + 0.12 * sin(time * 2 * .pi / glassBreathPeriod + .pi / 3))

        return Circle()
            .fill(.clear)
            .frame(width: EmotionNebulaLayout.containerSize * 0.36)
            .background(.ultraThinMaterial, in: Circle())
            .opacity(lensOpacity)
            .scaleEffect(breathScale)
    }

    private func blobFillOpacity(_ blob: EmotionNebulaBlob) -> Double {
        let isCore = blob.isDominant || blob.amountShare >= EmotionNebulaLayout.coreAmountShareThreshold
        let base = blob.isDominant ? 0.95 : 0.88
        return isCore ? min(1, base * 1.1) : base
    }

    private func suspendEntrance() {
        entranceOpacity = 1
    }

    private func playEntrance() {
        guard !reduceMotion else {
            entranceOpacity = 1
            return
        }
        guard chartMotionMode == .live else {
            entranceOpacity = 1
            return
        }
        entranceOpacity = 0.01
        withAnimation(.easeOut(duration: 0.65)) {
            entranceOpacity = 1
        }
    }
}

// MARK: - Price–mood correlation (normalized dual series)

struct MoodCorrelationCard: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.analysisChartMotionMode) private var chartMotionMode

    let points: [AnalysisChartMetrics.CorrelationDayPoint]
    let warmTip: String
    let periodMode: PeriodMode
    var showsLoading: Bool = false
    var chartContentOpacity: Double = 1
    let onOpenBucket: (Date) -> Void

    @State private var rawXSelection: Date?
    @State private var drawProgress: CGFloat = 1
    @State private var showGuide = false
    @State private var drawAnimationTask: Task<Void, Never>?

    private var snappedPoint: AnalysisChartMetrics.CorrelationDayPoint? {
        guard let raw = rawXSelection, !points.isEmpty else { return nil }
        return points.min(by: {
            abs($0.bucketStart.timeIntervalSince(raw)) < abs($1.bucketStart.timeIntervalSince(raw))
        })
    }

    private var correlationXTickDates: [Date] {
        AnalysisChartMetrics.correlationXAxisTickDates(points: points, period: periodMode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            correlationHeaderRow

            if showsLoading {
                AnalysisChartLoadingPlaceholder()
            } else if points.isEmpty {
                EmptyStateBlock(
                    title: localization.text(.commonNoData),
                    hint: localization.text(.analysisCorrelationEmptyHint),
                    systemImage: "chart.xyaxis.line"
                )
            } else {
                Group {
                    correlationChart

                    HStack(spacing: 14) {
                        legendLine(color: AppTheme.actionBlue, title: localization.text(.analysisCorrelationLegendExpense))
                        legendLine(color: AppTheme.accentInsight.opacity(0.5), title: localization.text(.analysisCorrelationLegendNegativity))
                    }
                }
                .opacity(chartContentOpacity)

                if let p = snappedPoint {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(bucketSummary(for: p))
                            .font(.caption)
                            .foregroundStyle(AppTheme.textPrimary)

                        HStack(spacing: 10) {
                            Button {
                                onOpenBucket(p.bucketStart)
                            } label: {
                                Text(localization.text(.analysisCorrelationOpenList))
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(AppTheme.actionBlue.opacity(0.14))
                                    .foregroundStyle(AppTheme.actionBlue)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Button {
                                rawXSelection = nil
                            } label: {
                                Text(localization.text(.analysisCorrelationClearSelection))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .appCardStyle()
        .sheet(isPresented: $showGuide) {
            MoodCorrelationGuideSheet(warmTip: warmTip)
                .environmentObject(localization)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear { scheduleDrawAnimationIfVisible() }
        .onChange(of: points.map(\.id)) { _, _ in
            rawXSelection = nil
            scheduleDrawAnimationIfVisible()
        }
        .onChange(of: chartContentOpacity) { _, newOpacity in
            if newOpacity >= 0.98 {
                scheduleDrawAnimationIfVisible()
            }
        }
        .onChange(of: rawXSelection) { _, newValue in
            snapSelectionToNearestBucket(newValue)
        }
        .onDisappear {
            drawAnimationTask?.cancel()
        }
        .onChange(of: chartMotionMode) { _, mode in
            if mode == .suspended {
                suspendDrawAnimation()
            }
        }
    }

    private var correlationHeaderRow: some View {
        HStack(alignment: .top, spacing: 4) {
            VStack(alignment: .leading, spacing: 4) {
                Text(localization.text(.analysisCorrelationTitle))
                    .font(.headline)
                Text(localization.text(.analysisCorrelationSubtitle))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                showGuide = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.72))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(localization.text(.analysisCorrelationGuideOpenA11yLabel)))
            .accessibilityHint(Text(localization.text(.analysisCorrelationGuideOpenA11yHint)))
        }
    }

    private var correlationChart: some View {
        Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Day", point.bucketStart),
                    y: .value("Neg", drawProgress * point.negativityNormalized)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            AppTheme.accentInsight.opacity(0.32),
                            AppTheme.accentInsight.opacity(0.06)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            ForEach(points) { point in
                LineMark(
                    x: .value("Day", point.bucketStart),
                    y: .value("Spend", drawProgress * point.expenseNormalized)
                )
                .foregroundStyle(AppTheme.actionBlue)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.catmullRom)
            }
            if let p = snappedPoint {
                RuleMark(x: .value("Sel", p.bucketStart))
                    .foregroundStyle(AppTheme.actionBlue.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
            }
        }
        .chartYScale(domain: 0...1)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 0.5, 1]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int((v * 100).rounded()))%")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: correlationXTickDates) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(correlationXAxisLabel(for: date))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
        }
        .padding(.top, 8)
        .frame(height: 228)
        .chartPlotStyle { plot in
            plot.background(AppTheme.cardBackground.opacity(0.35))
        }
        .drawingGroup(opaque: false)
        .chartOverlay { proxy in
            chartPlotInteractionOverlay(proxy: proxy)
        }
    }

    private func correlationXAxisLabel(for date: Date) -> String {
        guard let point = points.min(by: {
            abs($0.bucketStart.timeIntervalSince(date)) < abs($1.bucketStart.timeIntervalSince(date))
        }) else { return "" }
        return point.axisLabel
    }

    @ViewBuilder
    private func chartPlotInteractionOverlay(proxy: ChartProxy) -> some View {
        GeometryReader { geometry in
            if let plotFrame = proxy.plotFrame {
                let plot = geometry[plotFrame]
                CorrelationChartPlotInteractionView(
                    plotRect: plot,
                    onSelectPlotX: { x, width in
                        selectBucket(atPlotX: x, plotWidth: width, proxy: proxy)
                    }
                )
            }
        }
    }

    private func selectBucket(atPlotX xInPlot: CGFloat, plotWidth: CGFloat, proxy: ChartProxy) {
        guard !points.isEmpty, plotWidth > 0 else { return }
        let clamped = min(max(0, xInPlot), plotWidth)
        guard let rawDate: Date = proxy.value(atX: clamped, as: Date.self) else { return }
        guard let best = points.min(by: {
            abs($0.bucketStart.timeIntervalSince(rawDate)) < abs($1.bucketStart.timeIntervalSince(rawDate))
        }) else { return }
        rawXSelection = best.bucketStart
    }

    private func snapSelectionToNearestBucket(_ date: Date?) {
        guard let date, !points.isEmpty else { return }
        guard let best = points.min(by: {
            abs($0.bucketStart.timeIntervalSince(date)) < abs($1.bucketStart.timeIntervalSince(date))
        }) else { return }
        if rawXSelection != best.bucketStart {
            rawXSelection = best.bucketStart
        }
    }

    private func bucketTitle(for point: AnalysisChartMetrics.CorrelationDayPoint) -> String {
        switch periodMode {
        case .year:
            let df = DateFormatter()
            df.locale = localization.locale
            df.setLocalizedDateFormatFromTemplate("yMMMM")
            return df.string(from: point.bucketStart)
        default:
            return AppFormatter.dayString(from: point.bucketStart, locale: localization.locale)
        }
    }

    private func bucketSummary(for point: AnalysisChartMetrics.CorrelationDayPoint) -> String {
        let money = AppFormatter.moneyString(from: point.totalExpense, locale: localization.locale)
        let pct = Int((point.negativityNormalized * 100).rounded())
        return String(
            format: localization.text(.analysisCorrelationBucketSummary),
            locale: localization.locale,
            arguments: [bucketTitle(for: point), money, "\(point.billCount)", "\(pct)"]
        )
    }

    private func legendLine(color: Color, title: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 14, height: 3)
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func scheduleDrawAnimationIfVisible() {
        guard chartContentOpacity >= 0.98 else { return }
        animateDraw()
    }

    private func suspendDrawAnimation() {
        drawAnimationTask?.cancel()
        drawProgress = 1
    }

    private func animateDraw() {
        drawAnimationTask?.cancel()
        guard !reduceMotion else {
            drawProgress = 1
            return
        }
        guard chartMotionMode == .live else {
            drawProgress = 1
            return
        }
        drawProgress = 0
        drawAnimationTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            withAnimation(.timingCurve(0.22, 0.0, 0.12, 1.0, duration: 0.72)) {
                drawProgress = 1
            }
        }
    }

}

// MARK: - Correlation guide sheet

private struct MoodCorrelationGuideSheet: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let warmTip: String

    var body: some View {
        NavigationStack {
            ScrollView {
                guideContentCard
                    .padding(20)
            }
            .background(AppTheme.pageBackground)
            .navigationTitle(localization.text(.analysisCorrelationGuideTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.text(.commonDone)) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var guideContentCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                correlationGuideLegendRow(
                    lineColor: AppTheme.actionBlue,
                    areaColor: AppTheme.accentInsight.opacity(0.35),
                    title: localization.text(.analysisCorrelationLegendExpense)
                )
                correlationGuideLegendRow(
                    lineColor: AppTheme.accentInsight.opacity(0.55),
                    areaColor: AppTheme.accentInsight.opacity(0.2),
                    title: localization.text(.analysisCorrelationLegendNegativity)
                )
            }

            guideSection(
                title: localization.text(.analysisCorrelationGuideSectionRead),
                body: localization.text(.analysisCorrelationHowToRead)
            )

            guideSection(
                title: localization.text(.analysisCorrelationGuideSectionInteract),
                body: localization.text(.analysisCorrelationSelectHint)
            )

            if !warmTip.isEmpty {
                guideSection(
                    title: localization.text(.analysisCorrelationGuideSectionInsight),
                    body: warmTip,
                    emphasized: true
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            DashboardWatercolorBackground(palette: .spending)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.metricDashboardCornerRadius, style: .continuous))
    }

    private func guideSection(title: String, body: String, emphasized: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            Text(body)
                .font(.system(size: emphasized ? 14 : 13, weight: emphasized ? .medium : .regular))
                .foregroundStyle(emphasized ? AppTheme.textPrimary : AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(emphasized ? 12 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    if emphasized {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppTheme.actionBlue.opacity(0.08))
                    }
                }
        }
    }

    private func correlationGuideLegendRow(lineColor: Color, areaColor: Color, title: String) -> some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(areaColor)
                    .frame(width: 28, height: 14)
                RoundedRectangle(cornerRadius: 1)
                    .fill(lineColor)
                    .frame(width: 28, height: 3)
                    .offset(y: -4)
            }
            .frame(width: 28, height: 14)

            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Heatmap guide sheet

struct EmotionHeatmapGuideSheet: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let periodExpenses: [TransactionRecord]

    private var customLegendItems: [MoodSpectrumCustomLegendItem] {
        AnalysisChartEmotionGuideLegend.customItems(in: periodExpenses)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                guideContentCard
                    .padding(20)
            }
            .background(AppTheme.pageBackground)
            .navigationTitle(localization.text(.analysisHeatmapGuideTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.text(.commonDone)) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var guideContentCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            heatmapGuideSection(
                title: localization.text(.analysisHeatmapGuideSectionColor),
                body: localization.text(.analysisHeatmapGuideColorRule)
            )

            heatmapGuideSection(
                title: localization.text(.analysisHeatmapGuideSectionSize),
                body: localization.text(.analysisHeatmapGuideSizeRule)
            )

            heatmapGuideSection(
                title: localization.text(.analysisHeatmapGuideSectionMeasure),
                body: localization.text(.analysisHeatmapGuideMeasureRule)
            )

            ChartEmotionGuidePresetSection()

            if !customLegendItems.isEmpty {
                ChartEmotionGuideCustomSection(
                    items: customLegendItems,
                    customNoteKey: .analysisChartGuideCustomNote
                )
            }

            ChartEmotionGuideReadingSection(
                titleKey: .analysisHeatmapGuideReadingTitle,
                bodyKey: .analysisHeatmapGuideReadingBody
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            DashboardWatercolorBackground(palette: .emotion)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.metricDashboardCornerRadius, style: .continuous))
    }

    private func heatmapGuideSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            Text(body)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Emotional spectrum guide sheet

struct EmotionSpectrumGuideSheet: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let periodMode: PeriodMode
    let periodExpenses: [TransactionRecord]

    private var customLegendItems: [MoodSpectrumCustomLegendItem] {
        AnalysisChartEmotionGuideLegend.customItems(in: periodExpenses)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                guideContentCard
                    .padding(20)
            }
            .background(AppTheme.pageBackground)
            .navigationTitle(localization.text(.analysisSpectrumGuideTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.text(.commonDone)) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var guideContentCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            spectrumGuideSection(
                title: localization.text(.analysisSpectrumGuideSectionChart),
                body: localization.text(.analysisSpectrumGuideChartBody)
            )

            spectrumGuideSection(
                title: localization.text(.analysisSpectrumGuideSectionEmptyBars),
                body: localization.text(.analysisSpectrumGuideEmptyBarsBody)
            )

            spectrumGuideSection(
                title: localization.text(.analysisSpectrumGuideSectionStrokeHeight),
                body: localization.text(.analysisSpectrumGuideStrokeHeightBody)
            )

            VStack(alignment: .leading, spacing: 10) {
                Text(localization.text(.analysisSpectrumGuideSectionPeriod))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                Text(localization.text(periodBodyKey))
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ChartEmotionGuidePresetSection()

            if !customLegendItems.isEmpty {
                ChartEmotionGuideCustomSection(
                    items: customLegendItems,
                    customNoteKey: .analysisChartGuideCustomNote
                )
            }

            ChartEmotionGuideReadingSection(
                titleKey: .analysisSpectrumGuideReadingTitle,
                bodyKey: .analysisSpectrumGuideReadingBody
            )

            spectrumGuideSection(
                title: localization.text(.analysisSpectrumGuideSectionInsight),
                body: localization.text(.analysisSpectrumGuideInsightBody)
            )

            Text(localization.text(.analysisSpectrumGuideHomeContrast))
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            DashboardWatercolorBackground(palette: .spectrum)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.metricDashboardCornerRadius, style: .continuous))
    }

    private var periodBodyKey: LKey {
        switch periodMode {
        case .day: return .analysisSpectrumGuidePeriodDay
        case .week: return .analysisSpectrumGuidePeriodWeek
        case .month: return .analysisSpectrumGuidePeriodMonth
        case .year: return .analysisSpectrumGuidePeriodYear
        case .custom: return .analysisSpectrumGuidePeriodCustom
        }
    }

    private func spectrumGuideSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            Text(body)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Emotion spending trend chart

struct EmotionTrendChartSegment: Identifiable {
    let id: String
    let color: Color
    let yStart: Double
    let yEnd: Double
}

struct EmotionTrendChartBucket: Identifiable {
    let id: String
    let label: String
    let segments: [EmotionTrendChartSegment]

    var hasData: Bool { !segments.isEmpty }
}

struct EmotionTrendAnimatedChart: View {
    let buckets: [EmotionTrendChartBucket]
    let yAxisTicks: [Double]
    let yAxisTop: Double
    let stackGap: Double
    let xAxisTickLabels: Set<String>
    let chartScopeID: String
    let dataSignature: String
    let animationEpoch: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.analysisChartMotionMode) private var chartMotionMode
    @State private var revealedBucketIDs: Set<String> = []
    @State private var revealGeneration = 0

    private let chartHeight: CGFloat = 220
    private let plotHeight: CGFloat = 198
    private let yAxisWidth: CGFloat = 34
    private let barWidthRatio: CGFloat = 0.52
    private let baseStaggerStep: Double = 0.032
    private let compactStaggerStep: Double = 0.02
    private let compactStaggerThreshold = 12

    private var revealKey: String {
        "\(chartScopeID)|\(dataSignature)|\(animationEpoch)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            yAxisLabels
            chartPlot
        }
        .frame(height: chartHeight)
        .frame(maxWidth: .infinity)
        .onAppear { playEntrance() }
        .onChange(of: revealKey) { _, _ in
            playEntrance()
        }
        .onChange(of: chartMotionMode) { _, mode in
            if mode == .suspended {
                suspendEntrance()
            }
        }
    }

    private var chartPlot: some View {
        GeometryReader { geometry in
            let columnCount = CGFloat(max(buckets.count, 1))
            let slotWidth = geometry.size.width / columnCount

            ZStack(alignment: .topLeading) {
                ForEach(yAxisTicks, id: \.self) { tick in
                    if tick > 0 {
                        Rectangle()
                            .fill(Color.primary.opacity(0.04))
                            .frame(width: geometry.size.width, height: 1)
                            .offset(y: yOffset(for: tick))
                    }
                }

                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(buckets) { bucket in
                        bucketColumn(bucket, slotWidth: slotWidth)
                    }
                }
                .frame(width: geometry.size.width, height: plotHeight, alignment: .bottom)
            }
        }
        .frame(height: plotHeight)
        .frame(maxWidth: .infinity)
    }

    private var yAxisLabels: some View {
        ZStack(alignment: .topLeading) {
            ForEach(yAxisTicks, id: \.self) { tick in
                Text("\(Int(tick.rounded()))")
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                    .offset(y: max(0, yOffset(for: tick) - 7))
            }
        }
        .frame(width: yAxisWidth, height: plotHeight, alignment: .topLeading)
    }

    @ViewBuilder
    private func bucketColumn(_ bucket: EmotionTrendChartBucket, slotWidth: CGFloat) -> some View {
        let barWidth = max(2, slotWidth * barWidthRatio)
        let revealed = isBucketRevealed(bucket.id)
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                if bucket.hasData {
                    VStack(spacing: gapHeight) {
                        ForEach(bucket.segments.reversed()) { segment in
                            Capsule()
                                .fill(segment.color)
                                .frame(
                                    width: barWidth,
                                    height: revealed ? segmentHeight(segment) : 0
                                )
                        }
                    }
                    .frame(width: slotWidth, height: plotHeight, alignment: .bottom)
                } else {
                    Color.clear
                        .frame(width: slotWidth, height: plotHeight)
                }
            }

            if xAxisTickLabels.contains(bucket.label) {
                Text(bucket.label)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            } else {
                Text(" ")
                    .font(.system(size: 10))
            }
        }
        .frame(width: slotWidth)
    }

    private var gapHeight: CGFloat {
        guard yAxisTop > 0 else { return 0 }
        return plotHeight * CGFloat(stackGap / yAxisTop)
    }

    private func yOffset(for tick: Double) -> CGFloat {
        guard yAxisTop > 0 else { return plotHeight }
        return plotHeight * (1 - CGFloat(tick / yAxisTop))
    }

    private func segmentHeight(_ segment: EmotionTrendChartSegment) -> CGFloat {
        guard yAxisTop > 0 else { return 0 }
        return plotHeight * CGFloat((segment.yEnd - segment.yStart) / yAxisTop)
    }

    private func isBucketRevealed(_ bucketID: String) -> Bool {
        reduceMotion || revealedBucketIDs.contains(bucketID)
    }

    private func snapEntranceToRevealed() {
        let dataBuckets = buckets.filter(\.hasData)
        revealedBucketIDs = Set(dataBuckets.map(\.id))
    }

    private func suspendEntrance() {
        revealGeneration += 1
        snapEntranceToRevealed()
    }

    private func playEntrance() {
        let dataBuckets = buckets.filter(\.hasData)
        guard !dataBuckets.isEmpty else {
            revealedBucketIDs = []
            return
        }
        guard !reduceMotion else {
            snapEntranceToRevealed()
            return
        }
        guard chartMotionMode == .live else {
            snapEntranceToRevealed()
            return
        }
        if buckets.count > 30 {
            snapEntranceToRevealed()
            return
        }

        revealGeneration += 1
        let generation = revealGeneration
        revealedBucketIDs = []

        let staggerStep = dataBuckets.count > compactStaggerThreshold
            ? compactStaggerStep
            : baseStaggerStep
        let stepNanoseconds = UInt64(staggerStep * 1_000_000_000)

        Task { @MainActor in
            await Task.yield()
            var isFirst = true
            for bucket in dataBuckets {
                guard generation == revealGeneration else { return }
                if !isFirst {
                    try? await Task.sleep(nanoseconds: stepNanoseconds)
                }
                isFirst = false
                guard generation == revealGeneration else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = false
                transaction.animation = .spring(response: 0.46, dampingFraction: 0.82)
                withTransaction(transaction) {
                    _ = revealedBucketIDs.insert(bucket.id)
                }
            }
        }
    }
}

// MARK: - Emotional spectrum

struct EmotionSpectrumCard: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.analysisChartMotionMode) private var chartMotionMode

    let periodMode: PeriodMode
    let periodExpenses: [TransactionRecord]
    let columns: [AnalysisChartMetrics.SpectrumBucketColumn]
    let insight: AnalysisChartMetrics.SpectrumInsight?
    var showsLoading: Bool = false
    /// Bumped when the analysis tab becomes visible (see `AnalysisView`).
    let animationEpoch: Int

    @State private var showGuide = false
    @State private var revealedColumnCount = 0
    @State private var spectrumRevealGeneration = 0

    private var titleKey: LKey {
        switch periodMode {
        case .day: return .analysisSpectrumTitleDay
        case .week: return .analysisSpectrumTitleWeek
        case .month: return .analysisSpectrumTitleMonth
        case .year: return .analysisSpectrumTitleYear
        case .custom: return .analysisSpectrumTitleCustom
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localization.text(titleKey))
                        .font(.headline)
                    Text(localization.text(.analysisSpectrumSubtitle))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    showGuide = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.72))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(localization.text(.analysisSpectrumGuideOpenA11yLabel)))
                .accessibilityHint(Text(localization.text(.analysisSpectrumGuideOpenA11yHint)))
            }

            if showsLoading {
                AnalysisChartLoadingPlaceholder()
            } else if columns.isEmpty {
                EmptyStateBlock(
                    title: localization.text(.commonNoData),
                    systemImage: "paintpalette"
                )
            } else {
                spectrumChart
                    .padding(.vertical, 4)

                if let insight {
                    SpectrumInsightPanel(tier: insight.tier, text: insight.text)
                }
            }
        }
        .appCardStyle()
        .sheet(isPresented: $showGuide) {
            EmotionSpectrumGuideSheet(periodMode: periodMode, periodExpenses: periodExpenses)
                .environmentObject(localization)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear { playSpectrumEntrance() }
        .onChange(of: spectrumRevealKey) { _, _ in
            playSpectrumEntrance()
        }
        .onChange(of: chartMotionMode) { _, mode in
            if mode == .suspended {
                suspendSpectrumEntrance()
            }
        }
    }

    private var columnsSignature: String {
        columns.map(\.id).joined(separator: "|")
    }

    /// Changes when column data or tab-replay epoch updates (period title can change independently).
    private var spectrumRevealKey: String {
        "\(columnsSignature)|\(animationEpoch)"
    }

    private let spectrumBarHeight: CGFloat = 72
    private let spectrumColumnStaggerStep: Double = 0.032
    private let spectrumColumnGap: CGFloat = 1
    private let spectrumMinAxisLabelSlotWidth: CGFloat = 10

    private struct SpectrumInsightPanel: View {
        let tier: AnalysisChartMetrics.SpectrumInsightTier
        let text: String

        var body: some View {
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary.opacity(foregroundOpacity))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    ZStack {
                        DashboardWatercolorBackground(
                            cornerRadius: 12,
                            palette: .spectrum,
                            layout: .metricDefault
                        )
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: overlayColors,
                                    center: UnitPoint(x: 0.1, y: 0.35),
                                    startRadius: 0,
                                    endRadius: 170
                                )
                            )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }

        private var foregroundOpacity: Double {
            switch tier {
            case .elevated: return 0.9
            case .balanced, .calm: return 0.82
            }
        }

        private var overlayColors: [Color] {
            switch tier {
            case .elevated:
                return [
                    AppTheme.accentInsight.opacity(0.16),
                    AppTheme.accentWarning.opacity(0.06),
                    Color.clear,
                ]
            case .balanced:
                return [
                    AppTheme.accentInsight.opacity(0.08),
                    AppTheme.accentSecondary.opacity(0.05),
                    Color.clear,
                ]
            case .calm:
                return [
                    AppTheme.accentSecondary.opacity(0.09),
                    AppTheme.accentInsight.opacity(0.04),
                    Color.clear,
                ]
            }
        }
    }

    private var spectrumChart: some View {
        GeometryReader { geometry in
            let columnCount = CGFloat(columns.count)
            let gapTotal = spectrumColumnGap * CGFloat(max(0, columns.count - 1))
            let slotWidth = max(2, (geometry.size.width - gapTotal) / max(columnCount, 1))

            HStack(alignment: .bottom, spacing: spectrumColumnGap) {
                ForEach(Array(columns.enumerated()), id: \.element.id) { columnIndex, column in
                    VStack(spacing: 4) {
                        spectrumColumn(column, slotWidth: slotWidth, columnIndex: columnIndex)
                            .frame(width: slotWidth, height: spectrumBarHeight, alignment: .bottom)

                        if let label = spectrumAxisLabel(for: column, slotWidth: slotWidth) {
                            Text(label)
                                .font(.system(size: 8))
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        } else {
                            Text(" ")
                                .font(.system(size: 8))
                        }
                    }
                    .frame(width: slotWidth)
                }
            }
            .frame(width: geometry.size.width, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: spectrumBarHeight + 16)
        /// Tab root disables implicit animations; opt this chart back in for the entrance.
        .transaction { transaction in
            transaction.disablesAnimations = false
        }
    }

    private func spectrumAxisLabel(
        for column: AnalysisChartMetrics.SpectrumBucketColumn,
        slotWidth: CGFloat
    ) -> String? {
        guard let label = column.axisLabel else { return nil }
        if slotWidth >= spectrumMinAxisLabelSlotWidth {
            return label
        }
        guard periodMode == .year else { return label }
        let week = column.bucketIndex
        if week == 1 || week == 26 || week == AnalysisChartMetrics.spectrumYearWeekCount {
            return label
        }
        return nil
    }

    private func spectrumStrokeWidth(strokeCount: Int, slotWidth: CGFloat) -> CGFloat {
        let inset: CGFloat = 1
        let available = max(2, slotWidth - inset)
        let innerGap: CGFloat = 1
        guard strokeCount > 1 else {
            return min(3, available * 0.65)
        }
        let totalGaps = CGFloat(strokeCount - 1) * innerGap
        return max(1, (available - totalGaps) / CGFloat(strokeCount))
    }

    @ViewBuilder
    private func spectrumColumn(
        _ column: AnalysisChartMetrics.SpectrumBucketColumn,
        slotWidth: CGFloat,
        columnIndex: Int
    ) -> some View {
        let barWidth = max(2, slotWidth - 1)
        let revealed = isColumnRevealed(columnIndex)
        if column.strokes.isEmpty {
            RoundedRectangle(cornerRadius: 2)
                .fill(AppTheme.divider)
                .frame(width: barWidth, height: spectrumBarHeight)
                .opacity(revealed ? 1 : 0)
        } else {
            let strokeWidth = spectrumStrokeWidth(strokeCount: column.strokes.count, slotWidth: slotWidth)
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(column.strokes) { stroke in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(stroke.color)
                        .frame(
                            width: strokeWidth,
                            height: revealed
                                ? targetStrokeHeight(for: stroke)
                                : 0
                        )
                }
            }
            .frame(width: slotWidth, height: spectrumBarHeight, alignment: .bottom)
        }
    }

    private func isColumnRevealed(_ columnIndex: Int) -> Bool {
        reduceMotion || columnIndex < revealedColumnCount
    }

    private func targetStrokeHeight(for stroke: AnalysisChartMetrics.SpectrumStroke) -> CGFloat {
        AnalysisChartMetrics.spectrumStrokeHeight(amount: stroke.amount, barHeight: spectrumBarHeight)
    }

    private func snapSpectrumEntranceToRevealed() {
        revealedColumnCount = columns.count
    }

    private func suspendSpectrumEntrance() {
        spectrumRevealGeneration += 1
        snapSpectrumEntranceToRevealed()
    }

    private func playSpectrumEntrance() {
        let columnCount = columns.count
        guard columnCount > 0 else {
            revealedColumnCount = 0
            return
        }
        guard !reduceMotion else {
            snapSpectrumEntranceToRevealed()
            return
        }
        guard chartMotionMode == .live else {
            snapSpectrumEntranceToRevealed()
            return
        }

        spectrumRevealGeneration += 1
        let generation = spectrumRevealGeneration
        revealedColumnCount = 0

        Task { @MainActor in
            await Task.yield()
            guard generation == spectrumRevealGeneration else { return }
            let stepNanoseconds = UInt64(spectrumColumnStaggerStep * 1_000_000_000)
            for index in columns.indices {
                guard generation == spectrumRevealGeneration else { return }
                if index > 0 {
                    try? await Task.sleep(nanoseconds: stepNanoseconds)
                }
                guard generation == spectrumRevealGeneration else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = false
                withAnimation(.spring(response: 0.46, dampingFraction: 0.82)) {
                    revealedColumnCount = index + 1
                }
            }
        }
    }
}

// MARK: - Regret quadrant guide sheet

struct RegretQuadrantGuideSheet: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let periodExpenses: [TransactionRecord]

    private var customLegendItems: [MoodSpectrumCustomLegendItem] {
        AnalysisChartEmotionGuideLegend.customItems(in: periodExpenses)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                guideContentCard
                    .padding(20)
            }
            .background(AppTheme.pageBackground)
            .navigationTitle(localization.text(.analysisRegretGuideTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.text(.commonDone)) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var guideContentCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            regretGuideSection(
                title: localization.text(.analysisRegretGuideSectionSource),
                body: localization.text(.analysisRegretGuideSourceBody)
            )

            regretGuideSection(
                title: localization.text(.analysisRegretGuideSectionAxes),
                body: localization.text(.analysisRegretGuideAxesBody)
            )

            VStack(alignment: .leading, spacing: 10) {
                Text(localization.text(.analysisRegretGuideSectionDotColor))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                VStack(alignment: .leading, spacing: 8) {
                    regretGuideLegendRow(
                        color: AppTheme.accentSecondary,
                        label: localization.text(.analysisRegretLegendWorthIt)
                    )
                    regretGuideLegendRow(
                        color: AppTheme.textSecondary,
                        label: localization.text(.analysisRegretLegendNeutral)
                    )
                    regretGuideLegendRow(
                        color: AppTheme.accentRisk,
                        label: localization.text(.analysisRegretLegendRegret)
                    )
                }
            }

            regretGuideSection(
                title: localization.text(.analysisRegretGuideSectionTags),
                body: localization.text(.analysisRegretGuideTagsBody)
            )

            ChartEmotionGuidePresetSection()

            if !customLegendItems.isEmpty {
                ChartEmotionGuideCustomSection(
                    items: customLegendItems,
                    customNoteKey: .analysisChartGuideCustomNote
                )
            }

            ChartEmotionGuideReadingSection(
                titleKey: .analysisRegretGuideReadingTitle,
                bodyKey: .analysisRegretGuideReadingBody
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            DashboardWatercolorBackground(palette: .spectrum)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.metricDashboardCornerRadius, style: .continuous))
    }

    private func regretGuideSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            Text(body)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func regretGuideLegendRow(color: Color, label: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color.opacity(0.85))
                .overlay {
                    Circle()
                        .stroke(.background, lineWidth: 1)
                }
                .frame(width: 12, height: 12)
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Regret quadrant

private struct RegretQuadrantScatterDot: View {
    let color: Color
    let phaseOffset: Double
    let animationTime: TimeInterval

    var body: some View {
        let breathing = 0.92 + 0.08 * sin(animationTime * 2 * .pi / 3.8 + phaseOffset)
        dotCircle(breathingScale: breathing)
    }

    private func dotCircle(breathingScale: CGFloat) -> some View {
        Circle()
            .fill(color.opacity(0.8))
            .frame(width: 12, height: 12)
            .scaleEffect(breathingScale)
            .blur(radius: 1)
    }
}

struct RegretQuadrantCard: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.analysisChartMotionMode) private var chartMotionMode

    let periodExpenses: [TransactionRecord]
    let points: [AnalysisChartMetrics.RegretQuadrantPoint]
    var onSelect: (UUID) -> Void

    @State private var appeared = false
    @State private var showGuide = false
    @State private var pickerPresentedGroupID: String?

    private var moodChipGroups: [AnalysisChartMetrics.RegretQuadrantMoodChipGroup] {
        AnalysisChartMetrics.regretQuadrantMoodChipGroups(from: points)
    }

    private var usesLiveTimeline: Bool {
        !reduceMotion && chartMotionMode == .live
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localization.text(.analysisRegretTitle))
                        .font(.headline)
                    Text(localization.text(.analysisRegretSubtitle))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    showGuide = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.72))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(localization.text(.analysisRegretGuideOpenA11yLabel)))
                .accessibilityHint(Text(localization.text(.analysisRegretGuideOpenA11yHint)))
            }

            if points.isEmpty {
                EmptyStateBlock(
                    title: localization.text(.commonNoData),
                    hint: localization.text(.analysisRegretEmpty),
                    systemImage: "square.grid.2x2"
                )
            } else {
                Group {
                    if usesLiveTimeline {
                        TimelineView(.animation(minimumInterval: 1.0 / 20)) { timeline in
                            regretQuadrantChart(
                                animationTime: timeline.date.timeIntervalSinceReferenceDate
                            )
                        }
                    } else {
                        regretQuadrantChart(animationTime: 0)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(moodChipGroups) { group in
                            regretMoodChip(group)
                        }
                    }
                }

                HStack(spacing: 12) {
                    regretLegendDot(color: AppTheme.accentSecondary, label: localization.text(.analysisRegretLegendWorthIt))
                    regretLegendDot(color: AppTheme.textSecondary, label: localization.text(.analysisRegretLegendNeutral))
                    regretLegendDot(color: AppTheme.accentRisk, label: localization.text(.analysisRegretLegendRegret))
                }
            }
        }
        .appCardStyle()
        .sheet(isPresented: $showGuide) {
            RegretQuadrantGuideSheet(periodExpenses: periodExpenses)
                .environmentObject(localization)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            playScatterEntrance()
        }
        .onChange(of: chartMotionMode) { _, mode in
            if mode == .suspended {
                appeared = true
            }
        }
    }

    private func playScatterEntrance() {
        guard !reduceMotion else {
            appeared = true
            return
        }
        guard chartMotionMode == .live else {
            appeared = true
            return
        }
        appeared = false
        withAnimation(.easeOut(duration: 0.75)) {
            appeared = true
        }
    }

    private func regretQuadrantChart(animationTime: TimeInterval) -> some View {
        Chart(points) { point in
            PointMark(
                x: .value("Value", appeared ? point.longTermValue : 0),
                y: .value("Joy", appeared ? point.instantJoy : 0)
            )
            .symbol {
                RegretQuadrantScatterDot(
                    color: point.feedbackColor,
                    phaseOffset: regretScatterPhaseOffset(for: point),
                    animationTime: animationTime
                )
            }
        }
        .chartXScale(domain: 0...1)
        .chartYScale(domain: 0...1)
        .chartXAxis {
            AxisMarks(values: [0.5]) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.primary.opacity(0.05))
            }
        }
        .chartYAxis {
            AxisMarks(values: [0.5]) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.primary.opacity(0.05))
            }
        }
        .frame(height: 220)
        .chartPlotStyle { plot in
            plot.background(Color.clear)
        }
    }

    private func regretScatterPhaseOffset(for point: AnalysisChartMetrics.RegretQuadrantPoint) -> Double {
        point.longTermValue * 4.1 + point.instantJoy * 2.6
    }

    private func regretLegendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    @ViewBuilder
    private func regretMoodChip(_ group: AnalysisChartMetrics.RegretQuadrantMoodChipGroup) -> some View {
        let chip = regretMoodChipLabel(group)
        if group.count == 1, let point = group.points.first {
            Button {
                onSelect(point.recordPublicId)
            } label: {
                chip
            }
            .buttonStyle(.plain)
        } else {
            Button {
                pickerPresentedGroupID = group.id
            } label: {
                chip
            }
            .buttonStyle(.plain)
            .popover(isPresented: chipPickerPresentedBinding(for: group)) {
                RegretQuadrantMoodChipPicker(
                    group: group,
                    onSelect: { recordPublicId in
                        pickerPresentedGroupID = nil
                        onSelect(recordPublicId)
                    }
                )
                .environmentObject(localization)
                .presentationCompactAdaptation(.popover)
            }
        }
    }

    private func chipPickerPresentedBinding(
        for group: AnalysisChartMetrics.RegretQuadrantMoodChipGroup
    ) -> Binding<Bool> {
        Binding(
            get: { pickerPresentedGroupID == group.id },
            set: { isPresented in
                if !isPresented, pickerPresentedGroupID == group.id {
                    pickerPresentedGroupID = nil
                }
            }
        )
    }

    private func regretMoodChipLabel(_ group: AnalysisChartMetrics.RegretQuadrantMoodChipGroup) -> some View {
        Text(regretMoodChipTitle(group))
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(group.tagColor.opacity(0.18))
            .foregroundStyle(AppTheme.textPrimary)
            .clipShape(Capsule())
    }

    private func regretMoodChipTitle(_ group: AnalysisChartMetrics.RegretQuadrantMoodChipGroup) -> String {
        if group.count > 1 {
            return String(
                format: localization.text(.analysisRegretChipCount),
                locale: localization.locale,
                arguments: [group.title, group.count] as [CVarArg]
            )
        }
        return group.title
    }

}

// MARK: - Regret quadrant mood chip picker (popover)

private struct RegretQuadrantMoodChipPicker: View {
    @EnvironmentObject private var localization: LocalizationManager

    let group: AnalysisChartMetrics.RegretQuadrantMoodChipGroup
    let onSelect: (UUID) -> Void

    private let panelWidth: CGFloat = 292
    private let cornerRadius: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            pickerHeader
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()
                .overlay(Color.primary.opacity(0.06))

            VStack(spacing: 0) {
                ForEach(Array(group.points.enumerated()), id: \.element.id) { index, point in
                    if index > 0 {
                        Divider()
                            .overlay(Color.primary.opacity(0.05))
                            .padding(.leading, 36)
                    }
                    RegretQuadrantPickerEntryRow(
                        point: point,
                        worthLabel: worthLabel(for: point.worth),
                        onSelect: onSelect
                    )
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: panelWidth)
        .background { pickerGlassBackground }
    }

    private var pickerHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(group.tagColor.opacity(0.92))
                .frame(width: 3, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(group.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Text(pickerEntryCountText)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 0)
        }
    }

    private var pickerEntryCountText: String {
        String(
            format: localization.text(.analysisRegretPickerEntryCount),
            locale: localization.locale,
            arguments: [group.count] as [CVarArg]
        )
    }

    private func worthLabel(for worth: RetrospectiveWorth) -> String {
        switch worth {
        case .worthIt: return localization.text(.analysisRegretLegendWorthIt)
        case .neutral: return localization.text(.analysisRegretLegendNeutral)
        case .regret: return localization.text(.analysisRegretLegendRegret)
        }
    }

    @ViewBuilder
    private var pickerGlassBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: AppTheme.cardShadow.opacity(0.55), radius: 16, y: 8)
    }
}

private struct RegretQuadrantPickerEntryRow: View {
    @EnvironmentObject private var localization: LocalizationManager

    let point: AnalysisChartMetrics.RegretQuadrantPoint
    let worthLabel: String
    let onSelect: (UUID) -> Void

    var body: some View {
        Button {
            onSelect(point.recordPublicId)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Circle()
                    .fill(point.feedbackColor.opacity(0.9))
                    .frame(width: 8, height: 8)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(moneyText)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    Text(dateTimeText)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Text(worthLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(point.feedbackColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.45))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var moneyText: String {
        AppFormatter.moneyString(from: point.amount, locale: localization.locale)
    }

    private var dateTimeText: String {
        let day = AppFormatter.dayString(from: point.createdAt, locale: localization.locale)
        let time = AppFormatter.timeString(from: point.createdAt, locale: localization.locale)
        return "\(day) · \(time)"
    }
}
