import SwiftData
import SwiftUI
import UIKit

struct MineView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var currencyManager: CurrencyManager
    @EnvironmentObject private var appSettings: AppSettings
    @EnvironmentObject private var notificationStore: NotificationCenterStore
    @EnvironmentObject private var appSyncState: AppSyncState

    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @Query(filter: #Predicate<TransactionRecord> { $0.deletedAt == nil }) private var records: [TransactionRecord]
    @State private var showProfileEditor = false
    @State private var showPaywall = false
    @State private var showRestoreSuccessBanner = false
    @State private var showRestoreFailedAlert = false

    var body: some View {
        ZStack(alignment: .top) {
            minePageUnifiedBackground
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    profileHeroSection
                    proMembershipBanner
                    languageGroup
                    advancedFeaturesGroup
                    aboutGroup
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 12)
                .background(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .scrollEdgeEffectHiddenIfAvailable()

            if showRestoreSuccessBanner {
                restoreSuccessBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showProfileEditor) {
            ProfileEditView()
                .environmentObject(localization)
                .environmentObject(appSettings)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(source: .general)
                .environmentObject(localization)
        }
        .alert(
            localization.text(.paywallRestoreFailed),
            isPresented: $showRestoreFailedAlert
        ) {
            Button(localization.text(.commonOk), role: .cancel) {}
        }
    }

    // MARK: - Background

    private var minePageUnifiedBackground: some View {
        LinearGradient(
            stops: [
                .init(color: AppTheme.mineHeroWashA.opacity(0.45), location: 0),
                .init(color: AppTheme.mineHeroWashB.opacity(0.28), location: 0.22),
                .init(color: AppTheme.pageBackground, location: 0.48),
                .init(color: AppTheme.pageBackground, location: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Profile hero

    private var profileHeroSection: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                Button {
                    showProfileEditor = true
                } label: {
                    ProfileAvatarView(
                        imageData: appSettings.avatarImageData,
                        presetID: appSettings.avatarPresetID,
                        size: 92
                    )
                    .overlay(
                        Circle()
                            .stroke(AppTheme.cardBackground, lineWidth: 4)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showProfileEditor = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(AppTheme.mineHeroEditBadgeFill))
                        .overlay(
                            Circle()
                                .stroke(AppTheme.cardBackground, lineWidth: 2.5)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localization.text(.mineAvatarEditTitle))
                .offset(x: 4, y: 4)
            }
            .frame(width: 100, height: 100)

            Text(
                AppBranding.resolvedDisplayName(
                    stored: appSettings.displayName,
                    language: localization.effectiveLanguage
                )
            )
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    // MARK: - Pro membership banner

    private var proMembershipBanner: some View {
        Button {
            if !subscriptionManager.isPro {
                showPaywall = true
            }
        } label: {
            HStack(alignment: .center, spacing: 14) {
                PaywallBrandMark(size: 44)

                VStack(alignment: .leading, spacing: 6) {
                    Text(proBannerTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.leading)

                    Text(proBannerSubtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.white.opacity(subscriptionManager.isPro ? 0.78 : 0.62))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if !subscriptionManager.isPro {
                    HStack(spacing: 6) {
                        Text(localization.text(.mineProBannerLearnMore))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.92))

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.75))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.14))
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(proBannerBackground)
            .shadow(color: AppTheme.mineCardShadowColor.opacity(0.85), radius: 12, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(subscriptionManager.isPro)
        .accessibilityHint(
            subscriptionManager.isPro
                ? localization.text(.mineProBannerOwnedSubtitle)
                : localization.text(.mineProBannerLearnMore)
        )
    }

    private var proBannerBackground: some View {
        RoundedRectangle(cornerRadius: AppTheme.mineCardCornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [AppTheme.mineHeroStripGradientStart, AppTheme.mineHeroStripGradientEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.mineCardCornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.18))
            }
    }

    private var proBannerTitle: String {
        if subscriptionManager.isPro {
            let name = AppBranding.productName(for: localization.effectiveLanguage)
            return String(
                format: localization.text(.mineProBannerOwnedTitle),
                locale: localization.locale,
                arguments: [name]
            )
        }
        return localization.text(.mineProBannerUpgradeTitle)
    }

    private var proBannerSubtitle: String {
        subscriptionManager.isPro
            ? localization.text(.mineProBannerOwnedSubtitle)
            : localization.text(.mineProBannerUpgradeSubtitle)
    }

    // MARK: - Restore success banner

    private var restoreSuccessBanner: some View {
        VStack {
            Spacer()
            Text(localization.text(.mineProRestoreSuccess))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background {
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: AppTheme.mineCardShadowColor.opacity(0.5), radius: 10, y: 4)
                }
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }

    // MARK: - Settings groups

    private var languageGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            MineSettingsGroupHeader(title: localization.text(.mineSectionBasic))
            MineSettingsCard {
                Menu {
                    Button(localization.text(.mineLanguageSystem)) {
                        localization.language = .system
                    }
                    Button(localization.text(.mineLanguageChinese)) {
                        localization.language = .zhHans
                    }
                    Button(localization.text(.mineLanguageTraditionalChinese)) {
                        localization.language = .zhHant
                    }
                    Button(localization.text(.mineLanguageEnglish)) {
                        localization.language = .en
                    }
                } label: {
                    MineSettingsActionRow(
                        icon: "globe",
                        title: localization.text(.mineLanguage),
                        value: currentLanguageLabel
                    )
                }
                .buttonStyle(MineRowButtonStyle())
                MineSettingsDivider()
                Menu {
                    ForEach(AppThemeMode.allCases) { mode in
                        Button(themeModeLabel(mode)) {
                            appSettings.themeMode = mode
                        }
                    }
                } label: {
                    MineSettingsActionRow(
                        icon: "paintpalette",
                        title: localization.text(.mineTheme),
                        value: themeModeLabel(appSettings.themeMode)
                    )
                }
                .buttonStyle(MineRowButtonStyle())
                MineSettingsDivider()
                firstDayOfWeekRow
                MineSettingsDivider()
                emotionIconStyleRow
                MineSettingsDivider()
                NavigationLink {
                    CurrencySettingsView()
                        .environmentObject(localization)
                        .environmentObject(currencyManager)
                } label: {
                    MineSettingsActionRow(
                        icon: "coloncurrencysign.circle.fill",
                        title: localization.text(.mineCurrencyHub),
                        value: currencyManager.settingsSubtitle(
                            language: localization.language,
                            followSystemLabel: localization.text(.mineCurrencyFollowSystem)
                        )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emotionIconStyleRow: some View {
        HStack(spacing: 12) {
            MineSettingsIconWell(systemIcon: "face.smiling")
            Text(localization.text(.mineEmotionIconStyle))
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 8)
            Picker("", selection: $appSettings.emotionIconStyle) {
                Text(localization.text(.mineEmotionIconStyleRaster))
                    .tag(EmotionIconStyle.raster)
                Text(localization.text(.mineEmotionIconStyleSystem))
                    .tag(EmotionIconStyle.system)
            }
            .pickerStyle(.segmented)
            .frame(width: emotionIconStylePickerWidth)
        }
        .frame(minHeight: 58)
        .padding(.horizontal, 16)
    }

    private var emotionIconStylePickerWidth: CGFloat {
        localization.effectiveLanguage == .en ? 148 : 136
    }

    private var firstDayOfWeekRow: some View {
        HStack(spacing: 12) {
            MineSettingsIconWell(systemIcon: "calendar")
            Text(localization.text(.mineFirstDayOfWeek))
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 8)
            Picker("", selection: $appSettings.firstDayOfWeek) {
                Text(localization.text(.mineFirstDayOfWeekMonday))
                    .tag(FirstDayOfWeek.monday)
                Text(localization.text(.mineFirstDayOfWeekSunday))
                    .tag(FirstDayOfWeek.sunday)
            }
            .pickerStyle(.segmented)
            .frame(width: firstDayOfWeekPickerWidth)
        }
        .frame(minHeight: 58)
        .padding(.horizontal, 16)
    }

    /// Segmented control width: compact English labels; Chinese fits without crowding.
    private var firstDayOfWeekPickerWidth: CGFloat {
        localization.effectiveLanguage == .en ? 128 : 136
    }

    private var advancedFeaturesGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            MineSettingsGroupHeader(title: localization.text(.mineSectionAdvanced))
            MineSettingsCard {
                NavigationLink {
                    EmotionNotificationView()
                        .environmentObject(localization)
                        .environmentObject(appSettings)
                } label: {
                    MineSettingsActionRow(
                        icon: "bell.badge",
                        title: localization.text(.mineEmotionNotificationHub)
                    )
                }
                .buttonStyle(.plain)

                MineSettingsDivider()

                NavigationLink {
                    ReviewRuleSettingsView()
                        .environmentObject(localization)
                        .environmentObject(appSettings)
                } label: {
                    MineSettingsActionRow(
                        icon: "slider.horizontal.3",
                        title: localization.text(.mineRuleTitle)
                    )
                }
                .buttonStyle(.plain)

                MineSettingsDivider()

                NavigationLink {
                    DataManagementView()
                        .environmentObject(localization)
                        .environmentObject(appSettings)
                        .environmentObject(notificationStore)
                        .environmentObject(appSyncState)
                } label: {
                    MineSettingsActionRow(
                        icon: "tray.full",
                        title: localization.text(.mineDataManagementHub)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var aboutGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            MineSettingsGroupHeader(title: localization.text(.mineSectionAbout))
            MineSettingsCard {
                NavigationLink {
                    AboutAppView()
                        .environmentObject(localization)
                } label: {
                    MineSettingsActionRow(
                        icon: "info.circle.fill",
                        title: localization.text(.mineAboutApp)
                    )
                }
                .buttonStyle(.plain)

                MineSettingsDivider()

                NavigationLink {
                    HowToUseView()
                        .environmentObject(localization)
                } label: {
                    MineSettingsActionRow(
                        icon: "book.pages.fill",
                        title: localization.text(.mineAboutHowToUse)
                    )
                }
                .buttonStyle(.plain)

                MineSettingsDivider()

                Button {
                    Task { await restorePurchasesFromSettings() }
                } label: {
                    MineSettingsActionRow(
                        icon: "arrow.clockwise.circle.fill",
                        title: localization.text(.paywallRestore)
                    )
                }
                .buttonStyle(MineRowButtonStyle())
            }
        }
    }

    // MARK: - Restore

    private func restorePurchasesFromSettings() async {
        do {
            try await subscriptionManager.restorePurchases()
            if subscriptionManager.isPro {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                presentRestoreSuccessBanner()
            }
        } catch {
            showRestoreFailedAlert = true
        }
    }

    private func presentRestoreSuccessBanner() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            showRestoreSuccessBanner = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.28)) {
                    showRestoreSuccessBanner = false
                }
            }
        }
    }

    // MARK: - Labels

    private var currentLanguageLabel: String {
        switch localization.language {
        case .system:
            return localization.text(.mineLanguageSystem)
        case .zhHans:
            return localization.text(.mineLanguageChinese)
        case .zhHant:
            return localization.text(.mineLanguageTraditionalChinese)
        case .en:
            return localization.text(.mineLanguageEnglish)
        }
    }

    private func themeModeLabel(_ mode: AppThemeMode) -> String {
        switch mode {
        case .system:
            return localization.text(.mineThemeSystem)
        case .light:
            return localization.text(.mineThemeLight)
        case .dark:
            return localization.text(.mineThemeDark)
        }
    }
}

#Preview {
    MineView()
        .environmentObject(LocalizationManager())
        .environmentObject(AppSettings())
        .environmentObject(AppSyncState())
        .environmentObject(CurrencyManager())
        .environmentObject(NotificationCenterStore())
        .modelContainer(PersistenceController.inMemoryForPreviews().modelContainer)
}
