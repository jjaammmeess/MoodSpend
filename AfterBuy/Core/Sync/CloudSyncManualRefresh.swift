import CoreData
import Foundation
import SwiftData

/// User-initiated nudge for CloudKit sync (account probe + local store refresh + export queue).
enum CloudSyncManualRefresh {
    @MainActor
    static func trigger(appSyncState: AppSyncState) async {
        guard PersistenceConfiguration.cloudKitSyncEnabled else { return }
        guard CloudSyncStorage.isSyncActive else { return }

        appSyncState.setSyncing(true)
        await CloudKitAccountProbe.refreshStatus(into: appSyncState)

        if let container = PersistenceController.shared.persistentCloudKitContainer {
            await container.viewContext.perform {
                container.viewContext.refreshAllObjects()
            }
        }

        nudgeCloudKitExport()
        appSyncState.bumpDataRefresh()

        // `CloudSyncNotificationObserver` usually clears `isSyncing` on import/export end.
        try? await Task.sleep(for: .seconds(2))
        if appSyncState.isSyncing {
            appSyncState.setSyncing(false)
        }
    }

    /// Touches a CloudKit-backed row so `NSPersistentCloudKitContainer` schedules an export.
    @MainActor
    private static func nudgeCloudKitExport() {
        let context = ModelContext(PersistenceController.shared.modelContainer)
        PersistenceController.shared.configure(context)
        do {
            if let preferences = try context.fetch(FetchDescriptor<AppPreferences>()).first {
                preferences.updatedAt = Date()
                try context.save()
            }
        } catch {
            #if DEBUG
            print("CloudSyncManualRefresh export nudge failed: \(error)")
            #endif
        }
    }
}
