import Foundation
import SwiftData

/// Copies data from the pre-CloudKit `default.store` into `AfterBuyCloud.store` so
/// Core Data + CloudKit can create zones on a clean sqlite file (fixes CK zone setup failures).
enum CloudKitLegacyStoreMigrator {
    private static let migratedKey = "afterbuy.cloudkit.legacyStoreMigrated"

    static func migrateIfNeeded() {
        guard PersistenceConfiguration.cloudKitSyncEnabled else { return }
        guard !UserDefaults.standard.bool(forKey: migratedKey) else { return }

        let legacyURL = PersistenceConfiguration.legacyStoreURL
        let cloudURL = PersistenceConfiguration.cloudKitStoreURL
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: legacyURL.path) else {
            UserDefaults.standard.set(true, forKey: migratedKey)
            return
        }

        if fileManager.fileExists(atPath: cloudURL.path) {
            if isCloudStoreEmpty(at: cloudURL), fileManager.fileExists(atPath: legacyURL.path) {
                removeStoreFiles(at: cloudURL)
            } else {
                UserDefaults.standard.set(true, forKey: migratedKey)
                return
            }
        }

        // Run on the caller thread (main at launch). Do not use a background queue + semaphore.wait()
        // on main — SwiftData can route work back to the main actor and deadlock with 0% CPU.
        do {
            try performMigration(legacyURL: legacyURL, cloudURL: cloudURL)
            UserDefaults.standard.set(true, forKey: migratedKey)
            archiveLegacyStoreFiles()
        } catch {
            #if DEBUG
            print("CloudKitLegacyStoreMigrator failed: \(error)")
            #endif
        }
    }

    private static func performMigration(legacyURL: URL, cloudURL: URL) throws {
        let schema = Schema([
            TransactionRecord.self,
            CustomOption.self,
            RecordAttachment.self,
            UserProfile.self,
            AppPreferences.self,
            SyncedAppNotification.self
        ])

        let legacyConfig = ModelConfiguration(schema: schema, url: legacyURL)
        let legacyContainer = try ModelContainer(for: schema, configurations: [legacyConfig])
        let legacyContext = ModelContext(legacyContainer)

        // Local-only target; CloudKit mirroring attaches when the main container opens.
        let cloudConfig = ModelConfiguration(schema: schema, url: cloudURL)
        let cloudContainer = try ModelContainer(for: schema, configurations: [cloudConfig])
        let cloudContext = ModelContext(cloudContainer)

        try copyRecords(from: legacyContext, to: cloudContext)
        try copyCustomOptions(from: legacyContext, to: cloudContext)
        try copyAttachments(from: legacyContext, to: cloudContext)
        try copyProfiles(from: legacyContext, to: cloudContext)
        try copyPreferences(from: legacyContext, to: cloudContext)
        try copyNotifications(from: legacyContext, to: cloudContext)
        try cloudContext.save()
    }

    private static func copyRecords(from legacy: ModelContext, to cloud: ModelContext) throws {
        let legacyAttachments = try legacy.fetch(FetchDescriptor<RecordAttachment>())
        let attachmentsByRecord = Dictionary(grouping: legacyAttachments, by: \.recordPublicId)

        let records = try legacy.fetch(FetchDescriptor<TransactionRecord>())
        for source in records {
            let copy = TransactionRecord(
                amount: source.amount,
                type: source.type,
                categoryKey: source.categoryKey,
                categoryName: source.categoryName,
                emotionRaw: source.emotionRaw,
                emotionName: source.emotionName,
                emotionColorHex: source.emotionColorHex,
                emotionBucketRaw: source.emotionBucketRaw,
                categoryIconSymbolRaw: source.categoryIconSymbolRaw,
                emotionIconSymbolRaw: source.emotionIconSymbolRaw,
                note: source.note,
                createdAt: source.createdAt,
                publicId: source.publicId,
                retrospectiveWorthRaw: source.retrospectiveWorthRaw
            )
            copy.updatedAt = source.updatedAt
            copy.deletedAt = source.deletedAt
            copy.lastModifiedDeviceId = source.lastModifiedDeviceId
            cloud.insert(copy)

            if attachmentsByRecord[source.publicId]?.isEmpty ?? true {
                var legacyBlobs = source.imageAttachmentDatas
                if legacyBlobs.isEmpty, let imageData = source.imageData, !imageData.isEmpty {
                    legacyBlobs = [imageData]
                }
                if !legacyBlobs.isEmpty {
                    copy.applyImageAttachments(legacyBlobs)
                }
            }
        }
    }

    private static func copyCustomOptions(from legacy: ModelContext, to cloud: ModelContext) throws {
        let options = try legacy.fetch(FetchDescriptor<CustomOption>())
        for source in options {
            let copy = CustomOption(
                kind: source.kind,
                name: source.name,
                colorHex: source.colorHex,
                emotionBucketRaw: source.emotionBucketRaw,
                iconSymbolRaw: source.iconSymbolRaw,
                createdAt: source.createdAt,
                publicId: source.publicId
            )
            copy.updatedAt = source.updatedAt
            copy.deletedAt = source.deletedAt
            cloud.insert(copy)
        }
    }

    private static func copyAttachments(from legacy: ModelContext, to cloud: ModelContext) throws {
        let attachments = try legacy.fetch(FetchDescriptor<RecordAttachment>())
        let recordsByPublicId = Dictionary(
            uniqueKeysWithValues: (try cloud.fetch(FetchDescriptor<TransactionRecord>())).map { ($0.publicId, $0) }
        )
        for source in attachments {
            guard let record = recordsByPublicId[source.recordPublicId] else { continue }
            let copy = RecordAttachment(
                attachmentId: source.attachmentId,
                recordPublicId: source.recordPublicId,
                sortOrder: source.sortOrder,
                imageData: source.imageData,
                createdAt: source.createdAt,
                record: record
            )
            cloud.insert(copy)
        }
    }

    private static func copyProfiles(from legacy: ModelContext, to cloud: ModelContext) throws {
        guard let source = try legacy.fetch(FetchDescriptor<UserProfile>()).first else { return }
        cloud.insert(
            UserProfile(
                singletonId: source.singletonId,
                displayName: source.displayName,
                avatarImageData: source.avatarImageData,
                avatarPresetID: source.avatarPresetID,
                updatedAt: source.updatedAt
            )
        )
    }

    private static func copyPreferences(from legacy: ModelContext, to cloud: ModelContext) throws {
        guard let source = try legacy.fetch(FetchDescriptor<AppPreferences>()).first else { return }
        cloud.insert(
            AppPreferences(
                singletonId: source.singletonId,
                themeModeRaw: source.themeModeRaw,
                languageRaw: source.languageRaw,
                emotionAlertEnabled: source.emotionAlertEnabled,
                emotionAlertHighRiskOnly: source.emotionAlertHighRiskOnly,
                emotionAlertCooldownDays: source.emotionAlertCooldownDays,
                patternMinCount: source.patternMinCount,
                patternMinRatio: source.patternMinRatio,
                updatedAt: source.updatedAt
            )
        )
    }

    private static func copyNotifications(from legacy: ModelContext, to cloud: ModelContext) throws {
        let items = try legacy.fetch(FetchDescriptor<SyncedAppNotification>())
        for source in items {
            cloud.insert(
                SyncedAppNotification(
                    id: source.id,
                    typeRaw: source.typeRaw,
                    priorityRaw: source.priorityRaw,
                    title: source.title,
                    message: source.message,
                    createdAt: source.createdAt,
                    isRead: source.isRead,
                    isPinned: source.isPinned,
                    actionRaw: source.actionRaw,
                    warningEmotionRaw: source.warningEmotionRaw,
                    warningCount: source.warningCount,
                    warningAmount: source.warningAmount,
                    dedupKey: source.dedupKey,
                    linkedRecordId: source.linkedRecordId,
                    linkedRecordPersistentToken: source.linkedRecordPersistentToken
                )
            )
        }
    }

    private static func isCloudStoreEmpty(at url: URL) -> Bool {
        let schema = Schema([
            TransactionRecord.self,
            CustomOption.self,
            RecordAttachment.self,
            UserProfile.self,
            AppPreferences.self,
            SyncedAppNotification.self
        ])
        guard let container = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: url)]
        ) else {
            return true
        }
        let context = ModelContext(container)
        let recordCount = (try? context.fetchCount(FetchDescriptor<TransactionRecord>())) ?? 0
        return recordCount == 0
    }

    private static func removeStoreFiles(at url: URL) {
        try? FileManager.default.removeItem(at: url)
        for suffix in ["-shm", "-wal"] {
            try? FileManager.default.removeItem(atPath: url.path + suffix)
        }
    }

    private static func archiveLegacyStoreFiles() {
        let legacyURL = PersistenceConfiguration.legacyStoreURL
        let archiveURL = legacyURL.deletingLastPathComponent()
            .appendingPathComponent("default.store.pre-cloudkit.backup")
        try? FileManager.default.removeItem(at: archiveURL)
        try? FileManager.default.moveItem(at: legacyURL, to: archiveURL)
        for suffix in ["-shm", "-wal"] {
            let sidecar = URL(fileURLWithPath: legacyURL.path + suffix)
            guard FileManager.default.fileExists(atPath: sidecar.path) else { continue }
            let dest = URL(fileURLWithPath: archiveURL.path + suffix)
            try? FileManager.default.moveItem(at: sidecar, to: dest)
        }
    }
}
