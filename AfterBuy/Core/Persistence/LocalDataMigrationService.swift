import Foundation
import SwiftData

/// One-shot local migrations before CloudKit sync is enabled (P1 M0).
enum LocalDataMigrationService {
    static let currentVersion = 2
    private static let versionKey = "afterbuy.localDataMigration.version"

    @MainActor
    static func runIfNeeded(using container: ModelContainer) async {
        let completed = UserDefaults.standard.integer(forKey: versionKey)
        guard completed < currentVersion else { return }

        let context = PersistenceController.shared.newBackgroundContext()
        migrateAttachments(in: context)
        migrateUserProfile(in: context)
        migrateAppPreferences(in: context)
        migrateNotifications(in: context)
        UserProfileConsolidation.consolidateIfNeeded(in: context)
        AppPreferencesConsolidation.consolidateIfNeeded(in: context)

        do {
            try context.save()
            UserDefaults.standard.set(currentVersion, forKey: versionKey)
        } catch {
            #if DEBUG
            print("LocalDataMigrationService save failed: \(error)")
            #endif
        }
    }

    @MainActor
    private static func migrateAttachments(in context: ModelContext) {
        guard let records = try? context.fetch(FetchDescriptor<TransactionRecord>()) else { return }
        for record in records {
            if let attachments = record.attachments, !attachments.isEmpty { continue }
            let legacy = record.legacyImageAttachmentDatas
            guard !legacy.isEmpty else { continue }
            record.applyImageAttachments(legacy)
        }
    }

    @MainActor
    private static func migrateUserProfile(in context: ModelContext) {
        if fetchProfile(in: context) != nil { return }

        let defaults = UserDefaults.standard
        let displayName = defaults.string(forKey: "settings.displayName")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let avatarData = defaults.data(forKey: "settings.avatarImageData")
        let presetID = defaults.string(forKey: "settings.avatarPresetID")

        let profile = UserProfile(
            displayName: displayName.isEmpty ? AppBranding.nameZhHans : String(displayName.prefix(20)),
            avatarImageData: avatarData,
            avatarPresetID: presetID
        )
        context.insert(profile)
    }

    @MainActor
    private static func migrateAppPreferences(in context: ModelContext) {
        if fetchPreferences(in: context) != nil { return }

        let defaults = UserDefaults.standard
        let legacyThemeRaw = defaults.string(forKey: ThemeModeStorage.legacyUserDefaultsKey)
        let themeRaw = AppThemeMode.resolved(from: legacyThemeRaw).rawValue
        let languageRaw = defaults.string(forKey: "AfterBuy.appLanguage") ?? AppLanguage.defaultPreference.rawValue
        let alertEnabled = defaults.object(forKey: "settings.emotionAlertEnabled") as? Bool ?? true
        let alertHighRiskOnly = defaults.object(forKey: "settings.emotionAlertHighRiskOnly") as? Bool ?? true
        let cooldown = defaults.object(forKey: "settings.emotionAlertCooldownDays") as? Int ?? 3
        let patternCount = defaults.object(forKey: "settings.patternMinCount") as? Int ?? 2
        let patternRatio = defaults.object(forKey: "settings.patternMinRatio") as? Double ?? 0.25
        let iCloudSyncEnabled = defaults.object(forKey: CloudSyncStorage.userEnabledKey) as? Bool
            ?? CloudSyncStorage.defaultUserEnabled

        let preferences = AppPreferences(
            themeModeRaw: themeRaw,
            languageRaw: languageRaw,
            emotionAlertEnabled: alertEnabled,
            emotionAlertHighRiskOnly: alertHighRiskOnly,
            emotionAlertCooldownDays: min(max(cooldown, 1), 7),
            patternMinCount: min(max(patternCount, 1), 10),
            patternMinRatio: min(max(patternRatio, 0.05), 0.9),
            iCloudSyncEnabled: iCloudSyncEnabled
        )
        CloudSyncStorage.isUserSyncEnabled = iCloudSyncEnabled
        context.insert(preferences)
    }

    @MainActor
    private static func migrateNotifications(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<SyncedAppNotification>())) ?? []
        guard existing.isEmpty else { return }

        guard let data = UserDefaults.standard.data(forKey: "notificationCenter.items"),
              let items = try? JSONDecoder().decode([AppNotificationItem].self, from: data)
        else { return }

        for item in items {
            context.insert(SyncedAppNotification(from: item))
        }
    }

    @MainActor
    private static func fetchProfile(in context: ModelContext) -> UserProfile? {
        let id = PersistenceConfiguration.profileSingletonId
        var descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.singletonId == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    @MainActor
    private static func fetchPreferences(in context: ModelContext) -> AppPreferences? {
        let id = PersistenceConfiguration.preferencesSingletonId
        var descriptor = FetchDescriptor<AppPreferences>(
            predicate: #Predicate { $0.singletonId == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
