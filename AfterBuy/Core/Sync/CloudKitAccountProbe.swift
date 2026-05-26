import CloudKit
import Foundation

enum CloudKitAccountProbe {
    @MainActor
    static func refreshStatus(into appSyncState: AppSyncState) async {
        guard PersistenceConfiguration.cloudKitSyncEnabled else { return }

        appSyncState.refreshICloudAvailability()
        guard appSyncState.isICloudAvailable else {
            appSyncState.setAccountStatusHint(nil)
            return
        }

        let container = CKContainer(identifier: PersistenceConfiguration.cloudKitContainerIdentifier)
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                appSyncState.setAccountStatusHint(nil)
            case .noAccount:
                appSyncState.setAccountStatusHint(.noAccount)
            case .restricted:
                appSyncState.setAccountStatusHint(.restricted)
            case .temporarilyUnavailable:
                appSyncState.setAccountStatusHint(.temporarilyUnavailable)
            case .couldNotDetermine:
                appSyncState.setAccountStatusHint(.couldNotDetermine)
            @unknown default:
                appSyncState.setAccountStatusHint(.couldNotDetermine)
            }
        } catch {
            appSyncState.reportError(error.localizedDescription)
        }
    }
}
