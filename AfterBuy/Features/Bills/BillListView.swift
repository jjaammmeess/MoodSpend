import SwiftData
import SwiftUI

struct BillListView: View {
    private enum FilterChrome {
        static let selectedFill = Color(hex: "3F6F76")
        static let orbSize: CGFloat = 22
    }

    private enum FilterChipIconStyle {
        /// Category row: flat SF Symbol / icon.
        case inline
        /// Emotion row: circular orb like Record sheet (`EmotionGridCell`).
        case emotionOrb
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.isTabActive) private var isTabActive
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var notificationStore: NotificationCenterStore

    @EnvironmentObject private var periodContext: AppPeriodContext
    @EnvironmentObject private var appSettings: AppSettings
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Query(
        filter: #Predicate<TransactionRecord> { $0.deletedAt == nil },
        sort: \TransactionRecord.createdAt,
        order: .reverse
    ) private var records: [TransactionRecord]
    @Query(
        filter: #Predicate<CustomOption> { $0.deletedAt == nil },
        sort: \CustomOption.createdAt,
        order: .reverse
    ) private var customOptions: [CustomOption]
    @State private var showPaywall = false
    @State private var paywallSource: PaywallSource = .general
    @State private var showCustomPicker = false
    /// Empty = all categories in the current period (OR when non-empty).
    @State private var selectedCategoryKeys: Set<String> = []
    /// `nil` = all moods in the current period.
    @State private var selectedEmotionRaw: String?
    @State private var showBillFilterSheet = false
    @State private var metricsDetailKind: BillListMetricDetailKind?
    @State private var filterSheetDraftCategoryKeys: Set<String> = []
    @State private var filterSheetDraftEmotion: String?
    @State private var editingRecord: TransactionRecord?
    @State private var selectedRecord: TransactionRecord?
    @State private var recordPendingDelete: TransactionRecord?
    /// Bumped when period/category/emotion filters change so the sparkline replays its draw animation.
    @State private var sparklineDrawGeneration: UInt = 0
    @State private var cachedSparklinePoints: [BillListSparklineMetrics.Point] = []

    private var customOptionsFingerprint: String {
        customOptions.map { "\($0.kindRaw):\($0.name)" }.sorted().joined(separator: "|")
    }

    private var customCategoryOptions: [CustomOption] {
        customOptions
            .filter { $0.kind == .category }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var customEmotionOptions: [CustomOption] {
        customOptions
            .filter { $0.kind == .emotion }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var validCategoryKeys: Set<String> {
        var s = Set(CategoryPreset.options.map(\.id))
        for o in customCategoryOptions {
            s.insert(CustomOptionMutation.categoryKey(forName: o.name))
        }
        return s
    }

    private var validEmotionRaws: Set<String> {
        var s = Set(EmotionTag.allCases.map(\.rawValue))
        for o in customEmotionOptions {
            s.insert(CustomOptionMutation.emotionRaw(forName: o.name))
        }
        return s
    }

    private var periodScopedExpenses: [TransactionRecord] {
        records.filter { record in
            periodContext.recordIsInPeriod(record.createdAt) && record.type == .expense
        }
    }

    private var filteredRecords: [TransactionRecord] {
        periodScopedExpenses.filter { record in
            let categoryOK = selectedCategoryKeys.isEmpty || selectedCategoryKeys.contains(record.categoryKey)
            let emotionOK = selectedEmotionRaw == nil || record.emotionRaw == selectedEmotionRaw
            return categoryOK && emotionOK
        }
    }

    private var hasActiveFilters: Bool {
        !selectedCategoryKeys.isEmpty || selectedEmotionRaw != nil
    }

    private var totalExpense: Double {
        filteredRecords.reduce(0) { $0 + $1.amount }
    }

    private var previousPeriodFilteredRecords: [TransactionRecord] {
        records.filter { record in
            guard record.type == .expense, periodContext.recordIsInPreviousPeriod(record.createdAt) else { return false }
            let categoryOK = selectedCategoryKeys.isEmpty || selectedCategoryKeys.contains(record.categoryKey)
            let emotionOK = selectedEmotionRaw == nil || record.emotionRaw == selectedEmotionRaw
            return categoryOK && emotionOK
        }
    }

    private var previousPeriodExpense: Double {
        previousPeriodFilteredRecords.reduce(0) { $0 + $1.amount }
    }

    /// Period expenses with emotion filter only — used for category share chips.
    private var categoryScopeExpenses: [TransactionRecord] {
        periodScopedExpenses.filter { record in
            selectedEmotionRaw == nil || record.emotionRaw == selectedEmotionRaw
        }
    }

    private var sparklineScopeExpenses: [TransactionRecord] {
        periodScopedExpenses.filter { record in
            let categoryOK = selectedCategoryKeys.isEmpty || selectedCategoryKeys.contains(record.categoryKey)
            let emotionOK = selectedEmotionRaw == nil || record.emotionRaw == selectedEmotionRaw
            return categoryOK && emotionOK
        }
    }

    private var sparklineMetricsToken: String {
        let customToken: String = {
            guard let range = periodContext.customRange else { return "-" }
            return "\(range.year)-\(range.startMonth)-\(range.endMonth)"
        }()
        let categoryToken = selectedCategoryKeys.sorted().joined(separator: ",")
        return "\(periodContext.selectedPeriod.rawValue)|\(periodContext.targetDate.timeIntervalSince1970)|\(customToken)|\(categoryToken)|\(selectedEmotionRaw ?? "")|\(records.count)|\(appSettings.firstDayOfWeek.rawValue)"
    }

    private var sparklineReplayToken: String {
        "\(sparklineMetricsToken)|\(sparklineDrawGeneration)"
    }

    private var categorySpendChips: [BillListCategorySpendChip] {
        let expenses = categoryScopeExpenses
        guard !expenses.isEmpty else { return [] }

        let grouped = Dictionary(grouping: expenses, by: \.categoryKey)
        let totals = grouped.mapValues { records in records.reduce(0) { $0 + $1.amount } }
        let grandTotal = totals.values.reduce(0, +)
        guard grandTotal > 0 else { return [] }

        return totals
            .sorted { $0.value > $1.value }
            .prefix(8)
            .map { key, amount in
                let percent = Int((amount / grandTotal * 100).rounded())
                let records = grouped[key] ?? []
                return BillListCategorySpendChip(
                    id: key,
                    title: displayCategoryTitle(forKey: key, records: records),
                    percent: max(1, percent),
                    systemImage: CategoryVisualStyle.iconName(for: key),
                    iconTint: CategoryVisualStyle.iconColor(for: key)
                )
            }
    }

    private var dashboardModel: BillListDashboardModel {
        BillListDashboardModel(
            totalSpentTitle: localization.text(dashboardTotalSpentTitleKey),
            totalExpenseAmount: totalExpense,
            expenseDeltaText: expenseDeltaDisplayText,
            expenseDeltaTrend: expenseDeltaTrend,
            frequencyTitle: localization.text(dashboardFrequencyTitleKey),
            entryCount: filteredRecords.count,
            entriesLabel: localization.text(.billsDashboardEntries),
            frequencyDeltaText: frequencyDeltaDisplayText,
            frequencyDeltaTrend: frequencyDeltaTrend
        )
    }

    private var dashboardTotalSpentTitleKey: LKey {
        switch periodContext.selectedPeriod {
        case .day: return .billsDashboardTotalSpentDay
        case .week: return .billsDashboardTotalSpentWeek
        case .month: return .billsDashboardTotalSpentMonth
        case .year: return .billsDashboardTotalSpentYear
        case .custom: return .billsDashboardTotalSpentCustom
        }
    }

    private var dashboardFrequencyTitleKey: LKey {
        switch periodContext.selectedPeriod {
        case .day: return .billsDashboardFrequencyDay
        case .week: return .billsDashboardFrequencyWeek
        case .month: return .billsDashboardFrequencyMonth
        case .year: return .billsDashboardFrequencyYear
        case .custom: return .billsDashboardFrequencyCustom
        }
    }

    private var dashboardComparePeriodKey: LKey {
        switch periodContext.selectedPeriod {
        case .day: return .billsDashboardComparePeriodDay
        case .week: return .billsDashboardComparePeriodWeek
        case .month: return .billsDashboardComparePeriodMonth
        case .year: return .billsDashboardComparePeriodYear
        case .custom: return .billsDashboardComparePeriodCustom
        }
    }

    private var expenseDeltaTrend: MetricTrendDeltaCapsule.Trend {
        trend(forCurrent: totalExpense, previous: previousPeriodExpense)
    }

    private var frequencyDeltaTrend: MetricTrendDeltaCapsule.Trend {
        trend(
            forCurrent: Double(filteredRecords.count),
            previous: Double(previousPeriodFilteredRecords.count)
        )
    }

    private func trend(forCurrent current: Double, previous: Double) -> MetricTrendDeltaCapsule.Trend {
        if previous == 0, current == 0 { return .neutral }
        if previous == 0, current > 0 { return .up }
        let delta = current - previous
        if delta == 0 { return .flat }
        return delta > 0 ? .up : .down
    }

    private var expenseDeltaDisplayText: String? {
        let current = totalExpense
        let previous = previousPeriodExpense
        let periodLabel = localization.text(dashboardComparePeriodKey)

        if previous == 0, current == 0 {
            return localizedTemplate(.billsDashboardExpenseDeltaUnavailable, periodLabel)
        }
        if previous == 0 {
            let percent = 100
            return localizedTemplate(.billsDashboardExpenseDeltaUp, "\(percent)", periodLabel)
        }

        let delta = current - previous
        if delta == 0 {
            return localizedTemplate(.billsDashboardExpenseDeltaFlat, periodLabel)
        }
        let percent = Int((abs(delta) / previous * 100).rounded())
        if delta > 0 {
            return localizedTemplate(.billsDashboardExpenseDeltaUp, "\(percent)", periodLabel)
        }
        return localizedTemplate(.billsDashboardExpenseDeltaDown, "\(-percent)", periodLabel)
    }

    private var frequencyDeltaDisplayText: String? {
        let current = filteredRecords.count
        let previous = previousPeriodFilteredRecords.count
        let periodLabel = localization.text(dashboardComparePeriodKey)

        if previous == 0, current == 0 {
            return localizedTemplate(.billsDashboardFreqDeltaUnavailable, periodLabel)
        }
        if previous == 0 {
            return localizedTemplate(.billsDashboardFreqDeltaUp, "\(current)", periodLabel)
        }

        let delta = current - previous
        if delta == 0 {
            return localizedTemplate(.billsDashboardFreqDeltaFlat, periodLabel)
        }
        if delta > 0 {
            return localizedTemplate(.billsDashboardFreqDeltaUp, "\(delta)", periodLabel)
        }
        return localizedTemplate(.billsDashboardFreqDeltaDown, "\(delta)", periodLabel)
    }

    private func moneyText(_ amount: Double) -> String {
        AppFormatter.moneyString(from: amount, locale: localization.locale)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground.ignoresSafeArea()
                mainScrollContent
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: customOptionsFingerprint) { _, _ in
                syncSelectionsWithAvailableOptions()
            }
            .onAppear {
                periodContext.refreshNow()
                syncSelectionsWithAvailableOptions()
                scheduleSparklineRecompute(playAnimation: isTabActive)
            }
            .onChange(of: sparklineMetricsToken) { _, _ in
                scheduleSparklineRecompute(playAnimation: true)
            }
            .onChange(of: isTabActive) { _, active in
                guard active else { return }
                scheduleSparklineRecompute(playAnimation: true)
            }
        }
        .navigationDestination(item: $editingRecord) { record in
            RecordSheetView(editingRecord: record)
                .environmentObject(localization)
                .environmentObject(appSettings)
        }
        .sheet(item: $selectedRecord) { record in
            RecordDetailView(record: record)
                .environmentObject(localization)
                .environmentObject(appSettings)
                .environmentObject(notificationStore)
        }
        .sheet(isPresented: $showBillFilterSheet) {
            billFilterSheet
                .environmentObject(localization)
        }
        .sheet(item: $metricsDetailKind) { kind in
            BillListMetricsDetailSheet(
                kind: kind,
                model: metricsDetailModel(for: kind),
                onSelectRecord: { record in
                    selectedRecord = record
                }
            )
            .environmentObject(localization)
        }
        .sheet(isPresented: $showCustomPicker, onDismiss: {
            if periodContext.selectedPeriod == .custom, periodContext.customRange == nil {
                periodContext.resetToCurrentMonth()
            }
        }) {
            CustomRangePickerSheet(
                availableYears: AppPeriodContext.availableYears(
                    from: records,
                    calendar: periodContext.calendar
                ),
                initialRange: periodContext.customRange,
                onApply: { range in
                    periodContext.applyCustomRange(range)
                    selectedCategoryKeys = []
                    showCustomPicker = false
                }
            )
            .environmentObject(localization)
        }
        .fullScreenCover(isPresented: $showPaywall, onDismiss: handlePaywallDismiss) {
            PaywallView(source: paywallSource)
                .environmentObject(localization)
        }
        .recordDeleteConfirmation(item: $recordPendingDelete)
        .onChange(of: subscriptionManager.isPro) { _, isPro in
            if isPro {
                showPaywall = false
            } else {
                periodContext.clampToFreeRetentionWindowIfNeeded(isPro: false)
            }
        }
    }

    private func handlePaywallDismiss() {
        guard !subscriptionManager.isPro else { return }
        periodContext.rollbackAfterFreePaywallDismiss()
        showCustomPicker = false
    }

    private var billInsightPeriodPrefixKey: LKey {
        switch periodContext.selectedPeriod {
        case .day: return .billsInsightPeriodPrefixDay
        case .week: return .billsInsightPeriodPrefixWeek
        case .month: return .billsInsightPeriodPrefixMonth
        case .year: return .billsInsightPeriodPrefixYear
        case .custom: return .billsInsightPeriodPrefixCustom
        }
    }

    private var billListCustomInsightClause: String? {
        guard periodContext.selectedPeriod == .custom,
              let range = periodContext.customRange
        else { return nil }
        return AppPeriodContext.insightClause(
            for: range,
            localize: { localization.text($0) },
            locale: localization.locale
        )
    }

    private var billListPreviousCustomRangeLabel: String? {
        guard periodContext.selectedPeriod == .custom,
              let range = periodContext.customRange,
              let previous = AppPeriodContext.previousCustomRange(before: range)
        else { return nil }
        return AppPeriodContext.insightRangeLabel(
            for: previous,
            localize: { localization.text($0) },
            locale: localization.locale
        )
    }

    /// List capsule row: single-select UI; replaces any multi-select from the filter sheet.
    private var capsuleRowCategorySelection: Binding<String?> {
        Binding(
            get: {
                selectedCategoryKeys.count == 1 ? selectedCategoryKeys.first : nil
            },
            set: { newValue in
                if let newValue {
                    selectedCategoryKeys = [newValue]
                } else {
                    selectedCategoryKeys = []
                }
            }
        )
    }

    private var billListInsightText: String? {
        BillListInsightEngine.make(
            input: BillListInsightEngine.Input(
                periodMode: periodContext.selectedPeriod,
                customRange: periodContext.customRange,
                dateFilter: periodContext.selectedPeriod.dateFilterEquivalent,
                selectedCategoryKeys: selectedCategoryKeys,
                categoryScopeExpenses: categoryScopeExpenses,
                filteredRecords: filteredRecords,
                sparklinePoints: cachedSparklinePoints,
                totalExpense: totalExpense,
                previousPeriodExpense: previousPeriodExpense,
                periodCompareLabel: localization.text(dashboardComparePeriodKey),
                categoryTitle: { displayCategoryTitle(forKey: $0) },
                periodPrefix: localization.text(billInsightPeriodPrefixKey),
                customRangeClause: billListCustomInsightClause,
                previousCustomRangeLabel: billListPreviousCustomRangeLabel,
                localize: localizedTemplate,
                calendar: periodContext.calendar,
                now: periodContext.now
            )
        )
    }

    /// Title, period filter, and summary card — pinned above the unified list (intrinsic height only).
    private var billListPinnedHeader: some View {
        VStack(spacing: 0) {
            billListTitleRow

            AppPeriodHeader(
                period: periodContext,
                subscriptionManager: subscriptionManager,
                showPaywall: $showPaywall,
                paywallSource: $paywallSource,
                showCustomPicker: $showCustomPicker,
                onPeriodChangeNeedsRollback: {
                    periodContext.resetToCurrentMonth()
                }
            )

            metricDashboard
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background {
            AppTheme.pageBackground
                .ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.divider)
                .frame(height: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 6, y: 3)
    }

    private var billListTitleRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(localization.text(.billsTitle))
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            billFilterEntryButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var billListTrendRowInsets: EdgeInsets {
        EdgeInsets()
    }

    private var billListRecordRowInsets: EdgeInsets {
        EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)
    }

    @ViewBuilder
    private var mainScrollContent: some View {
        if periodScopedExpenses.isEmpty {
            emptyPeriodScroll
        } else {
            unifiedBillList
        }
    }

    private var emptyPeriodScroll: some View {
        ScrollView {
            VStack(spacing: 0) {
                billListPinnedHeader
                Spacer(minLength: 48)
                EmptyStateBlock(
                    title: localization.text(.billsEmptyTip),
                    systemImage: "list.bullet.clipboard"
                )
                .padding(.horizontal, 24)
                Spacer(minLength: 120)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.pageBackground)
    }

    /// Sparkline, category capsules, insight, and bill rows share one List (no external trend block).
    private var unifiedBillList: some View {
        List {
            BillListExpenseSparkline(
                points: cachedSparklinePoints,
                replayToken: sparklineReplayToken,
                accessibilityLabelText: localization.text(.billsDashboardSparklineA11y)
            )
            .frame(height: BillListExpenseSparkline.layoutHeight)
            .frame(maxWidth: .infinity)
            .clipped()
            .listRowInsets(billListTrendRowInsets)
            .listRowSeparator(.hidden)
            .listRowBackground(AppTheme.pageBackground)

            if !categorySpendChips.isEmpty {
                BillListCategoryCapsuleRow(
                    allChipTitle: localization.text(.commonAll),
                    chips: categorySpendChips,
                    selectedCategoryKey: capsuleRowCategorySelection
                )
                .listRowInsets(billListTrendRowInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.pageBackground)
            }

            if let billListInsightText {
                BillListInsightRow(text: billListInsightText)
                    .listRowInsets(billListTrendRowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.pageBackground)
            }

            if filteredRecords.isEmpty {
                filteredEmptyListRow
            } else {
                ForEach(filteredRecords) { record in
                    billRecordRow(record)
                }
                .onDelete(perform: delete)
            }
        }
        .listStyle(.plain)
        .animation(nil, value: filteredRecords.count)
        .listSectionSpacing(0)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListHeaderHeight, 0)
        .contentMargins(.top, 0, for: .scrollContent)
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .safeAreaInset(edge: .top, spacing: 0) {
            billListPinnedHeader
        }
    }

    private var filteredEmptyListRow: some View {
        VStack(spacing: 16) {
            EmptyStateBlock(
                title: localization.text(.billsFilteredEmptyTitle),
                hint: localization.text(.billsFilteredEmptyHint),
                systemImage: "line.3.horizontal.decrease.circle"
            )
            if hasActiveFilters {
                Button(localization.text(.billsClearFilters)) {
                    selectedCategoryKeys = []
                    selectedEmotionRaw = nil
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.actionBlue)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius)
                        .stroke(AppTheme.actionBlue.opacity(0.35), lineWidth: 1)
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .listRowInsets(billListTrendRowInsets)
        .listRowSeparator(.hidden)
        .listRowBackground(AppTheme.pageBackground)
    }

    @ViewBuilder
    private func billRecordRow(_ record: TransactionRecord) -> some View {
        RecordRowView(
            record: record,
            showsBottomSeparator: false
        )
        .listRowBackground(AppTheme.cardBackground)
        .listRowInsets(billListRecordRowInsets)
        .listRowSeparator(.hidden)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedRecord = record
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(localization.text(.billsEdit)) {
                editingRecord = record
            }
            .tint(AppTheme.actionBlue)
            Button {
                recordPendingDelete = record
            } label: {
                Label(localization.text(.commonDelete), systemImage: "trash")
            }
            .tint(AppTheme.accentRisk)
        }
    }

    private var billFilterEntryButton: some View {
        Button {
            filterSheetDraftCategoryKeys = selectedCategoryKeys
            filterSheetDraftEmotion = selectedEmotionRaw
            showBillFilterSheet = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(hasActiveFilters ? AppTheme.actionBlue : AppTheme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                if hasActiveFilters {
                    Circle()
                        .fill(AppTheme.actionBlue)
                        .frame(width: 6, height: 6)
                        .offset(x: 4, y: -4)
                }
            }
            .background(
                hasActiveFilters
                    ? AppTheme.actionBlue.opacity(0.14)
                    : AppTheme.cardBackground
            )
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(filterSummaryLine)
        .accessibilityHint(localization.text(.billsFilterEntryA11yHint))
    }

    private var filterSummaryLine: String {
        let categoryPart = displayCategoryFilterSummary(for: selectedCategoryKeys)
        let emotionPart = displayEmotionTitle(forRaw: selectedEmotionRaw)
        return "\(categoryPart) · \(emotionPart)"
    }

    private func displayCategoryTitle(forKey key: String, records: [TransactionRecord] = []) -> String {
        if let preset = CategoryPreset.options.first(where: { $0.id == key }), let presetKey = preset.key {
            return localization.text(presetKey)
        }
        if let custom = customCategoryOptions.first(where: { CustomOptionMutation.categoryKey(forName: $0.name) == key }) {
            return custom.name
        }
        if CustomOptionMutation.customCategorySuffix(fromKey: key) != nil {
            if let snapshot = records.first(where: { !$0.categoryName.isEmpty })?.categoryName {
                return snapshot
            }
            if let suffix = CustomOptionMutation.customCategorySuffix(fromKey: key), !suffix.isEmpty {
                return suffix
            }
        }
        return key
    }

    private func displayCategoryFilterSummary(for keys: Set<String>) -> String {
        guard !keys.isEmpty else { return localization.text(.commonAll) }
        if keys.count == 1, let key = keys.first {
            return displayCategoryTitle(forKey: key)
        }
        let sorted = keys.sorted {
            displayCategoryTitle(forKey: $0).localizedStandardCompare(displayCategoryTitle(forKey: $1)) == .orderedAscending
        }
        let first = displayCategoryTitle(forKey: sorted[0])
        return localizedTemplate(.billsFilterCategorySummaryMany, first, "\(keys.count)")
    }

    private func displayEmotionTitle(forRaw raw: String?) -> String {
        guard let raw else { return localization.text(.commonAll) }
        if let tag = EmotionTag.from(raw: raw) {
            return localization.text(tag.key)
        }
        if let custom = customEmotionOptions.first(where: { CustomOptionMutation.emotionRaw(forName: $0.name) == raw }) {
            return custom.name
        }
        return localization.text(.commonAll)
    }

    private var billFilterSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    filterDimensionSection(
                        titleKey: .billsFilterCategoryLabel,
                        topInset: 0,
                        titleRowSpacing: 4,
                        row: { categoryFilterGrid(selection: $filterSheetDraftCategoryKeys) }
                    )

                    Rectangle()
                        .fill(AppTheme.divider.opacity(0.5))
                        .frame(height: 1)
                        .padding(.vertical, 2)

                    filterDimensionSection(
                        titleKey: .billsFilterEmotionLabel,
                        topInset: 0,
                        titleRowSpacing: 4,
                        row: { emotionFilterGrid(selection: $filterSheetDraftEmotion) }
                    )
                }
                .padding(16)
            }
            .background(AppTheme.pageBackground)
            .navigationTitle(localization.text(.billsFilterSheetTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.text(.commonCancel)) {
                        showBillFilterSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    HStack(spacing: 16) {
                        Button(localization.text(.billsFilterSheetReset)) {
                            filterSheetDraftCategoryKeys = []
                            filterSheetDraftEmotion = nil
                        }
                        .foregroundStyle(.secondary)

                        Button(localization.text(.commonDone)) {
                            selectedCategoryKeys = filterSheetDraftCategoryKeys
                            selectedEmotionRaw = filterSheetDraftEmotion
                            showBillFilterSheet = false
                        }
                    }
                }
            }
        }
        .presentationDetents([.fraction(2.0 / 3.0)])
        .environment(\.locale, localization.locale)
    }

    private func filterDimensionSection(
        titleKey: LKey,
        topInset: CGFloat = 6,
        titleRowSpacing: CGFloat = 4,
        @ViewBuilder row: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: titleRowSpacing) {
            Text(localization.text(titleKey))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            row()
        }
        .padding(.top, topInset)
    }

    private var billFilterTagGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 104, maximum: 220), spacing: 8, alignment: .leading)]
    }

    private func selectedChipForeground(fillHex: String?) -> Color {
        guard let fillHex else { return .white }
        return AppTheme.labelOnFilledSwatch(hex: fillHex)
    }

    @ViewBuilder
    private func filterChipIcon(
        systemImage: String,
        iconTint: Color,
        isSelected: Bool,
        selectedForeground: Color,
        rasterAssetName: String?,
        style: FilterChipIconStyle
    ) -> some View {
        let size = FilterChrome.orbSize
        switch style {
        case .inline:
            if let raster = rasterAssetName {
                Image(raster)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? selectedForeground : iconTint)
                    .frame(width: size, alignment: .center)
                    .symbolRenderingMode(.monochrome)
            }
        case .emotionOrb:
            ZStack {
                if let raster = rasterAssetName {
                    Image(raster)
                        .renderingMode(.original)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(
                            isSelected
                                ? selectedForeground.opacity(0.2)
                                : AppTheme.divider.opacity(0.45)
                        )
                        .frame(width: size, height: size)
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? selectedForeground : iconTint)
                        .symbolRenderingMode(.monochrome)
                }
                Circle()
                    .strokeBorder(
                        isSelected ? selectedForeground.opacity(0.55) : iconTint.opacity(0.4),
                        lineWidth: isSelected ? 1.2 : 1
                    )
                    .frame(width: size, height: size)
            }
            .frame(width: size, height: size)
        }
    }

    private func filterSheetOptionChip(
        title: String,
        systemImage: String,
        iconTint: Color,
        isSelected: Bool,
        iconStyle: FilterChipIconStyle = .inline,
        selectedAccent: Color? = nil,
        selectedFillHex: String? = nil,
        rasterAssetName: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        let chipFill = isSelected
            ? (selectedAccent ?? FilterChrome.selectedFill)
            : Color.primary.opacity(0.04)
        let chipForeground = isSelected
            ? selectedChipForeground(fillHex: selectedFillHex)
            : AppTheme.textPrimary
        let animationKey = "\(isSelected)-\(selectedFillHex ?? "default")"

        return Button(action: action) {
            HStack(alignment: .center, spacing: 8) {
                filterChipIcon(
                    systemImage: systemImage,
                    iconTint: iconTint,
                    isSelected: isSelected,
                    selectedForeground: chipForeground,
                    rasterAssetName: rasterAssetName,
                    style: iconStyle
                )
                Text(title)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(chipForeground)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .background(chipFill)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: animationKey)
    }

    private func categoryFilterGrid(selection: Binding<Set<String>>) -> some View {
        LazyVGrid(columns: billFilterTagGridColumns, spacing: 8) {
            filterSheetOptionChip(
                title: localization.text(.commonAll),
                systemImage: "square.grid.2x2",
                iconTint: AppTheme.textSecondary,
                isSelected: selection.wrappedValue.isEmpty,
                selectedAccent: FilterChrome.selectedFill,
                selectedFillHex: "3F6F76"
            ) {
                selection.wrappedValue = []
            }

            ForEach(CategoryPreset.options) { option in
                let title = localization.text(option.key!)
                let accentHex = CategoryVisualStyle.accentHex(for: option.id)
                filterSheetOptionChip(
                    title: title,
                    systemImage: CategoryVisualStyle.iconName(for: option.id),
                    iconTint: CategoryVisualStyle.iconColor(for: option.id),
                    isSelected: selection.wrappedValue.contains(option.id),
                    selectedAccent: Color(hex: accentHex),
                    selectedFillHex: accentHex
                ) {
                    toggleCategoryKey(option.id, in: selection)
                }
            }

            ForEach(customCategoryOptions) { opt in
                let id = CustomOptionMutation.categoryKey(forName: opt.name)
                let symbol = opt.iconSymbolRaw.isEmpty ? "tag" : opt.iconSymbolRaw
                filterSheetOptionChip(
                    title: opt.name,
                    systemImage: symbol,
                    iconTint: AppTheme.actionBlue,
                    isSelected: selection.wrappedValue.contains(id),
                    selectedAccent: AppTheme.actionBlue,
                    selectedFillHex: "3F6F76"
                ) {
                    toggleCategoryKey(id, in: selection)
                }
            }
        }
    }

    private func toggleCategoryKey(_ key: String, in selection: Binding<Set<String>>) {
        if selection.wrappedValue.contains(key) {
            selection.wrappedValue.remove(key)
        } else {
            selection.wrappedValue.insert(key)
        }
    }

    private func emotionFilterGrid(selection: Binding<String?>) -> some View {
        LazyVGrid(columns: billFilterTagGridColumns, spacing: 8) {
            filterSheetOptionChip(
                title: localization.text(.commonAll),
                systemImage: "face.smiling",
                iconTint: AppTheme.textSecondary,
                isSelected: selection.wrappedValue == nil,
                iconStyle: .emotionOrb,
                selectedAccent: FilterChrome.selectedFill,
                selectedFillHex: "3F6F76"
            ) {
                selection.wrappedValue = nil
            }

            ForEach(EmotionTag.allCases) { tag in
                filterSheetOptionChip(
                    title: localization.text(tag.key),
                    systemImage: tag.sfSymbolName,
                    iconTint: Color(hex: tag.colorHex),
                    isSelected: selection.wrappedValue == tag.rawValue,
                    iconStyle: .emotionOrb,
                    selectedAccent: Color(hex: tag.colorHex),
                    selectedFillHex: tag.colorHex,
                    rasterAssetName: tag.rasterAssetName(for: appSettings.emotionIconStyle)
                ) {
                    if selection.wrappedValue == tag.rawValue {
                        selection.wrappedValue = nil
                    } else {
                        selection.wrappedValue = tag.rawValue
                    }
                }
            }

            ForEach(customEmotionOptions) { opt in
                let id = CustomOptionMutation.emotionRaw(forName: opt.name)
                let symbol = opt.iconSymbolRaw.isEmpty ? "heart.text.square" : opt.iconSymbolRaw
                let tintHex = opt.colorHex ?? EmotionTag.ritual.colorHex
                filterSheetOptionChip(
                    title: opt.name,
                    systemImage: symbol,
                    iconTint: Color(hex: tintHex),
                    isSelected: selection.wrappedValue == id,
                    iconStyle: .emotionOrb,
                    selectedAccent: Color(hex: tintHex),
                    selectedFillHex: tintHex
                ) {
                    if selection.wrappedValue == id {
                        selection.wrappedValue = nil
                    } else {
                        selection.wrappedValue = id
                    }
                }
            }
        }
    }

    private func bumpSparklineDrawGeneration() {
        sparklineDrawGeneration &+= 1
    }

    private func scheduleSparklineRecompute(playAnimation: Bool) {
        cachedSparklinePoints = BillListSparklineMetrics.points(
            expenses: sparklineScopeExpenses,
            period: periodContext.selectedPeriod,
            anchor: periodContext.targetDate,
            customRange: periodContext.customRange,
            calendar: periodContext.calendar
        )
        guard playAnimation else { return }
        bumpSparklineDrawGeneration()
    }

    private func syncSelectionsWithAvailableOptions() {
        selectedCategoryKeys = selectedCategoryKeys.filter { validCategoryKeys.contains($0) }
        if let e = selectedEmotionRaw, !validEmotionRaws.contains(e) {
            selectedEmotionRaw = nil
        }
    }

    private var metricDashboard: some View {
        BillListMetricDashboard(
            model: dashboardModel,
            onExpenseTap: { metricsDetailKind = .expense },
            onFrequencyTap: { metricsDetailKind = .frequency }
        )
    }

    private func metricsDetailModel(for kind: BillListMetricDetailKind) -> BillListMetricsDetailModel {
        BillListMetricsDetailModel.build(
            kind: kind,
            records: filteredRecords,
            totalExpense: totalExpense,
            customEmotions: customEmotionOptions,
            calendar: periodContext.calendar,
            categoryTitle: { displayCategoryTitle(forKey: $0) },
            emotionTitle: { displayEmotionTitle(forRaw: $0) }
        )
    }

    private func localizedTemplate(_ key: LKey, _ args: CVarArg...) -> String {
        String(format: localization.text(key), locale: localization.locale, arguments: args)
    }

    private func localizedTemplate(_ key: LKey, _ args: [CVarArg]) -> String {
        let format = localization.text(key)
        switch args.count {
        case 0:
            return format
        case 1:
            return String(format: format, locale: localization.locale, arguments: [args[0]])
        case 2:
            return String(format: format, locale: localization.locale, arguments: [args[0], args[1]])
        case 3:
            return String(format: format, locale: localization.locale, arguments: [args[0], args[1], args[2]])
        case 4:
            return String(
                format: format,
                locale: localization.locale,
                arguments: [args[0], args[1], args[2], args[3]]
            )
        default:
            return String(
                format: format,
                locale: localization.locale,
                arguments: [args[0], args[1], args[2], args[3]]
            )
        }
    }

    private func delete(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        recordPendingDelete = filteredRecords[index]
    }
}

#Preview {
    BillListView()
        .environmentObject(LocalizationManager())
        .environmentObject(AppSettings())
        .environmentObject(AppPeriodContext.shared)
        .environmentObject(NotificationCenterStore())
        .modelContainer(for: [TransactionRecord.self, CustomOption.self], inMemory: true)
}
