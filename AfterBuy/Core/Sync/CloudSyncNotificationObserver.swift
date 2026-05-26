import CoreData
import Foundation

@MainActor
final class CloudSyncNotificationObserver {
    static let shared = CloudSyncNotificationObserver()

    private var observerToken: NSObjectProtocol?
    private var importInFlight = false
    private var exportInFlight = false

    private init() {}

    func start(
        appSyncState: AppSyncState,
        onRemoteStoreChange: @escaping @MainActor () -> Void
    ) {
        guard observerToken == nil else { return }
        guard PersistenceConfiguration.cloudKitSyncEnabled else { return }

        observerToken = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self, weak appSyncState] notification in
            guard let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event else {
                return
            }
            Task { @MainActor [weak self, weak appSyncState] in
                guard let self, let appSyncState else { return }
                self.handle(
                    event: event,
                    appSyncState: appSyncState,
                    onRemoteStoreChange: onRemoteStoreChange
                )
            }
        }
    }

    func stop() {
        if let observerToken {
            NotificationCenter.default.removeObserver(observerToken)
        }
        observerToken = nil
        importInFlight = false
        exportInFlight = false
    }

    private func handle(
        event: NSPersistentCloudKitContainer.Event,
        appSyncState: AppSyncState,
        onRemoteStoreChange: @MainActor () -> Void
    ) {
        if event.endDate == nil {
            switch event.type {
            case .import:
                importInFlight = true
                appSyncState.setSyncing(true)
            case .export:
                exportInFlight = true
            default:
                break
            }
            return
        }

        switch event.type {
        case .setup:
            if !event.succeeded {
                appSyncState.reportError(CloudKitErrorMessage.userFacing(event.error))
                appSyncState.updateInitialImportGate(shouldBlock: false)
            }
        case .import:
            importInFlight = false
            if event.succeeded {
                CloudKitBootstrap.markInitialImportCompleted()
                appSyncState.markLastSyncFinished()
                appSyncState.updateInitialImportGate(shouldBlock: false)
                onRemoteStoreChange()
            } else {
                appSyncState.reportError(CloudKitErrorMessage.userFacing(event.error))
                appSyncState.updateInitialImportGate(shouldBlock: false)
            }
        case .export:
            exportInFlight = false
            if event.succeeded {
                appSyncState.markLastSyncFinished()
            } else {
                appSyncState.reportError(CloudKitErrorMessage.userFacing(event.error))
            }
        default:
            break
        }

        if !importInFlight, !exportInFlight {
            appSyncState.setSyncing(false)
        }
    }
}
