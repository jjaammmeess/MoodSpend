import SwiftData
import SwiftUI
import UIKit

struct HomeView: View {
    private struct MonthSpendingMetric {
        let totalExpense: Double
        let count: Int
        let records: [TransactionRecord]
    }

    private static let ledgerPreviewMaxCount = 10

    private static var hasPlayedLaunchHeroAnimation = false

    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var currencyManager: CurrencyManager
    @EnvironmentObject private var appSettings: AppSettings
    @EnvironmentObject private var notificationStore: NotificationCenterStore
    @EnvironmentObject private var appSyncState: AppSyncState
    @EnvironmentObject private var rootTab: RootTabCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    @State private var selectedRecord: TransactionRecord?
    @State private var showProfileEditor = false
    @State private var displayedMonthTotalExpense: Double = 0
    @State private var displayedMonthEffectiveExpense: Double = 0
    @State private var displayedMonthEmotionalExpense: Double = 0
    @State private var displayedMonthNecessaryExpense: Double = 0
    @State private var heroAnimationTask: Task<Void, Never>?
    @State private var heroBucketDetailSession: HomeHeroBucketDetailSession?

    private var monthMetric: MonthSpendingMetric {
        let calendar = Calendar.current
        let expenses = records.filter { $0.type == .expense }
        guard let interval = calendar.dateInterval(of: .month, for: Date()) else {
            return MonthSpendingMetric(totalExpense: 0, count: 0, records: [])
        }
        let filtered = expenses.filter { interval.contains($0.createdAt) }
        return MonthSpendingMetric(
            totalExpense: filtered.reduce(0) { $0 + $1.amount },
            count: filtered.count,
            records: filtered
        )
    }

    private var monthEffectiveExpense: Double {
        monthMetric.records
            .filter { isEffectiveEmotion($0) }
            .reduce(0) { $0 + $1.amount }
    }

    private var monthEmotionalExpense: Double {
        monthMetric.records
            .filter { isEmotionalEmotion($0) }
            .reduce(0) { $0 + $1.amount }
    }

    private var monthNecessaryExpense: Double {
        monthMetric.records
            .filter { isNecessaryEmotion($0) }
            .reduce(0) { $0 + $1.amount }
    }

    private var customEmotionOptions: [CustomOption] {
        customOptions.filter { $0.kind == .emotion }
    }

    private var ledgerPreviewRecords: [TransactionRecord] {
        Array(records.filter { $0.type == .expense }.prefix(Self.ledgerPreviewMaxCount))
    }

    private var moodSpectrumPayload: MoodSpectrumPayload {
        MoodSpectrumBuilder.build(
            recentExpensesChronological: MoodSpectrumBuilder.recentExpenseRecords(from: records),
            customEmotions: customEmotionOptions,
            localization: localization
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                homePinnedChrome

                ScrollView(.vertical, showsIndicators: false) {
                    homeRecentActivityScrollContent
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $selectedRecord) { record in
            RecordDetailView(record: record)
                .environmentObject(localization)
                .environmentObject(appSettings)
                .environmentObject(notificationStore)
        }
        .sheet(isPresented: $showProfileEditor) {
            ProfileEditView()
                .environmentObject(localization)
                .environmentObject(appSettings)
        }
        .sheet(item: $heroBucketDetailSession) { session in
            HomeHeroBucketDetailSheet(
                bucket: session.bucket,
                monthExpenses: monthMetric.records,
                monthTotalExpense: monthMetric.totalExpense,
                customEmotions: customEmotionOptions
            )
            .environmentObject(localization)
            .environmentObject(appSettings)
            .environmentObject(notificationStore)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onAppear(perform: refreshAlert)
        .onAppear {
            playHeroAnimationIfNeeded()
        }
        .onChange(of: records.count) {
            refreshAlert()
            if HomeView.hasPlayedLaunchHeroAnimation || reduceMotion {
                syncDisplayedHeroValuesToCurrentTotals()
            }
        }
        .onChange(of: appSettings.emotionAlertEnabled) {
            refreshAlert()
        }
        .onChange(of: appSettings.emotionAlertHighRiskOnly) {
            refreshAlert()
        }
        .onChange(of: currencyManager.code) { _, _ in
            syncDisplayedHeroValuesToCurrentTotals()
        }
        .onDisappear {
            heroAnimationTask?.cancel()
        }
    }

    private var topHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                showProfileEditor = true
            } label: {
                ProfileAvatarView(
                    imageData: appSettings.avatarImageData,
                    presetID: appSettings.avatarPresetID,
                    size: 56
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(localization.text(.homeWelcomeBack).uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Text(
                    AppBranding.resolvedDisplayName(
                        stored: appSettings.displayName,
                        language: localization.effectiveLanguage
                    )
                )
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            Spacer()
            CloudSyncStatusIndicator()
                .environmentObject(appSyncState)
            Button {
                rootTab.showNotificationCenter = true
            } label: {
                Circle()
                    .fill(AppTheme.cardBackground)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "bell")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.actionBlue)
                    )
                    .overlay(alignment: .topTrailing) {
                        if notificationStore.unreadCount > 0 {
                            Text(notificationBadgeText)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .frame(height: 16)
                                .background(AppTheme.accentRisk)
                                .clipShape(Capsule())
                                .offset(x: 6, y: -3)
                        }
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 2)
    }

    private var heroSummaryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    Text(heroCardTitleText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    monthDeltaBadge
                }

                Spacer(minLength: 4)

                emphasizedMoney(amount: displayedMonthTotalExpense)

                Spacer(minLength: 4)

                heroMetricRow
            }
            .frame(maxWidth: .infinity, minHeight: 166, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(
                LinearGradient(
                    colors: [Color(hex: "2D4F56"), Color(hex: "3F6F76"), Color(hex: "4B3A58")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(heroWaveTexture)
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        RadialGradient(
                            colors: [
                                AppTheme.accentSecondary.opacity(0.22),
                                .clear
                            ],
                            center: .topTrailing,
                            startRadius: 10,
                            endRadius: 180
                        )
                    )
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 8)
    }

    private var heroWaveTexture: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                // B profile: clearer three-layer wave texture.
                ZStack {
                    waveLine(
                        width: width,
                        height: height,
                        baseY: height * 0.33,
                        amplitude: 8,
                        frequency: 0.022,
                        phase: 0.0,
                        color: Color.white.opacity(0.26),
                        lineWidth: 2.0
                    )
                    waveLine(
                        width: width,
                        height: height,
                        baseY: height * 0.52,
                        amplitude: 6,
                        frequency: 0.018,
                        phase: 1.2,
                        color: AppTheme.accentSecondary.opacity(0.18),
                        lineWidth: 1.4
                    )
                    waveLine(
                        width: width,
                        height: height,
                        baseY: height * 0.70,
                        amplitude: 4,
                        frequency: 0.025,
                        phase: 2.1,
                        color: Color.white.opacity(0.12),
                        lineWidth: 1.0
                    )
                }

                // Right-top emphasis: stronger lines near delta badge.
                ZStack {
                    waveLine(
                        width: width,
                        height: height,
                        baseY: height * 0.30,
                        amplitude: 8,
                        frequency: 0.02,
                        phase: 0.9,
                        color: Color.white.opacity(0.28),
                        lineWidth: 2.0
                    )
                    waveLine(
                        width: width,
                        height: height,
                        baseY: height * 0.44,
                        amplitude: 6,
                        frequency: 0.024,
                        phase: 2.4,
                        color: AppTheme.accentWarning.opacity(0.20),
                        lineWidth: 1.4
                    )
                }
                .mask(
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.25),
                            Color.white
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

                // Soft top-half glow to make wave ridges more visible.
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.16),
                                Color.white.opacity(0.06),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .mask(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color.white.opacity(0.8),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .padding(.horizontal, 4)
            .mask(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.24),
                                Color.white.opacity(0.92),
                                Color.white.opacity(0.74)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
        }
        .allowsHitTesting(false)
    }

    private func waveLine(
        width: CGFloat,
        height: CGFloat,
        baseY: CGFloat,
        amplitude: CGFloat,
        frequency: CGFloat,
        phase: CGFloat,
        color: Color,
        lineWidth: CGFloat
    ) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: baseY))
            var x: CGFloat = 0
            while x <= width {
                let y = baseY + sin((x * frequency) + phase) * amplitude
                path.addLine(to: CGPoint(x: x, y: y))
                x += 2
            }
        }
        .stroke(color, lineWidth: lineWidth)
    }

    private var monthDeltaBadge: some View {
        let iconName: String = {
            if monthDeltaText.contains("--") { return "minus" }
            return monthDeltaText.contains("+") ? "arrow.up.right" : "arrow.down.right"
        }()
        return HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .bold))
            Text(monthDeltaText)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(Color.white.opacity(0.92))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.14))
        .clipShape(Capsule())
    }

    private var heroCardTitleText: String {
        heroDisplayTitle(
            standard: .homeHeroTitle,
            compact: .homeHeroTitleCompact
        )
    }

    private func heroMetricTitle(_ key: LKey) -> String {
        switch key {
        case .homeEffectiveSpend:
            return heroDisplayTitle(standard: .homeEffectiveSpend, compact: .homeEffectiveSpendCompact)
        case .homeEmotionalSpend:
            return heroDisplayTitle(standard: .homeEmotionalSpend, compact: .homeEmotionalSpendCompact)
        case .homeNecessarySpend:
            return heroDisplayTitle(standard: .homeNecessarySpend, compact: .homeNecessarySpendCompact)
        default:
            return localization.text(key)
        }
    }

    private func heroDisplayTitle(standard: LKey, compact: LKey) -> String {
        let text = localization.effectiveLanguage == .en
            ? localization.text(compact)
            : localization.text(standard)
        return heroTitleUsesUppercase ? text.uppercased() : text
    }

    private var heroTitleUsesUppercase: Bool {
        localization.effectiveLanguage != .en
    }

    private var heroMetricRow: some View {
        GeometryReader { geometry in
            let amounts = [
                displayedMonthEffectiveExpense,
                displayedMonthEmotionalExpense,
                displayedMonthNecessaryExpense
            ]
            let roles: [HomeHeroMetricColumnRole] = [.side, .center, .side]
            let idealWidths = zip(amounts, roles).map { amount, role in
                heroMetricMoneyIdealWidth(for: amount, role: role)
            }
            let columnWidths = HomeHeroMetricLayout.columnWidths(
                totalWidth: geometry.size.width,
                idealWidths: idealWidths
            )
            let moneyScale = HomeHeroMetricLayout.globalMoneyScale(
                columnWidths: columnWidths,
                idealWidths: idealWidths
            )

            HStack(alignment: .top, spacing: HomeHeroMetricLayout.rowSpacing) {
                heroMetricBlock(
                    bucket: .effective,
                    title: heroMetricTitle(.homeEffectiveSpend),
                    amount: displayedMonthEffectiveExpense,
                    dotColor: AppTheme.accentSecondary,
                    columnWidth: columnWidths[0],
                    moneyRole: .side,
                    moneyScale: moneyScale
                )
                heroMetricColumnDivider
                heroMetricBlock(
                    bucket: .emotional,
                    title: heroMetricTitle(.homeEmotionalSpend),
                    amount: displayedMonthEmotionalExpense,
                    dotColor: AppTheme.accentRisk,
                    columnWidth: columnWidths[1],
                    moneyRole: .center,
                    moneyScale: moneyScale
                )
                heroMetricColumnDivider
                heroMetricBlock(
                    bucket: .necessary,
                    title: heroMetricTitle(.homeNecessarySpend),
                    amount: displayedMonthNecessaryExpense,
                    dotColor: AppTheme.accentWarning,
                    columnWidth: columnWidths[2],
                    moneyRole: .side,
                    moneyScale: moneyScale
                )
            }
        }
        .frame(height: HomeHeroMetricLayout.rowHeight)
    }

    private var heroMetricColumnDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: HomeHeroMetricLayout.dividerLineWidth)
            .frame(maxHeight: 44)
            .padding(.horizontal, HomeHeroMetricLayout.dividerPadding)
    }

    private func heroMetricBlock(
        bucket: EmotionBucket,
        title: String,
        amount: Double,
        dotColor: Color,
        columnWidth: CGFloat,
        moneyRole: HomeHeroMetricColumnRole,
        moneyScale: CGFloat
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            heroBucketDetailSession = HomeHeroBucketDetailSession(bucket: bucket)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 6) {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 7, height: 7)
                        .padding(.top, 3)
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }

                compactMoney(amount: amount, color: Color.white, role: moneyRole, scale: moneyScale)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: columnWidth, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(title), \(moneyText(amount))"))
        .accessibilityHint(Text(localization.text(.homeHeroBucketDetailOpenA11yHint)))
    }

    private func heroMetricMoneyIdealWidth(
        for amount: Double,
        role: HomeHeroMetricColumnRole
    ) -> CGFloat {
        let parts = amountParts(amount)
        let majorFont = UIFont.monospacedDigitSystemFont(
            ofSize: role.majorFontSize,
            weight: .semibold
        )
        let minorFont = UIFont.monospacedDigitSystemFont(
            ofSize: role.minorFontSize,
            weight: .semibold
        )
        let majorWidth = (parts.major as NSString).size(withAttributes: [.font: majorFont]).width
        let minorWidth = (parts.minor as NSString).size(withAttributes: [.font: minorFont]).width
        return ceil(majorWidth + minorWidth) + 2
    }

    /// Avatar, hero card, mood spectrum, and mind-state copy — locked above the ledger scroll.
    private var homePinnedChrome: some View {
        VStack(alignment: .leading, spacing: 16) {
            topHeader
            heroSummaryCard
            MoodSpectrumView(payload: moodSpectrumPayload)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 16)
    }

    private var homeRecentActivityScrollContent: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            recentActivityHeader

            if ledgerPreviewRecords.isEmpty {
                EmptyStateBlock(
                    title: localization.text(.homeEmptyTip),
                    systemImage: "tray"
                )
            } else {
                ForEach(ledgerPreviewRecords) { record in
                    recentRecordCard(record)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(minHeight: 80)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .onTapGesture {
                            selectedRecord = record
                        }
                }
            }
        }
        .padding(.top, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recentActivityHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(localization.text(.homeRecentActivity))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Button(localization.text(.homeViewAll)) {
                rootTab.selected = .bills
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppTheme.actionBlue)
        }
    }

    private func recentRecordCard(_ record: TransactionRecord) -> some View {
        HStack(alignment: .center, spacing: 10) {
            CategoryIconBadge(
                categoryKey: record.categoryKey,
                iconSymbolOverride: record.categoryIconSymbolRaw,
                backgroundColor: record.emotionColor,
                size: 36,
                cornerRadius: 10,
                iconSize: 15
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(displayCategory(record))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text(AppFormatter.dayTimeString(from: record.createdAt, locale: localization.locale))
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    if RecordAttachmentIndicators.hasContent(record) {
                        RecordAttachmentIndicators(record: record)
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text("-\(moneyText(record.amount))")
                    .font(.system(size: 18, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                EmotionTagCapsule(
                    title: displayEmotion(raw: record.emotionRaw, fallback: record.safeEmotionName),
                    record: record
                )
            }
        }
    }

    private var monthDeltaText: String {
        let current = monthMetric.totalExpense
        let previous = previousMonthTotalExpense
        let noneKey: LKey = localization.effectiveLanguage == .en ? .homeWeekDeltaNoneCompact : .homeWeekDeltaNone
        let deltaKey: LKey = localization.effectiveLanguage == .en ? .homeWeekDeltaCompact : .homeWeekDelta
        // Guard against misleading spikes when the baseline is too small.
        if previous < 10 {
            return localization.text(noneKey)
        }
        guard previous > 0 else { return localization.text(noneKey) }
        let ratio = (current - previous) / previous
        let percent = Int((ratio * 100).rounded())
        let sign = percent >= 0 ? "+" : ""
        return String(
            format: localization.text(deltaKey),
            locale: localization.locale,
            arguments: ["\(sign)\(percent)%"]
        )
    }

    private var previousMonthTotalExpense: Double {
        let calendar = Calendar.current
        guard let currentInterval = calendar.dateInterval(of: .month, for: Date()) else { return 0 }
        guard let start = calendar.date(byAdding: .month, value: -1, to: currentInterval.start) else { return 0 }
        guard let previousInterval = calendar.dateInterval(of: .month, for: start) else { return 0 }
        return records
            .filter { $0.type == .expense && previousInterval.contains($0.createdAt) }
            .reduce(0) { $0 + $1.amount }
    }

    private func moneyText(_ amount: Double) -> String {
        amount.formattedAsMoney(currencyManager: currencyManager, locale: localization.locale)
    }

    private func emphasizedMoney(amount: Double) -> some View {
        scalableHeroMoneyText(
            heroMoneyAttributedString(
                amount: amount,
                majorSize: 42,
                majorWeight: .bold,
                minorSize: 26,
                minorWeight: .semibold,
                color: .white,
                minorColor: Color.white.opacity(0.9)
            ),
            minScale: 0.7
        )
    }

    private func compactMoney(
        amount: Double,
        color: Color,
        role: HomeHeroMetricColumnRole,
        scale: CGFloat
    ) -> some View {
        let clampedScale = max(scale, HomeHeroMetricLayout.minGlobalMoneyScale)
        let majorSize = role.majorFontSize * clampedScale
        let minorSize = role.minorFontSize * clampedScale
        let minScale: CGFloat = clampedScale < 0.999 ? 1 : 0.6

        return scalableHeroMoneyText(
            heroMoneyAttributedString(
                amount: amount,
                majorSize: majorSize,
                majorWeight: .semibold,
                minorSize: minorSize,
                minorWeight: .semibold,
                color: color,
                minorColor: color.opacity(0.82)
            ),
            minScale: minScale
        )
    }

    private func heroMoneyAttributedString(
        amount: Double,
        majorSize: CGFloat,
        majorWeight: Font.Weight,
        minorSize: CGFloat,
        minorWeight: Font.Weight,
        color: Color,
        minorColor: Color
    ) -> AttributedString {
        let parts = amountParts(amount)
        var result = AttributedString(parts.major)
        result.font = .system(size: majorSize, weight: majorWeight).monospacedDigit()
        result.foregroundColor = color

        var minor = AttributedString(parts.minor)
        minor.font = .system(size: minorSize, weight: minorWeight).monospacedDigit()
        minor.foregroundColor = minorColor
        result.append(minor)
        return result
    }

    private func scalableHeroMoneyText(_ content: AttributedString, minScale: CGFloat) -> some View {
        Text(content)
            .lineLimit(1)
            .minimumScaleFactor(minScale)
            .allowsTightening(true)
            .scaledToFit()
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private func amountParts(_ amount: Double) -> (major: String, minor: String) {
        let parts = amount.moneyDisplayParts(currencyManager: currencyManager, locale: localization.locale)
        return (parts.major, parts.minor)
    }

    private func localizedTemplate(_ key: LKey, _ args: CVarArg...) -> String {
        String(format: localization.text(key), locale: localization.locale, arguments: args)
    }

    private var notificationBadgeText: String {
        let count = notificationStore.unreadCount
        return count > 99 ? "99+" : "\(count)"
    }

    private func displayEmotion(raw: String, fallback: String) -> String {
        if let preset = EmotionTag.from(raw: raw) {
            return localization.text(preset.key)
        }
        return fallback
    }

    private func displayCategory(_ record: TransactionRecord) -> String {
        if let key = LKey(rawValue: record.categoryKey) {
            return localization.text(key)
        }
        return record.safeCategoryName
    }

    private func relativeDayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return localization.text(.commonToday) }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return localization.text(.commonYesterday)
        }
        return AppFormatter.dayString(from: date, locale: localization.locale)
    }

    private func isEffectiveEmotion(_ record: TransactionRecord) -> Bool {
        EmotionGrouping.isEffective(record, customEmotions: customEmotionOptions)
    }

    private func isEmotionalEmotion(_ record: TransactionRecord) -> Bool {
        EmotionGrouping.isEmotional(record, customEmotions: customEmotionOptions)
    }

    private func isNecessaryEmotion(_ record: TransactionRecord) -> Bool {
        EmotionGrouping.isNecessary(record, customEmotions: customEmotionOptions)
    }

    private func refreshAlert() {
        guard appSettings.emotionAlertEnabled else { return }

        guard let candidate = EmotionAlertService.detectCandidate(
            records: records,
            customEmotions: customEmotionOptions,
            highRiskOnly: appSettings.emotionAlertHighRiskOnly,
            locale: localization.locale,
            text: localization.text
        ) else {
            return
        }
        guard appSettings.consumeEmotionAlertIfNeeded(emotionRaw: candidate.emotionRaw) else {
            return
        }
        notificationStore.addWarning(
            title: candidate.title,
            message: candidate.message,
            emotionRaw: candidate.emotionRaw,
            count: candidate.count,
            amount: candidate.amount
        )
    }

    private func syncDisplayedHeroValuesToCurrentTotals() {
        displayedMonthTotalExpense = monthMetric.totalExpense
        displayedMonthEffectiveExpense = monthEffectiveExpense
        displayedMonthEmotionalExpense = monthEmotionalExpense
        displayedMonthNecessaryExpense = monthNecessaryExpense
    }

    private func playHeroAnimationIfNeeded() {
        heroAnimationTask?.cancel()

        let targetTotal = monthMetric.totalExpense
        let targetEffective = monthEffectiveExpense
        let targetEmotional = monthEmotionalExpense
        let targetNecessary = monthNecessaryExpense

        guard !reduceMotion, !HomeView.hasPlayedLaunchHeroAnimation else {
            displayedMonthTotalExpense = targetTotal
            displayedMonthEffectiveExpense = targetEffective
            displayedMonthEmotionalExpense = targetEmotional
            displayedMonthNecessaryExpense = targetNecessary
            return
        }

        displayedMonthTotalExpense = 0
        displayedMonthEffectiveExpense = 0
        displayedMonthEmotionalExpense = 0
        displayedMonthNecessaryExpense = 0
        HomeView.hasPlayedLaunchHeroAnimation = true

        heroAnimationTask = Task { @MainActor in
            let frameCount = 45
            let frameDurationNs: UInt64 = 20_000_000 // ~0.9s total

            for frame in 1...frameCount {
                if Task.isCancelled { return }
                let progress = Double(frame) / Double(frameCount)
                let eased = 1 - pow(1 - progress, 3)

                displayedMonthTotalExpense = targetTotal * eased
                displayedMonthEffectiveExpense = targetEffective * eased
                displayedMonthEmotionalExpense = targetEmotional * eased
                displayedMonthNecessaryExpense = targetNecessary * eased

                try? await Task.sleep(nanoseconds: frameDurationNs)
            }

            displayedMonthTotalExpense = targetTotal
            displayedMonthEffectiveExpense = targetEffective
            displayedMonthEmotionalExpense = targetEmotional
            displayedMonthNecessaryExpense = targetNecessary
        }
    }

}

// MARK: - Hero bucket row (content-aware widths + side/center typography)

private enum HomeHeroMetricColumnRole {
    case side
    case center

    var majorFontSize: CGFloat {
        switch self {
        case .side: return 20
        case .center: return 24
        }
    }

    var minorFontSize: CGFloat {
        switch self {
        case .side: return 12
        case .center: return 14
        }
    }
}

private enum HomeHeroMetricLayout {
    static let rowSpacing: CGFloat = 8
    static let dividerLineWidth: CGFloat = 1
    static let dividerPadding: CGFloat = 4
    static let rowHeight: CGFloat = 56
    static let minColumnWidth: CGFloat = 52
    static let minGlobalMoneyScale: CGFloat = 0.5

    private static var dividerOccupiedWidth: CGFloat {
        dividerLineWidth + dividerPadding * 2
    }

    private static var fixedRowOverhead: CGFloat {
        let gapCount: CGFloat = 4
        let dividerCount: CGFloat = 2
        return gapCount * rowSpacing + dividerCount * dividerOccupiedWidth
    }

    /// Distributes width by measured ideal money width (not equal thirds).
    static func columnWidths(totalWidth: CGFloat, idealWidths: [CGFloat]) -> [CGFloat] {
        let columnCount = 3
        guard idealWidths.count == columnCount else {
            let equal = max((totalWidth - fixedRowOverhead) / CGFloat(columnCount), 0)
            return Array(repeating: equal, count: columnCount)
        }

        let available = max(totalWidth - fixedRowOverhead, 0)
        let weightSum = idealWidths.reduce(0, +)

        if weightSum <= 0 {
            let equal = available / CGFloat(columnCount)
            return [equal, equal, equal]
        }

        let minTotal = minColumnWidth * CGFloat(columnCount)
        if available <= minTotal {
            let equal = available / CGFloat(columnCount)
            return [equal, equal, equal]
        }

        let flex = available - minTotal
        return idealWidths.map { minColumnWidth + flex * ($0 / weightSum) }
    }

    /// When any column cannot fit at its role’s base size, all three amounts share this scale.
    static func globalMoneyScale(columnWidths: [CGFloat], idealWidths: [CGFloat]) -> CGFloat {
        guard columnWidths.count == idealWidths.count, !columnWidths.isEmpty else { return 1 }

        var minRatio: CGFloat = 1
        for (columnWidth, idealWidth) in zip(columnWidths, idealWidths) {
            guard idealWidth > 0 else { continue }
            minRatio = min(minRatio, columnWidth / idealWidth)
        }

        if minRatio >= 0.999 {
            return 1
        }
        return max(minRatio, minGlobalMoneyScale)
    }
}

#Preview {
    HomeView()
        .environmentObject(RootTabCoordinator())
        .environmentObject(LocalizationManager())
        .environmentObject(CurrencyManager())
        .environmentObject(AppSettings())
        .environmentObject(NotificationCenterStore())
        .environmentObject(AppSyncState())
        .modelContainer(PersistenceController.inMemoryForPreviews().modelContainer)
}
