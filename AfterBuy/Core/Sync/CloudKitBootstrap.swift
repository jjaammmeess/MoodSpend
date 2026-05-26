import Foundation
import SwiftData

enum CloudKitBootstrap {
    private static let initialImportCompletedKey = "afterbuy.cloudkit.initialImportCompleted"

    @MainActor
    static func evaluateInitialImportGate(
        modelContext: ModelContext,
        appSyncState: AppSyncState
    ) {
        guard PersistenceConfiguration.cloudKitSyncEnabled else {
            appSyncState.updateInitialImportGate(shouldBlock: false)
            return
        }

        appSyncState.refreshICloudAvailability()
        guard appSyncState.isICloudAvailable else {
            appSyncState.updateInitialImportGate(shouldBlock: false)
            return
        }

        if UserDefaults.standard.bool(forKey: initialImportCompletedKey) {
            appSyncState.updateInitialImportGate(shouldBlock: false)
            return
        }

        let activeRecordCount = (try? modelContext.fetchCount(
            FetchDescriptor<TransactionRecord>(predicate: #Predicate { $0.deletedAt == nil })
        )) ?? 0

        if activeRecordCount > 0 {
            markInitialImportCompleted()
            appSyncState.updateInitialImportGate(shouldBlock: false)
            return
        }

        appSyncState.updateInitialImportGate(shouldBlock: true)
    }

    static func markInitialImportCompleted() {
        UserDefaults.standard.set(true, forKey: initialImportCompletedKey)
    }

    /// Unblocks the launch gate so the user can use the app without waiting for CloudKit import.
    @MainActor
    static func releaseInitialImportGate(appSyncState: AppSyncState) {
        markInitialImportCompleted()
        appSyncState.updateInitialImportGate(shouldBlock: false)
        appSyncState.clearLastError()
    }
}
