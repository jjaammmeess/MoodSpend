import SwiftUI

private enum MoodSpectrumSheet: Identifiable {
    case guide
    case detail

    var id: String {
        switch self {
        case .guide: "guide"
        case .detail: "detail"
        }
    }
}

struct MoodSpectrumView: View {
    let payload: MoodSpectrumPayload

    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var revealProgress: CGFloat = 0
    @State private var activeSheet: MoodSpectrumSheet?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            spectrumInteractiveZone
            dialogueRow
        }
        .padding(.vertical, HomeMoodSpectrumLayout.verticalPadding)
        .onAppear { playRevealAnimation() }
        .onChange(of: payload.segmentSignature) { _, _ in
            playRevealAnimation(quick: true)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .guide:
                MoodSpectrumGuideSheet(
                    subtitle: payload.subtitle,
                    longPressHint: payload.longPressHint,
                    footer: localization.text(.homeMoodSpectrumDetailFooter),
                    legendItems: payload.legendItems,
                    customLegendItems: payload.customLegendItems,
                    showsDetailAction: payload.hasDetailEntries,
                    onViewDetails: { activeSheet = .detail }
                )
                .environmentObject(localization)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            case .detail:
                MoodSpectrumDetailSheet(
                    entries: payload.entries,
                    title: localization.text(.homeMoodSpectrumDetailTitle),
                    footer: localization.text(.homeMoodSpectrumDetailFooter),
                    emptyMessage: localization.text(.homeMoodSpectrumDetailEmpty)
                )
                .environmentObject(localization)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var spectrumInteractiveZone: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .trailing) {
                spectrumStrip
                    .contentShape(Rectangle())
                    .accessibilityAddTraits(payload.hasDetailEntries ? .allowsDirectInteraction : [])
                    .onLongPressGesture(minimumDuration: 0.45) {
                        guard payload.hasDetailEntries else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        activeSheet = .detail
                    }

                Image(systemName: "info.circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.55))
                    .padding(.trailing, 1)
                    .accessibilityHidden(true)
            }

            emotionLegendRow
        }
        .contentShape(Rectangle())
        .onTapGesture {
            activeSheet = .guide
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(payload.spectrumZoneAccessibilityLabel)
        .accessibilityHint(payload.spectrumZoneAccessibilityHint)
    }

    private var emotionLegendRow: some View {
        HStack(spacing: 0) {
            ForEach(payload.legendItems) { item in
                VStack(spacing: HomeMoodSpectrumLayout.legendItemSpacing) {
                    Circle()
                        .fill(item.color)
                        .frame(width: HomeMoodSpectrumLayout.legendDotSize, height: HomeMoodSpectrumLayout.legendDotSize)
                    Text(item.shortLabel)
                        .font(.system(size: HomeMoodSpectrumLayout.legendFontSize, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.78))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, HomeMoodSpectrumLayout.legendTopPadding)
    }

    private var spectrumStrip: some View {
        ZStack(alignment: .top) {
            spectrumCapsule(gradient: payload.linearGradient)
                .blur(radius: 15)
                .opacity(glowOpacity)
                .offset(y: 3)
                .allowsHitTesting(false)

            spectrumCapsule(gradient: payload.linearGradient)
        }
        .frame(height: HomeMoodSpectrumLayout.stripHeight)
        .frame(maxWidth: .infinity)
    }

    private var dialogueRow: some View {
        MoodReflectionDialogueCard(glowTint: payload.dialogue.iconTint) {
            HStack(alignment: .top, spacing: 12) {
                reflectionIconWell
                Text(payload.dialogue.attributedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(payload.dialogueAccessibilityLabel)
    }

    private var reflectionIconWell: some View {
        let colors = reflectionIconWellColors(iconTint: payload.dialogue.iconTint)
        return Image(systemName: payload.dialogue.iconSystemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(colors.icon)
            .symbolRenderingMode(colorScheme == .dark ? .monochrome : .hierarchical)
            .frame(width: HomeMoodSpectrumLayout.reflectionIconWellSize, height: HomeMoodSpectrumLayout.reflectionIconWellSize)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.mineIconWellCornerRadius, style: .continuous)
                    .fill(colors.well)
            )
            .accessibilityHidden(true)
    }

    /// Dark emotion hexes (e.g. stress `#62496F`) need a tinted well + light icon on dark cards.
    private func reflectionIconWellColors(iconTint: Color) -> (well: Color, icon: Color) {
        if colorScheme == .dark {
            return (iconTint.opacity(0.28), Color.white.opacity(0.92))
        }
        return (AppTheme.moodReflectionIconWellFill, iconTint)
    }

    @ViewBuilder
    private func spectrumCapsule(gradient: LinearGradient) -> some View {
        Capsule()
            .fill(gradient)
            .frame(height: HomeMoodSpectrumLayout.barHeight)
            .frame(maxWidth: .infinity)
            .mask(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .frame(width: max(0, proxy.size.width * revealProgress))
                }
            }
    }

    private var glowOpacity: Double {
        colorScheme == .dark ? 0.28 : 0.4
    }

    private func playRevealAnimation(quick: Bool = false) {
        if reduceMotion {
            revealProgress = 1
            return
        }
        let duration = quick ? 0.35 : 1.15
        revealProgress = 0
        withAnimation(.easeInOut(duration: duration)) {
            revealProgress = 1
        }
    }
}

// MARK: - Reflection dialogue card (soft glow surface)

private struct MoodReflectionDialogueCard<Content: View>: View {
    let glowTint: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .softGlowCardStyle(
                glowTint: glowTint,
                intensity: .dialogue,
                padding: HomeMoodSpectrumLayout.reflectionCardPadding
            )
    }
}

// MARK: - Guide sheet (tap spectrum zone)

private struct MoodSpectrumGuideSheet: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let subtitle: String
    let longPressHint: String
    let footer: String
    let legendItems: [MoodSpectrumLegendItem]
    let customLegendItems: [MoodSpectrumCustomLegendItem]
    let showsDetailAction: Bool
    let onViewDetails: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    guideContentCard

                    if showsDetailAction {
                        Button {
                            onViewDetails()
                        } label: {
                            Text(localization.text(.homeMoodSpectrumGuideOpenDetail))
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.actionBlue)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.pageBackground)
            .navigationTitle(localization.text(.homeMoodSpectrumGuideTitle))
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
        VStack(alignment: .leading, spacing: 16) {
            Text(subtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            presetLegendSection

            if !customLegendItems.isEmpty {
                customLegendSection
            }

            readingGuideSection

            VStack(alignment: .leading, spacing: 8) {
                Text(footer)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(longPressHint)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            DashboardWatercolorBackground(palette: .spectrum)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.metricDashboardCornerRadius, style: .continuous))
    }

    private var presetLegendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localization.text(.homeMoodSpectrumGuidePresetSection))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            ForEach(legendItems) { item in
                HStack(spacing: 10) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 10, height: 10)
                    Text(item.accessibilityName)
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

    private var customLegendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localization.text(.homeMoodSpectrumGuideCustomSection))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            ForEach(customLegendItems) { item in
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

            Text(localization.text(.homeMoodSpectrumGuideCustomNote))
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var readingGuideSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localization.text(.homeMoodSpectrumGuideReadingTitle))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            Text(localization.text(.homeMoodSpectrumGuideReadingBody))
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .lineSpacing(2)
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

// MARK: - Long-press detail sheet

private struct MoodSpectrumDetailSheet: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let entries: [MoodSpectrumEntry]
    let title: String
    let footer: String
    let emptyMessage: String

    private var sortedEntries: [MoodSpectrumEntry] {
        entries.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sortedEntries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "paintpalette")
                            .font(.system(size: 32))
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                        Text(emptyMessage)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
                } else {
                    List {
                        Section {
                            Text(footer)
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                                .listRowBackground(Color.clear)
                        }

                        Section {
                            ForEach(sortedEntries) { entry in
                                MoodSpectrumDetailRow(entry: entry)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(AppTheme.pageBackground)
            .navigationTitle(title)
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
}

private struct MoodSpectrumDetailRow: View {
    @EnvironmentObject private var localization: LocalizationManager

    let entry: MoodSpectrumEntry

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(entry.color)
                .frame(width: 5, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.emotionTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(
                        String(
                            format: localization.text(.homeMoodSpectrumDetailIndex),
                            locale: localization.locale,
                            arguments: [entry.spectrumIndex]
                        )
                    )
                    Text("·")
                    Text(AppFormatter.dayTimeString(from: entry.createdAt, locale: localization.locale))
                }
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
            }

            Spacer(minLength: 8)

            Text("-\(moneyText(entry.amount))")
                .font(.system(size: 16, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel)
    }

    private var rowAccessibilityLabel: String {
        let indexLine = String(
            format: localization.text(.homeMoodSpectrumDetailIndex),
            locale: localization.locale,
            arguments: [entry.spectrumIndex]
        )
        let dayTime = AppFormatter.dayTimeString(from: entry.createdAt, locale: localization.locale)
        let money = moneyText(entry.amount)
        return "\(entry.emotionTitle)，\(indexLine)，\(dayTime)，-\(money)"
    }

    private func moneyText(_ amount: Double) -> String {
        AppFormatter.moneyString(from: amount, locale: localization.locale)
    }
}

private enum HomeMoodSpectrumLayout {
    static let verticalPadding: CGFloat = 4
    static let barHeight: CGFloat = 14
    static let stripHeight: CGFloat = 22
    static let legendDotSize: CGFloat = 10
    static let legendFontSize: CGFloat = 11
    static let legendItemSpacing: CGFloat = 5
    static let legendTopPadding: CGFloat = 4
    static let reflectionCardPadding: CGFloat = 15
    static let reflectionIconWellSize: CGFloat = 36
}

#if DEBUG
#Preview {
    MoodSpectrumView(payload: .preview)
        .environmentObject(LocalizationManager())
        .environmentObject(CurrencyManager())
        .padding(16)
        .background(AppTheme.pageBackground)
}
#endif
