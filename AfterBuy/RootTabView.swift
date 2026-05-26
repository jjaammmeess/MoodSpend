import SwiftData
import SwiftUI
import UIKit

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var currencyManager: CurrencyManager
    @EnvironmentObject private var appSettings: AppSettings
    @EnvironmentObject private var notificationStore: NotificationCenterStore
    @EnvironmentObject private var appSyncState: AppSyncState
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var rootTab = RootTabCoordinator()
    @StateObject private var analysisMetricsStore = AnalysisTabMetricsStore()
    @StateObject private var analysisScrollActivity = AnalysisScrollActivityTracker()
    @State private var homeIndicatorInset: CGFloat = 0
    @State private var foregroundRefreshTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                /// Only mount the selected tab so hidden tabs do not participate in DisplayLink / TimelineView work.
                Group {
                    switch rootTab.selected {
                    case .home:
                        HomeView().environment(\.isTabActive, true)
                    case .bills:
                        BillListView().environment(\.isTabActive, true)
                    case .analysis:
                        AnalysisView(initialSnapshot: analysisMetricsStore.snapshot)
                            .environment(\.isTabActive, true)
                    case .mine:
                        MineView().environment(\.isTabActive, true)
                    }
                }
                .id(currencyManager.code)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                /// Let scroll views extend under the floating tab chrome so list cells remain visible in transparent margins; keep end insets for scrollability.
                .contentMargins(.bottom, contentBottomInset, for: .scrollContent)

                if !rootTab.showQuickRecordSheet {
                    customFloatingTabBar
                        .padding(.horizontal, AppTheme.cardPadding)
                        /// Tab plate sits flush with the physical bottom; home-indicator clearance is **inside** the plate.
                        .padding(.bottom, 0)
                }
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
            /// Align chrome to the **physical** bottom like `UITabBar`; `homeIndicatorInset` lifts icons above the home indicator only.
            .ignoresSafeArea(edges: .bottom)
        }
        /// Present as sheet — `navigationDestination` on this outer stack conflicts with each tab's inner `NavigationStack` and can freeze on push.
        .sheet(isPresented: $rootTab.showQuickRecordSheet) {
            NavigationStack {
                RecordSheetView()
                    .environmentObject(localization)
                    .environmentObject(appSettings)
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $rootTab.showNotificationCenter, onDismiss: handleNotificationCenterDismissed) {
            NotificationCenterView { item in
                rootTab.pendingHandledNotification = item
            }
            .environmentObject(localization)
            .environmentObject(notificationStore)
        }
        .environmentObject(rootTab)
        .environmentObject(analysisMetricsStore)
        .environmentObject(analysisScrollActivity)
        .onAppear {
            syncHomeIndicatorInset()
            Task { @MainActor in
                EmotionBucketSnapshotSync.syncNilSnapshotsFromMatchingOptions(modelContext: modelContext)
                TransactionRecordPublicIdSync.ensureUniquePublicIds(modelContext: modelContext)
                CustomOptionPublicIdSync.ensureUniquePublicIds(modelContext: modelContext)
                refreshNotificationLocalization()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            syncHomeIndicatorInset()
            appSyncState.refreshICloudAvailability()
            scheduleForegroundRefresh()
        }
        .onChange(of: localization.language) { _, _ in
            refreshNotificationLocalization()
        }
        .onChange(of: notificationStore.pendingRetrospectivePublicId) { _, newId in
            if newId != nil {
                selectTabWithoutContentAnimation(.analysis)
            }
        }
        .onChange(of: notificationStore.pendingRetrospectivePersistentToken) { _, newToken in
            if newToken != nil {
                selectTabWithoutContentAnimation(.analysis)
            }
        }
    }

    private func scheduleForegroundRefresh() {
        foregroundRefreshTask?.cancel()
        foregroundRefreshTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            if rootTab.selected == .analysis {
                await analysisScrollActivity.waitUntilIdle(maxWaitMilliseconds: 3_000)
                guard !Task.isCancelled else { return }
            }

            SyncedStoreRefreshCoordinator.refreshAfterRemoteChange(
                modelContext: modelContext,
                appSettings: appSettings,
                notificationStore: notificationStore,
                localization: localization
            )
            refreshNotificationLocalization()
        }
    }

    private func syncHomeIndicatorInset() {
        homeIndicatorInset = WindowSafeArea.bottomInset()
    }

    /// Avoid cross-fade when swapping tab roots; do not apply to in-tab UI animations (e.g. sparkline draw).
    private func selectTabWithoutContentAnimation(_ tab: AppRootTab) {
        rootTab.selectTab(tab, contentAnimation: false)
    }

    private func handleNotificationCenterDismissed() {
        guard let item = rootTab.pendingHandledNotification else { return }
        rootTab.pendingHandledNotification = nil
        switch item.action {
        case .openAddRecord:
            rootTab.presentQuickRecord(afterDelayMs: 350)
        case .openAnalysis:
            rootTab.selectTab(.analysis, afterDelayMs: 350, contentAnimation: false)
        case .openRecordRetrospective:
            notificationStore.pendingRetrospectivePublicId = nil
            notificationStore.pendingRetrospectivePersistentToken = nil
            if let pid = item.linkedRecordId {
                notificationStore.pendingRetrospectivePublicId = pid
            } else if let token = item.linkedRecordPersistentToken {
                notificationStore.pendingRetrospectivePersistentToken = token
            }
        case .none:
            break
        }
    }

    private func refreshNotificationLocalization() {
        notificationStore.seedIfNeeded(
            systemTitle: localization.text(.notificationSystemWelcomeTitle),
            systemMessage: localization.text(.notificationSystemWelcomeMessage),
            taskTitle: localization.text(.notificationTaskStarterTitle),
            taskMessage: localization.text(.notificationTaskStarterMessage)
        )
        notificationStore.refreshSeedLocalization(
            systemTitle: localization.text(.notificationSystemWelcomeTitle),
            systemMessage: localization.text(.notificationSystemWelcomeMessage),
            taskTitle: localization.text(.notificationTaskStarterTitle),
            taskMessage: localization.text(.notificationTaskStarterMessage)
        )
        notificationStore.refreshWarningLocalization(
            locale: localization.locale,
            text: localization.text
        )
        notificationStore.refreshRetrospectiveTaskLocalization(
            modelContext: modelContext,
            locale: localization.locale,
            localizedText: localization.text,
            formatMoney: { amt in
                AppFormatter.moneyString(from: amt, locale: localization.locale)
            }
        )
    }

    /// White plate extends `pillHeight` + this band below the icon row; slightly **less** than the window safe inset so the row sits lower (less empty white under icons).
    private var effectiveHomeBand: CGFloat {
        max(0, homeIndicatorInset - Self.tabBarHomeBandCompression)
    }

    /// Clears tab chrome: icon row + compressed home band inside the plate + squircle protrusion.
    private var contentBottomInset: CGFloat {
        Self.pillHeight + effectiveHomeBand + Self.squircleProtrusionAbovePill
    }

    private var customFloatingTabBar: some View {
        let homeBand = effectiveHomeBand
        let plateHeight = Self.pillHeight + homeBand

        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: Self.pillCornerRadius, style: .continuous)
                .fill(AppTheme.cardBackground)
                .shadow(color: AppTheme.cardShadow, radius: 14, x: 0, y: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: Self.pillCornerRadius, style: .continuous)
                        .stroke(AppTheme.border.opacity(0.55), lineWidth: 1)
                )
                .frame(height: plateHeight)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    HStack(spacing: 0) {
                        tabIconButton(
                            tab: .home,
                            icon: "house",
                            iconSelected: "house.fill",
                            accessibilityTitle: localization.text(.tabHome)
                        )
                        tabIconButton(
                            tab: .bills,
                            icon: "list.bullet.rectangle",
                            iconSelected: "list.bullet.rectangle.fill",
                            accessibilityTitle: localization.text(.tabBills)
                        )
                    }
                    .frame(maxWidth: .infinity)

                    Color.clear
                        .frame(width: Self.quickRecordHitSide)

                    HStack(spacing: 0) {
                        tabIconButton(
                            tab: .analysis,
                            icon: "chart.pie",
                            iconSelected: "chart.pie.fill",
                            accessibilityTitle: localization.text(.tabAnalysis)
                        )
                        tabIconButton(
                            tab: .mine,
                            icon: "person",
                            iconSelected: "person.fill",
                            accessibilityTitle: localization.text(.tabMine)
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: Self.pillHeight)

                if homeBand > 0.5 {
                    Color.clear.frame(height: homeBand)
                }
            }

            quickRecordSquircle
                .buttonStyle(QuickRecordSquircleButtonStyle())
                .offset(
                    y: -plateHeight / 2 - Self.quickRecordSquircleSize / 2 + Self.squircleOverlapIntoPill
                        + Self.quickRecordSquircleDownNudge
                )
        }
        .frame(height: plateHeight + Self.squircleProtrusionAbovePill, alignment: .bottom)
    }

    private func tabIconButton(tab: AppRootTab, icon: String, iconSelected: String, accessibilityTitle: String) -> some View {
        let selected = rootTab.selected == tab
        return Button {
            selectTabWithoutContentAnimation(tab)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: selected ? iconSelected : icon)
                    .font(.system(size: Self.tabBarIconPointSize, weight: selected ? .semibold : .regular))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(selected ? AppTheme.actionBlue : AppTheme.textPrimary)

                Circle()
                    .fill(selected ? AppTheme.actionBlue : Color.clear)
                    .frame(width: Self.tabSelectionDotSize, height: Self.tabSelectionDotSize)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.pillHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var quickRecordSquircle: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            rootTab.presentQuickRecord()
        } label: {
            QuickRecordSquircleIcon(
                squircleSize: QuickRecordSquircleMetrics.tabBarSquircleSize,
                hitSide: QuickRecordSquircleMetrics.tabBarHitSide
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: QuickRecordSquircleMetrics.tabBarCornerRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(QuickRecordSquircleButtonStyle())
        .accessibilityLabel(localization.text(.homeActionAdd))
    }

    /// Shorter bottom band inside the tab plate than `safeAreaInsets.bottom` so icons sit lower; raise if taps feel too close to the home indicator.
    private static let tabBarHomeBandCompression: CGFloat = 20

    private static let pillHeight: CGFloat = 54
    private static let tabBarIconPointSize: CGFloat = 26
    private static let tabSelectionDotSize: CGFloat = 4.5
    private static let pillCornerRadius: CGFloat = 27

    /// Vertical space reserved above the pill so the “+” can straddle the top edge without clipping list content.
    private static let squircleProtrusionAbovePill: CGFloat = 26

    /// Positive = move the “+” squircle **down** (pt).
    private static let quickRecordSquircleDownNudge: CGFloat = 10

    /// Positive value pulls the squircle downward so more of it sits on the pill (pt).
    private static let squircleOverlapIntoPill: CGFloat = 14

    private static let quickRecordSquircleSize: CGFloat = QuickRecordSquircleMetrics.tabBarSquircleSize
    private static let quickRecordHitSide: CGFloat = QuickRecordSquircleMetrics.tabBarHitSide
}

#Preview {
    RootTabView()
        .environmentObject(LocalizationManager())
        .environmentObject(AppSettings())
        .environmentObject(NotificationCenterStore())
        .environmentObject(AppSyncState())
        .modelContainer(PersistenceController.inMemoryForPreviews().modelContainer)
}
