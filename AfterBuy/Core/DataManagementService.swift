import Foundation
import SwiftData

struct BackupPayload: Codable {
    /// `1` legacy · `2` publicId · `3` multi-image · `4` profile & custom tags · `5` notification center · `6` customOption publicId · `7` iCloud sync preference.
    let version: Int
    let exportedAt: Date
    let records: [TransactionSnapshot]
    /// Present from backup format v4 onward.
    let customOptions: [CustomOptionSnapshot]?
    let profile: ProfileSnapshot?
    let preferences: AppPreferencesSnapshot?
    /// Present from backup format v5 onward.
    let notifications: [AppNotificationItem]?
}

struct TransactionSnapshot: Codable {
    let amount: Double
    let typeRaw: String
    let categoryKey: String
    let categoryName: String
    let emotionRaw: String
    let emotionName: String
    let emotionColorHex: String
    let emotionBucketRaw: String?
    let categoryIconSymbolRaw: String?
    let emotionIconSymbolRaw: String?
    let note: String
    let imageData: Data?
    /// Present from backup format v3 onward.
    let imageAttachmentDatas: [Data]?
    let createdAt: Date
    /// Present from backup format v2 onward; `nil` when restoring v1 exports.
    let publicId: UUID?
    /// Present from backup format v4 onward.
    let retrospectiveWorthRaw: String?
}

struct CustomOptionSnapshot: Codable {
    let kindRaw: String
    let name: String
    let colorHex: String?
    let emotionBucketRaw: String?
    let iconSymbolRaw: String
    let createdAt: Date
    /// Present from backup format v6 onward.
    let publicId: UUID?
}

struct ProfileSnapshot: Codable {
    let displayName: String
    let avatarImageData: Data?
    let avatarPresetID: String?
}

struct AppPreferencesSnapshot: Codable {
    let themeModeRaw: String
    let languageRaw: String
    let emotionAlertEnabled: Bool
    let emotionAlertHighRiskOnly: Bool
    let emotionAlertCooldownDays: Int
    let patternMinCount: Int
    let patternMinRatio: Double
    /// Present from backup format v7 onward.
    let iCloudSyncEnabled: Bool?
}

enum RestoreMode {
    case merge
    case replace
}

struct BackupValidationSummary {
    let recordCount: Int
    let customOptionCount: Int
    let notificationCount: Int
    let includesProfile: Bool
    let exportedAt: Date
    let earliestRecordAt: Date?
    let latestRecordAt: Date?
}

struct BackupRestoreResult {
    let recordsInserted: Int
    let customOptionsInserted: Int
    let notificationsInserted: Int
    let profileRestored: Bool
    let preferencesRestored: Bool
    let restoredLanguage: AppLanguage?
}

enum DataManagementService {
    static let currentBackupVersion = 7

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    @MainActor
    static func buildBackupJSON(
        from records: [TransactionRecord],
        customOptions: [CustomOption],
        appSettings: AppSettings,
        language: AppLanguage,
        notifications: [AppNotificationItem]
    ) throws -> String {
        let payload = BackupPayload(
            version: currentBackupVersion,
            exportedAt: Date(),
            records: records.map(snapshot(from:)),
            customOptions: customOptions.map(snapshot(from:)),
            profile: profileSnapshot(from: appSettings),
            preferences: preferencesSnapshot(from: appSettings, language: language),
            notifications: notifications
        )
        let data = try encoder.encode(payload)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    @MainActor
    static func buildCSV(from records: [TransactionRecord]) -> String {
        var rows: [String] = []
        rows.append("createdAt,amount,category,emotion,note")
        let sorted = records.sorted { $0.createdAt > $1.createdAt }
        for record in sorted {
            let date = ISO8601DateFormatter().string(from: record.createdAt)
            let amount = String(format: "%.2f", record.amount)
            rows.append([
                csvEscape(date),
                csvEscape(amount),
                csvEscape(record.safeCategoryName),
                csvEscape(record.safeEmotionName),
                csvEscape(record.note)
            ].joined(separator: ","))
        }
        // UTF-8 BOM + CRLF so Excel (especially zh-CN Windows) opens Chinese text correctly.
        return "\u{FEFF}" + rows.joined(separator: "\r\n")
    }

    static func validateBackup(from jsonData: Data) throws -> BackupValidationSummary {
        let payload = try decoder.decode(BackupPayload.self, from: jsonData)
        let sortedDates = payload.records.map(\.createdAt).sorted()
        return BackupValidationSummary(
            recordCount: payload.records.count,
            customOptionCount: payload.customOptions?.count ?? 0,
            notificationCount: payload.notifications?.count ?? 0,
            includesProfile: payload.profile != nil,
            exportedAt: payload.exportedAt,
            earliestRecordAt: sortedDates.first,
            latestRecordAt: sortedDates.last
        )
    }

    @MainActor
    static func restoreBackup(
        from jsonData: Data,
        mode: RestoreMode,
        modelContext: ModelContext,
        existingRecords: [TransactionRecord],
        existingCustomOptions: [CustomOption],
        appSettings: AppSettings,
        notificationStore: NotificationCenterStore
    ) throws -> BackupRestoreResult {
        let payload = try decoder.decode(BackupPayload.self, from: jsonData)
        if mode == .replace {
            clearAllRecords(
                modelContext: modelContext,
                records: existingRecords,
                notificationStore: notificationStore
            )
            clearAllCustomOptions(modelContext: modelContext, options: existingCustomOptions)
        }

        let recordsInserted = insertRecords(
            from: payload.records,
            mode: mode,
            modelContext: modelContext,
            existingRecords: mode == .merge ? existingRecords : []
        )
        let customOptionsInserted = insertCustomOptions(
            from: payload.customOptions ?? [],
            mode: mode,
            modelContext: modelContext,
            existingOptions: mode == .merge ? existingCustomOptions : []
        )

        let profileRestored = applyProfile(payload.profile, to: appSettings)
        let (preferencesRestored, restoredLanguage) = applyPreferences(
            payload.preferences,
            to: appSettings,
            modelContext: modelContext
        )
        let notificationsInserted = restoreNotifications(
            payload.notifications,
            mode: mode,
            modelContext: modelContext,
            notificationStore: notificationStore
        )

        try modelContext.save()

        return BackupRestoreResult(
            recordsInserted: recordsInserted,
            customOptionsInserted: customOptionsInserted,
            notificationsInserted: notificationsInserted,
            profileRestored: profileRestored,
            preferencesRestored: preferencesRestored,
            restoredLanguage: restoredLanguage
        )
    }

    @MainActor
    static func clearAllRecords(
        modelContext: ModelContext,
        records: [TransactionRecord],
        notificationStore: NotificationCenterStore
    ) {
        notificationStore.removeAllRetrospectiveTasks()
        for record in records {
            modelContext.delete(record)
        }
    }

    @MainActor
    static func clearAllCustomOptions(
        modelContext: ModelContext,
        options: [CustomOption]
    ) {
        for option in options {
            modelContext.delete(option)
        }
    }

    // MARK: - Export snapshots

    @MainActor
    private static func snapshot(from record: TransactionRecord) -> TransactionSnapshot {
        let attachments = record.resolvedImageAttachments
        return TransactionSnapshot(
            amount: record.amount,
            typeRaw: record.typeRaw,
            categoryKey: record.categoryKey,
            categoryName: record.categoryName,
            emotionRaw: record.emotionRaw,
            emotionName: record.emotionName,
            emotionColorHex: record.emotionColorHex,
            emotionBucketRaw: record.emotionBucketRaw,
            categoryIconSymbolRaw: record.categoryIconSymbolRaw,
            emotionIconSymbolRaw: record.emotionIconSymbolRaw,
            note: record.note,
            imageData: attachments.first,
            imageAttachmentDatas: attachments.isEmpty ? nil : attachments,
            createdAt: record.createdAt,
            publicId: record.publicId,
            retrospectiveWorthRaw: record.retrospectiveWorthRaw
        )
    }

    @MainActor
    private static func snapshot(from option: CustomOption) -> CustomOptionSnapshot {
        CustomOptionSnapshot(
            kindRaw: option.kindRaw,
            name: option.name,
            colorHex: option.colorHex,
            emotionBucketRaw: option.emotionBucketRaw,
            iconSymbolRaw: option.iconSymbolRaw,
            createdAt: option.createdAt,
            publicId: option.publicId
        )
    }

    @MainActor
    private static func profileSnapshot(from settings: AppSettings) -> ProfileSnapshot {
        ProfileSnapshot(
            displayName: settings.displayName,
            avatarImageData: settings.avatarImageData,
            avatarPresetID: settings.avatarPresetID
        )
    }

    private static func preferencesSnapshot(
        from settings: AppSettings,
        language: AppLanguage
    ) -> AppPreferencesSnapshot {
        AppPreferencesSnapshot(
            themeModeRaw: settings.themeMode.rawValue,
            languageRaw: language.rawValue,
            emotionAlertEnabled: settings.emotionAlertEnabled,
            emotionAlertHighRiskOnly: settings.emotionAlertHighRiskOnly,
            emotionAlertCooldownDays: settings.emotionAlertCooldownDays,
            patternMinCount: settings.patternMinCount,
            patternMinRatio: settings.patternMinRatio,
            iCloudSyncEnabled: settings.iCloudSyncEnabled
        )
    }

    // MARK: - Restore helpers

    @MainActor
    private static func insertRecords(
        from snapshots: [TransactionSnapshot],
        mode: RestoreMode,
        modelContext: ModelContext,
        existingRecords: [TransactionRecord]
    ) -> Int {
        let existingSignatures = mode == .merge
            ? Set(existingRecords.map(recordSignature))
            : Set<String>()
        var existingPublicIds = mode == .merge
            ? Set(existingRecords.map(\.publicId))
            : Set<UUID>()
        var inserted = 0
        var mergedSignatures = existingSignatures

        for item in snapshots {
            if mode == .merge, let publicId = item.publicId, existingPublicIds.contains(publicId) {
                continue
            }
            let signature = snapshotSignature(item)
            if mode == .merge, mergedSignatures.contains(signature) {
                continue
            }
            let restoredAttachments: [Data] = {
                if let datas = item.imageAttachmentDatas, !datas.isEmpty { return datas }
                if let imageData = item.imageData, !imageData.isEmpty { return [imageData] }
                return []
            }()
            let record = TransactionRecord(
                amount: item.amount,
                type: RecordType(rawValue: item.typeRaw) ?? .expense,
                categoryKey: item.categoryKey,
                categoryName: item.categoryName,
                emotionRaw: item.emotionRaw,
                emotionName: item.emotionName,
                emotionColorHex: item.emotionColorHex,
                emotionBucketRaw: item.emotionBucketRaw,
                categoryIconSymbolRaw: item.categoryIconSymbolRaw,
                emotionIconSymbolRaw: item.emotionIconSymbolRaw,
                note: item.note,
                imageAttachmentDatas: restoredAttachments,
                createdAt: item.createdAt,
                publicId: item.publicId ?? UUID(),
                retrospectiveWorthRaw: item.retrospectiveWorthRaw
            )
            modelContext.insert(record)
            mergedSignatures.insert(signature)
            existingPublicIds.insert(record.publicId)
            inserted += 1
        }
        return inserted
    }

    @MainActor
    private static func insertCustomOptions(
        from snapshots: [CustomOptionSnapshot],
        mode: RestoreMode,
        modelContext: ModelContext,
        existingOptions: [CustomOption]
    ) -> Int {
        let existingSignatures = mode == .merge
            ? Set(existingOptions.map(customOptionSignature))
            : Set<String>()
        var existingPublicIds = mode == .merge
            ? Set(existingOptions.map(\.publicId))
            : Set<UUID>()
        var inserted = 0
        var mergedSignatures = existingSignatures

        for item in snapshots {
            if mode == .merge, let publicId = item.publicId, existingPublicIds.contains(publicId) {
                continue
            }
            let signature = customOptionSnapshotSignature(item)
            if mode == .merge, mergedSignatures.contains(signature) {
                continue
            }
            let kind = CustomOptionKind(rawValue: item.kindRaw) ?? .category
            let option = CustomOption(
                kind: kind,
                name: item.name,
                colorHex: item.colorHex,
                emotionBucketRaw: item.emotionBucketRaw,
                iconSymbolRaw: item.iconSymbolRaw,
                createdAt: item.createdAt,
                publicId: item.publicId ?? UUID()
            )
            modelContext.insert(option)
            mergedSignatures.insert(signature)
            existingPublicIds.insert(option.publicId)
            inserted += 1
        }
        return inserted
    }

    @discardableResult
    private static func applyProfile(_ profile: ProfileSnapshot?, to settings: AppSettings) -> Bool {
        guard let profile else { return false }
        settings.displayName = profile.displayName
        settings.avatarImageData = profile.avatarImageData
        settings.avatarPresetID = profile.avatarPresetID
        return true
    }

    @MainActor
    private static func restoreNotifications(
        _ notifications: [AppNotificationItem]?,
        mode: RestoreMode,
        modelContext: ModelContext,
        notificationStore: NotificationCenterStore
    ) -> Int {
        guard let notifications else { return 0 }
        let remapped = remappedNotifications(notifications, modelContext: modelContext)
        return notificationStore.applyBackupRestore(remapped, mode: mode)
    }

    @MainActor
    private static func remappedNotifications(
        _ notifications: [AppNotificationItem],
        modelContext: ModelContext
    ) -> [AppNotificationItem] {
        guard let records = try? modelContext.fetch(FetchDescriptor<TransactionRecord>()) else {
            return notifications
        }
        let recordsByPublicId = Dictionary(uniqueKeysWithValues: records.map { ($0.publicId, $0) })

        return notifications.map { item in
            guard let publicId = item.linkedRecordId else { return item }
            guard let record = recordsByPublicId[publicId] else {
                return AppNotificationItem(
                    id: item.id,
                    type: item.type,
                    priority: item.priority,
                    title: item.title,
                    message: item.message,
                    createdAt: item.createdAt,
                    isRead: item.isRead,
                    isPinned: item.isPinned,
                    action: item.action,
                    warningEmotionRaw: item.warningEmotionRaw,
                    warningCount: item.warningCount,
                    warningAmount: item.warningAmount,
                    dedupKey: item.dedupKey,
                    linkedRecordId: item.linkedRecordId,
                    linkedRecordPersistentToken: nil
                )
            }
            return AppNotificationItem(
                id: item.id,
                type: item.type,
                priority: item.priority,
                title: item.title,
                message: item.message,
                createdAt: item.createdAt,
                isRead: item.isRead,
                isPinned: item.isPinned,
                action: item.action,
                warningEmotionRaw: item.warningEmotionRaw,
                warningCount: item.warningCount,
                warningAmount: item.warningAmount,
                dedupKey: item.dedupKey,
                linkedRecordId: publicId,
                linkedRecordPersistentToken: RetrospectiveRecordLink.persistentToken(for: record)
            )
        }
    }

    @MainActor
    private static func applyPreferences(
        _ preferences: AppPreferencesSnapshot?,
        to settings: AppSettings,
        modelContext: ModelContext
    ) -> (applied: Bool, language: AppLanguage?) {
        guard let preferences else { return (false, nil) }
        settings.themeMode = AppThemeMode.resolved(from: preferences.themeModeRaw)
        if let iCloudSyncEnabled = preferences.iCloudSyncEnabled {
            settings.applyICloudSyncPreference(iCloudSyncEnabled)
        }
        let restoredLanguage = AppLanguage(rawValue: preferences.languageRaw)
        settings.emotionAlertEnabled = preferences.emotionAlertEnabled
        settings.emotionAlertHighRiskOnly = preferences.emotionAlertHighRiskOnly
        settings.emotionAlertCooldownDays = preferences.emotionAlertCooldownDays
        settings.patternMinCount = preferences.patternMinCount
        settings.patternMinRatio = preferences.patternMinRatio
        if let restoredLanguage,
           let prefs = try? PreferencesRepository.fetchOrCreate(in: modelContext) {
            prefs.languageRaw = restoredLanguage.rawValue
            try? PreferencesRepository.save(prefs, in: modelContext)
        }
        return (true, restoredLanguage)
    }

    private static func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static func recordSignature(_ record: TransactionRecord) -> String {
        signature(
            amount: record.amount,
            typeRaw: record.typeRaw,
            categoryKey: record.categoryKey,
            emotionRaw: record.emotionRaw,
            note: record.note,
            createdAt: record.createdAt
        )
    }

    private static func snapshotSignature(_ snapshot: TransactionSnapshot) -> String {
        signature(
            amount: snapshot.amount,
            typeRaw: snapshot.typeRaw,
            categoryKey: snapshot.categoryKey,
            emotionRaw: snapshot.emotionRaw,
            note: snapshot.note,
            createdAt: snapshot.createdAt
        )
    }

    private static func signature(
        amount: Double,
        typeRaw: String,
        categoryKey: String,
        emotionRaw: String,
        note: String,
        createdAt: Date
    ) -> String {
        let normalizedAmount = String(format: "%.2f", amount)
        let timestamp = String(Int(createdAt.timeIntervalSince1970))
        return [
            normalizedAmount,
            typeRaw,
            categoryKey,
            emotionRaw,
            note,
            timestamp
        ].joined(separator: "|")
    }

    private static func customOptionSignature(_ option: CustomOption) -> String {
        customOptionSnapshotSignature(
            CustomOptionSnapshot(
                kindRaw: option.kindRaw,
                name: option.name,
                colorHex: option.colorHex,
                emotionBucketRaw: option.emotionBucketRaw,
                iconSymbolRaw: option.iconSymbolRaw,
                createdAt: option.createdAt,
                publicId: option.publicId
            )
        )
    }

    private static func customOptionSnapshotSignature(_ snapshot: CustomOptionSnapshot) -> String {
        let normalizedName = snapshot.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(snapshot.kindRaw)|\(normalizedName)"
    }
}
