import Foundation

@MainActor
final class ICloudIdentityObserver {
    static let shared = ICloudIdentityObserver()

    private var observerToken: NSObjectProtocol?

    private init() {}

    func start(
        appSyncState: AppSyncState,
        onAccountChange: @escaping @MainActor () -> Void
    ) {
        guard observerToken == nil else { return }

        observerToken = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSUbiquityIdentityDidChange,
            object: nil,
            queue: .main
        ) { [weak appSyncState] _ in
            Task { @MainActor [weak appSyncState] in
                guard let appSyncState else { return }
                appSyncState.refreshICloudAvailability()
                onAccountChange()
            }
        }
    }

    func stop() {
        if let observerToken {
            NotificationCenter.default.removeObserver(observerToken)
        }
        observerToken = nil
    }
}
