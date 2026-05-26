import Combine
import Foundation
import SwiftData

@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let emotionAlertLastShownAt = "settings.emotionAlertLastShownAt"
        static let emotionAlertLastEmotionRaw = "settings.emotionAlertLastEmotionRaw"
    }

    private let defaults: UserDefaults
    private var modelContext: ModelContext?
    private var isApplyingRemoteValues = false
    private static let allowedCooldownDays = [1, 3, 7]

    @Published var patternMinCount: Int {
        didSet { persistPreferencesIfNeeded() }
    }

    @Published var patternMinRatio: Double {
        didSet { persistPreferencesIfNeeded() }
    }

    @Published var emotionAlertEnabled: Bool {
        didSet { persistPreferencesIfNeeded() }
    }

    @Published var emotionAlertHighRiskOnly: Bool {
        didSet { persistPreferencesIfNeeded() }
    }

    @Published var emotionAlertCooldownDays: Int {
        didSet { persistPreferencesIfNeeded() }
    }

    @Published var themeMode: AppThemeMode {
        didSet { persistPreferencesIfNeeded() }
    }

    @Published var firstDayOfWeek: FirstDayOfWeek {
        didSet {
            guard firstDayOfWeek != oldValue else { return }
            defaults.set(firstDayOfWeek.rawValue, forKey: FirstDayOfWeek.storageKey)
            AppPeriodContext.shared.applyFirstDayOfWeekChange()
        }
    }

    @Published var emotionIconStyle: EmotionIconStyle {
        didSet {
            guard emotionIconStyle != oldValue else { return }
            EmotionIconStyle.persist(emotionIconStyle)
            guard !isApplyingRemoteValues else { return }
            persistPreferencesIfNeeded()
        }
    }

    @Published var iCloudSyncEnabled: Bool {
        didSet {
            guard !isApplyingRemoteValues else { return }
            CloudSyncStorage.isUserSyncEnabled = iCloudSyncEnabled
            persistPreferencesIfNeeded()
        }
    }

    @Published var displayName: String {
        didSet { persistProfileIfNeeded() }
    }

    @Published var avatarImageData: Data? {
        didSet { persistProfileIfNeeded() }
    }

    @Published var avatarPresetID: String? {
        didSet { persistProfileIfNeeded() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        FirstDayOfWeek.registerDefaults()
        let weekRaw = defaults.integer(forKey: FirstDayOfWeek.storageKey)
        self.firstDayOfWeek = weekRaw == 1 ? .sunday : .monday
        self.emotionIconStyle = EmotionIconStyle.stored
        self.patternMinCount = 2
        self.patternMinRatio = 0.25
        self.emotionAlertEnabled = true
        self.emotionAlertHighRiskOnly = true
        self.emotionAlertCooldownDays = 3
        self.themeMode = AppThemeMode.defaultMode
        self.iCloudSyncEnabled = CloudSyncStorage.isUserSyncEnabled
        self.displayName = AppBranding.nameZhHans
        self.avatarImageData = nil
        self.avatarPresetID = nil
    }

    func configure(modelContext: ModelContext) {
        guard self.modelContext == nil else { return }
        self.modelContext = modelContext
        PersistenceController.shared.configure(modelContext)
        reloadFromSwiftData()
    }

    func reloadFromSwiftData() {
        loadFromSwiftData()
    }

    func resetPatternRules() {
        patternMinCount = 2
        patternMinRatio = 0.25
    }

    var emotionAlertCooldownDescription: String {
        "\(emotionAlertCooldownDays)"
    }

    var emotionAlertCooldownOptions: [Int] {
        Self.allowedCooldownDays
    }

    func consumeEmotionAlertIfNeeded(emotionRaw: String, now: Date = Date()) -> Bool {
        guard shouldPresentEmotionAlert(emotionRaw: emotionRaw, now: now) else { return false }
        defaults.set(now.timeIntervalSince1970, forKey: Keys.emotionAlertLastShownAt)
        defaults.set(emotionRaw, forKey: Keys.emotionAlertLastEmotionRaw)
        return true
    }

    private func loadFromSwiftData() {
        guard let modelContext else { return }
        isApplyingRemoteValues = true
        defer { isApplyingRemoteValues = false }

        if let profile = try? ProfileRepository.fetchOrCreate(in: modelContext) {
            displayName = profile.displayName
            avatarImageData = profile.avatarImageData
            avatarPresetID = profile.avatarPresetID
        }

        if let preferences = try? PreferencesRepository.fetchOrCreate(in: modelContext) {
            patternMinCount = min(max(preferences.patternMinCount, 1), 10)
            patternMinRatio = min(max(preferences.patternMinRatio, 0.05), 0.9)
            emotionAlertEnabled = preferences.emotionAlertEnabled
            emotionAlertHighRiskOnly = preferences.emotionAlertHighRiskOnly
            emotionAlertCooldownDays = Self.normalizedCooldownDays(
                preferences.emotionAlertCooldownDays,
                allowedValues: Self.allowedCooldownDays
            )
            themeMode = preferences.themeMode
            emotionIconStyle = preferences.emotionIconStyle
            iCloudSyncEnabled = preferences.iCloudSyncEnabled
            CloudSyncStorage.isUserSyncEnabled = preferences.iCloudSyncEnabled
        }
    }

    /// Applies user iCloud sync preference to SwiftData and `UserDefaults` (restart required for store reconfiguration).
    func applyICloudSyncPreference(_ enabled: Bool) {
        CloudSyncStorage.isUserSyncEnabled = enabled
        guard iCloudSyncEnabled != enabled else { return }
        iCloudSyncEnabled = enabled
    }

    private func persistProfileIfNeeded() {
        guard !isApplyingRemoteValues, let modelContext else { return }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let clamped = String(trimmed.prefix(20))
        if clamped != displayName {
            displayName = clamped.isEmpty ? AppBranding.nameZhHans : clamped
            return
        }
        try? ProfileRepository.save(
            displayName: clamped.isEmpty ? AppBranding.nameZhHans : clamped,
            avatarImageData: avatarImageData,
            avatarPresetID: avatarPresetID,
            in: modelContext
        )
    }

    private func persistPreferencesIfNeeded() {
        guard !isApplyingRemoteValues, let modelContext else { return }

        let clampedCount = min(max(patternMinCount, 1), 10)
        if clampedCount != patternMinCount {
            patternMinCount = clampedCount
            return
        }

        let clampedRatio = min(max(patternMinRatio, 0.05), 0.9)
        if abs(clampedRatio - patternMinRatio) > 0.0001 {
            patternMinRatio = clampedRatio
            return
        }

        let normalizedCooldown = Self.normalizedCooldownDays(
            emotionAlertCooldownDays,
            allowedValues: Self.allowedCooldownDays
        )
        if normalizedCooldown != emotionAlertCooldownDays {
            emotionAlertCooldownDays = normalizedCooldown
            return
        }

        guard let preferences = try? PreferencesRepository.fetchOrCreate(in: modelContext) else { return }
        preferences.themeModeRaw = themeMode.rawValue
        preferences.iCloudSyncEnabled = iCloudSyncEnabled
        preferences.emotionAlertEnabled = emotionAlertEnabled
        preferences.emotionAlertHighRiskOnly = emotionAlertHighRiskOnly
        preferences.emotionAlertCooldownDays = normalizedCooldown
        preferences.patternMinCount = clampedCount
        preferences.patternMinRatio = clampedRatio
        preferences.emotionIconStyleRaw = emotionIconStyle.rawValue
        try? PreferencesRepository.save(preferences, in: modelContext)
        EmotionIconStyle.persist(emotionIconStyle)
    }

    private func shouldPresentEmotionAlert(emotionRaw: String, now: Date) -> Bool {
        guard emotionAlertEnabled else { return false }
        guard let lastShownAt = lastEmotionAlertShownAt else { return true }
        let calendar = Calendar.current
        if calendar.isDate(lastShownAt, inSameDayAs: now) {
            return false
        }
        let startOfLast = calendar.startOfDay(for: lastShownAt)
        let startOfNow = calendar.startOfDay(for: now)
        let dayGap = calendar.dateComponents([.day], from: startOfLast, to: startOfNow).day ?? 0
        guard dayGap < emotionAlertCooldownDays else { return true }
        return emotionRaw != lastEmotionAlertEmotionRaw
    }

    private var lastEmotionAlertShownAt: Date? {
        let timestamp = defaults.object(forKey: Keys.emotionAlertLastShownAt) as? TimeInterval
        guard let timestamp else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    private var lastEmotionAlertEmotionRaw: String? {
        defaults.string(forKey: Keys.emotionAlertLastEmotionRaw)
    }

    private static func normalizedCooldownDays(_ value: Int, allowedValues: [Int]) -> Int {
        if allowedValues.contains(value) {
            return value
        }
        let sorted = allowedValues.sorted { abs($0 - value) < abs($1 - value) }
        return sorted.first ?? 3
    }
}
