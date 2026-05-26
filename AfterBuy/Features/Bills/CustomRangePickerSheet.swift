import SwiftUI

/// Copy bundle for custom month-range picker (bills vs mood review).
struct CustomRangePickerCopy {
    let pickerTitle: LKey
    let unsetPreview: LKey
    let rangePreview: LKey
    let confirmTitle: LKey
    let paywallHint: LKey

    static let bills = CustomRangePickerCopy(
        pickerTitle: .billsPeriodCustomPickerTitle,
        unsetPreview: .billsPeriodCustomUnset,
        rangePreview: .billsPeriodCustomPickerPreview,
        confirmTitle: .billsPeriodCustomConfirm,
        paywallHint: .billsPeriodCustomPaywallHint
    )

    static let analysis = CustomRangePickerCopy(
        pickerTitle: .billsPeriodCustomPickerTitle,
        unsetPreview: .billsPeriodCustomUnset,
        rangePreview: .billsPeriodCustomPickerPreview,
        confirmTitle: .analysisPeriodCustomConfirm,
        paywallHint: .analysisPeriodCustomPaywallHint
    )
}

/// Irregular same-year month span picker for bill list / mood review custom period.
struct CustomRangePickerSheet: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    let availableYears: [Int]
    let initialRange: CustomMonthRange?
    let copy: CustomRangePickerCopy
    let onApply: (CustomMonthRange) -> Void

    @State private var selectedYear: Int
    @State private var rangeStartMonth: Int?
    @State private var rangeEndMonth: Int?
    @State private var showPaywall = false
    @State private var confirmBreathingScale: CGFloat = 1

    private let gridColumns = 4
    private let gridRows = 3
    private let columnSpacing: CGFloat = 8
    private let rowSpacing: CGFloat = 8
    private let cellHeight: CGFloat = 44

    init(
        availableYears: [Int],
        initialRange: CustomMonthRange?,
        copy: CustomRangePickerCopy = .bills,
        onApply: @escaping (CustomMonthRange) -> Void
    ) {
        self.availableYears = availableYears
        self.initialRange = initialRange
        self.copy = copy
        self.onApply = onApply

        let fallbackYear = availableYears.first ?? Calendar.current.component(.year, from: Date())
        if let initialRange {
            _selectedYear = State(initialValue: initialRange.year)
            _rangeStartMonth = State(initialValue: initialRange.startMonth)
            _rangeEndMonth = State(initialValue: initialRange.endMonth)
        } else {
            _selectedYear = State(initialValue: fallbackYear)
            _rangeStartMonth = State(initialValue: nil)
            _rangeEndMonth = State(initialValue: nil)
        }
    }

    private var periodCalendar: Calendar {
        AppPeriodContext.shared.calendar
    }

    private var retentionNow: Date {
        AppPeriodContext.shared.now
    }

    private var yearsInPicker: [Int] {
        let currentYear = periodCalendar.component(.year, from: retentionNow)
        let cappedYears = availableYears.filter { $0 <= currentYear }
        if subscriptionManager.isPro {
            return cappedYears
        }
        let allowed = Set(
            AppPeriodContext.freeRetentionYears(calendar: periodCalendar, now: retentionNow)
        )
        return cappedYears.filter { allowed.contains($0) }
    }

    private var draftRange: CustomMonthRange? {
        guard let rangeStartMonth, let rangeEndMonth else { return nil }
        return CustomMonthRange(year: selectedYear, startMonth: rangeStartMonth, endMonth: rangeEndMonth).normalized
    }

    private var selectionBounds: (low: Int, high: Int)? {
        guard let rangeStartMonth, let rangeEndMonth else { return nil }
        let low = min(rangeStartMonth, rangeEndMonth)
        let high = max(rangeStartMonth, rangeEndMonth)
        return (low, high)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                summaryHeader

                yearFlowSelector

                monthStreamCanvas

                if !subscriptionManager.isPro {
                    Text(localization.text(copy.paywallHint))
                        .font(.footnote)
                        .foregroundStyle(CustomRangeSpectrum.mutedGuideText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 4)
                }

                confirmActionButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 16)
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationTitle(localization.text(copy.pickerTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localization.text(.commonCancel)) {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(source: .customRange)
                .environmentObject(localization)
        }
        .onChange(of: draftRange != nil) { _, hasRange in
            updateConfirmBreathing(hasRange: hasRange)
        }
        .onAppear {
            AppPeriodContext.shared.refreshNow()
            clampSelectedYearForFreeTier()
            clampDraftRangeSelection()
            collapseCrossMonthDraftForFreeTier()
            updateConfirmBreathing(hasRange: draftRange != nil)
        }
    }

    // MARK: - Summary

    private var summaryHeader: some View {
        Text(previewText)
            .font(.title3.weight(.semibold))
            .tracking(1.5)
            .foregroundStyle(AppTheme.textPrimary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }

    private var previewText: String {
        guard let draftRange else {
            return localization.text(copy.unsetPreview)
        }
        return String(
            format: localization.text(copy.rangePreview),
            locale: localization.locale,
            arguments: [
                AppFormatter.plainInteger(draftRange.year),
                draftRange.startMonth,
                draftRange.endMonth
            ]
        )
    }

    // MARK: - Year flow (minimal text)

    private var yearFlowSelector: some View {
        HStack(spacing: 32) {
            ForEach(yearsInPicker, id: \.self) { year in
                Button {
                    guard selectedYear != year else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedYear = year
                    clampDraftRangeSelection()
                } label: {
                    Text(yearLabel(year))
                        .font(selectedYear == year ? .title3.weight(.bold) : .subheadline.weight(.medium))
                        .foregroundStyle(
                            selectedYear == year
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary.opacity(0.45)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func yearLabel(_ year: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = localization.locale
        formatter.setLocalizedDateFormatFromTemplate("yyyy")
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        guard let date = Calendar.current.date(from: components) else { return "\(year)" }
        return formatter.string(from: date)
    }

    // MARK: - Month stream grid (glass card + connected spectrum)

    private var monthStreamCanvas: some View {
        VStack(spacing: rowSpacing) {
            ForEach(0..<gridRows, id: \.self) { row in
                monthStreamRow(rowIndex: row)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            Color.white.opacity(colorScheme == .dark ? 0.12 : 0.55),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.06), radius: 18, y: 8)
        }
    }

    private func monthStreamRow(rowIndex: Int) -> some View {
        ZStack(alignment: .leading) {
            rowSpectrumRail(rowIndex: rowIndex)

            HStack(spacing: columnSpacing) {
                ForEach(0..<gridColumns, id: \.self) { column in
                    let month = rowIndex * gridColumns + column + 1
                    monthCell(month)
                }
            }
        }
        .frame(height: cellHeight)
    }

    @ViewBuilder
    private func rowSpectrumRail(rowIndex: Int) -> some View {
        if let bounds = selectionBounds {
            let rowMonths = (0..<gridColumns).map { rowIndex * gridColumns + $0 + 1 }
            let selectedInRow = rowMonths.filter { $0 >= bounds.low && $0 <= bounds.high }
            if !selectedInRow.isEmpty,
               let segmentLow = selectedInRow.min(),
               let segmentHigh = selectedInRow.max() {
                rowSpectrumRailBody(
                    rowIndex: rowIndex,
                    bounds: bounds,
                    segmentLow: segmentLow,
                    segmentHigh: segmentHigh
                )
            }
        }
    }

    private func rowSpectrumRailBody(
        rowIndex: Int,
        bounds: (low: Int, high: Int),
        segmentLow: Int,
        segmentHigh: Int
    ) -> some View {
        GeometryReader { proxy in
            let cellWidth = (proxy.size.width - columnSpacing * CGFloat(gridColumns - 1)) / CGFloat(gridColumns)
            let lowCol = (segmentLow - 1) % gridColumns
            let highCol = (segmentHigh - 1) % gridColumns
            let segmentSpan = highCol - lowCol + 1
            let railWidth = CGFloat(segmentSpan) * cellWidth + CGFloat(segmentSpan - 1) * columnSpacing
            let xOffset = CGFloat(lowCol) * (cellWidth + columnSpacing)

            let lowRow = (bounds.low - 1) / gridColumns
            let highRow = (bounds.high - 1) / gridColumns
            let corners = rowRailCornerRadii(
                rowIndex: rowIndex,
                lowRow: lowRow,
                highRow: highRow,
                lowCol: lowCol,
                highCol: highCol,
                segmentLow: segmentLow,
                segmentHigh: segmentHigh,
                bounds: bounds
            )

            UnevenRoundedRectangle(cornerRadii: corners, style: .continuous)
                .fill(
                    CustomRangeSpectrum.segmentGradient(
                        segmentLow: segmentLow,
                        segmentHigh: segmentHigh,
                        globalLow: bounds.low,
                        globalHigh: bounds.high
                    )
                )
                .overlay {
                    UnevenRoundedRectangle(cornerRadii: corners, style: .continuous)
                        .stroke(CustomRangeSpectrum.railStroke, lineWidth: 0.8)
                }
                .frame(width: railWidth, height: cellHeight)
                .offset(x: xOffset)
                .shadow(color: CustomRangeSpectrum.railGlow, radius: 10, y: 3)
        }
        .allowsHitTesting(false)
    }

    private func rowRailCornerRadii(
        rowIndex: Int,
        lowRow: Int,
        highRow: Int,
        lowCol: Int,
        highCol: Int,
        segmentLow: Int,
        segmentHigh: Int,
        bounds: (low: Int, high: Int)
    ) -> RectangleCornerRadii {
        let outer: CGFloat = 13
        let inner: CGFloat = 4

        let isTopRow = rowIndex == lowRow
        let isBottomRow = rowIndex == highRow
        let touchesLeft = segmentLow == bounds.low
        let touchesRight = segmentHigh == bounds.high

        return RectangleCornerRadii(
            topLeading: isTopRow && touchesLeft ? outer : inner,
            bottomLeading: isBottomRow && touchesLeft ? outer : inner,
            bottomTrailing: isBottomRow && touchesRight ? outer : inner,
            topTrailing: isTopRow && touchesRight ? outer : inner
        )
    }

    private func monthCell(_ month: Int) -> some View {
        let selected = isMonthSelected(month)
        let selectable = isMonthSelectable(month)
        return Button {
            guard selectable else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            handleMonthTap(month)
        } label: {
            Text(monthLabel(month))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(
                    selected ? Color.white : (selectable ? Color.secondary : Color.secondary.opacity(0.32))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!selectable)
    }

    private func monthLabel(_ month: Int) -> String {
        var components = DateComponents()
        components.month = month
        components.day = 1
        guard let date = Calendar.current.date(from: components) else { return "\(month)" }
        let formatter = DateFormatter()
        formatter.locale = localization.locale
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: date)
    }

    // MARK: - Confirm CTA

    private var confirmActionButton: some View {
        Button {
            confirmSelection()
        } label: {
            Text(localization.text(copy.confirmTitle))
                .font(.headline.weight(.semibold))
                .foregroundStyle(confirmButtonForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(confirmButtonBackground)
                )
                .shadow(
                    color: Color.black.opacity(draftRange == nil ? 0 : (colorScheme == .dark ? 0.45 : 0.12)),
                    radius: 10,
                    y: 4
                )
        }
        .buttonStyle(.plain)
        .disabled(draftRange == nil)
        .opacity(draftRange == nil ? 0.42 : 1)
        .scaleEffect(confirmBreathingScale)
    }

    private var confirmButtonForeground: Color {
        colorScheme == .dark ? Color.white.opacity(0.94) : Color.black
    }

    private var confirmButtonBackground: Color {
        colorScheme == .dark ? Color(hex: "141418") : Color.white
    }

    private func updateConfirmBreathing(hasRange: Bool) {
        guard !reduceMotion else {
            confirmBreathingScale = 1
            return
        }
        if hasRange {
            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                confirmBreathingScale = 1.028
            }
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                confirmBreathingScale = 1
            }
        }
    }

    // MARK: - Selection logic

    private func isMonthSelected(_ month: Int) -> Bool {
        guard let bounds = selectionBounds else { return false }
        return month >= bounds.low && month <= bounds.high
    }

    private func handleMonthTap(_ month: Int) {
        if !subscriptionManager.isPro {
            rangeStartMonth = month
            rangeEndMonth = month
            return
        }
        if rangeStartMonth == nil {
            rangeStartMonth = month
            rangeEndMonth = month
            return
        }
        if let start = rangeStartMonth, rangeEndMonth == start, month != start {
            rangeEndMonth = month
            normalizeDraftRange()
            return
        }
        rangeStartMonth = month
        rangeEndMonth = month
    }

    private func normalizeDraftRange() {
        guard let rangeStartMonth, let rangeEndMonth else { return }
        var range = CustomMonthRange(year: selectedYear, startMonth: rangeStartMonth, endMonth: rangeEndMonth)
        range.normalize()
        self.rangeStartMonth = range.startMonth
        self.rangeEndMonth = range.endMonth
        clampDraftRangeSelection()
    }

    private func confirmSelection() {
        guard let draftRange else { return }
        AppPeriodContext.shared.refreshNow()
        let now = AppPeriodContext.shared.now
        guard AppPeriodContext.isCustomRangeWithinSelectableMonths(
            draftRange,
            calendar: periodCalendar,
            now: now
        ) else { return }

        if subscriptionManager.isPro {
            onApply(draftRange)
            dismiss()
            return
        }
        if AppPeriodContext.isCustomRangeAllowedForFreeUser(
            draftRange,
            calendar: periodCalendar,
            now: now
        ) {
            onApply(draftRange)
            dismiss()
        } else {
            showPaywall = true
        }
    }

    private func isMonthSelectable(_ month: Int) -> Bool {
        AppPeriodContext.isMonthSelectableInCustomPicker(
            year: selectedYear,
            month: month,
            calendar: periodCalendar,
            now: retentionNow,
            isPro: subscriptionManager.isPro
        )
    }

    private func clampSelectedYearForFreeTier() {
        let allowed = yearsInPicker
        guard !allowed.isEmpty else { return }
        if !allowed.contains(selectedYear) {
            selectedYear = allowed[0]
            rangeStartMonth = nil
            rangeEndMonth = nil
        }
    }

    private func clampDraftRangeSelection() {
        guard let start = rangeStartMonth, let end = rangeEndMonth else { return }
        let draft = CustomMonthRange(year: selectedYear, startMonth: start, endMonth: end).normalized
        guard let clamped = AppPeriodContext.clampCustomRangeToSelectableMonths(
            draft,
            calendar: periodCalendar,
            now: retentionNow
        ) else {
            rangeStartMonth = nil
            rangeEndMonth = nil
            return
        }
        for month in clamped.startMonth...clamped.endMonth {
            if !isMonthSelectable(month) {
                rangeStartMonth = nil
                rangeEndMonth = nil
                return
            }
        }
        rangeStartMonth = clamped.startMonth
        rangeEndMonth = clamped.endMonth
        collapseCrossMonthDraftForFreeTier()
    }

    /// Free tier: custom period is a single month (this month or last month), not a span.
    private func collapseCrossMonthDraftForFreeTier() {
        guard !subscriptionManager.isPro else { return }
        guard let start = rangeStartMonth, let end = rangeEndMonth, start != end else { return }
        rangeEndMonth = start
    }
}

// MARK: - MoodSpectrum-aligned gradient (one continuous stream per row segment)

private enum CustomRangeSpectrum {
    static let moodColors: [Color] = [
        Color(hex: "C65840"),
        Color(hex: "E8B84A"),
        Color(hex: "5F9E7A"),
        Color(hex: "69B7CE"),
        Color(hex: "8C76A1"),
    ]

    static var mutedGuideText: Color {
        Color(hex: "5C6670")
    }

    static var railGlow: Color {
        Color(hex: "69B7CE").opacity(0.22)
    }

    static var railStroke: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.45),
                Color.white.opacity(0.12),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func segmentGradient(
        segmentLow: Int,
        segmentHigh: Int,
        globalLow: Int,
        globalHigh: Int
    ) -> LinearGradient {
        let startX = unitX(month: segmentLow, globalLow: globalLow, globalHigh: globalHigh)
        let endX = unitX(month: segmentHigh, globalLow: globalLow, globalHigh: globalHigh)
        let stops = MoodSpectrumGradient.stops(from: moodColors)
        return LinearGradient(
            stops: stops,
            startPoint: UnitPoint(x: startX, y: 0.5),
            endPoint: UnitPoint(x: endX, y: 0.5)
        )
    }

    private static func unitX(month: Int, globalLow: Int, globalHigh: Int) -> CGFloat {
        guard globalHigh > globalLow else { return 0.5 }
        return CGFloat(month - globalLow) / CGFloat(globalHigh - globalLow)
    }
}
