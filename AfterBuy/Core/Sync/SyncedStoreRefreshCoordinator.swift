import Foundation
import SwiftData

/// Reconciles in-memory facades with SwiftData after a CloudKit import or iCloud account change.
@MainActor
enum SyncedStoreRefreshCoordinator {
    private static var debounceTask: Task<Void, Never>?

    static func refreshAfterRemoteChange(
        modelContext: ModelContext,
        appSettings: AppSettings,
        notificationStore: NotificationCenterStore,
        localization: LocalizationManager
    ) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            performRefresh(
                modelContext: modelContext,
                appSettings: appSettings,
                notificationStore: notificationStore,
                localization: localization
            )
        }
    }

    private static func performRefresh(
        modelContext: ModelContext,
        appSettings: AppSettings,
        notificationStore: NotificationCenterStore,
        localization: LocalizationManager
    ) {
        PersistenceController.shared.configure(modelContext)
        UserProfileConsolidation.consolidateIfNeeded(in: modelContext)
        AppPreferencesConsolidation.consolidateIfNeeded(in: modelContext)
        TransactionRecordPublicIdSync.ensureUniquePublicIds(modelContext: modelContext)
        CustomOptionPublicIdSync.ensureUniquePublicIds(modelContext: modelContext)
        EmotionBucketSnapshotSync.syncNilSnapshotsFromMatchingOptions(modelContext: modelContext)
        appSettings.reloadFromSwiftData()
        localization.reloadFromSwiftData()
        notificationStore.reloadFromSwiftData()
        notificationStore.pruneOrphanedRetrospectiveTasks(modelContext: modelContext)
    }
}
