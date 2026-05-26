import Combine
import Foundation

@MainActor
final class AppSyncState: ObservableObject {
    private static let lastSyncFinishedAtKey = "afterbuy.cloudkit.lastSyncFinishedAt"

    enum AccountStatusHint: Equatable {
        case noAccount
        case restricted
        case temporarilyUnavailable
        case couldNotDetermine
    }

    @Published private(set) var isSyncing = false
    @Published private(set) var isICloudAvailable = ICloudAvailability.isSignedIn
    @Published private(set) var isWaitingForInitialImport = false
    @Published private(set) var lastImportFinishedAt: Date?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var accountStatusHint: AccountStatusHint?
    /// Legacy hook for manual invalidation. Prefer SwiftData `@Query` + `SyncedStoreRefreshCoordinator` (do not rebuild the tab root).
    @Published private(set) var dataRefreshGeneration = UUID()

    init() {
        lastImportFinishedAt = Self.loadPersistedLastSyncFinishedAt()
    }

    var isCloudKitEnabled: Bool {
        PersistenceConfiguration.cloudKitSyncEnabled
    }

    func refreshICloudAvailability() {
        isICloudAvailable = ICloudAvailability.isSignedIn
        if !isICloudAvailable {
            accountStatusHint = nil
        }
    }

    func setAccountStatusHint(_ hint: AccountStatusHint?) {
        accountStatusHint = hint
    }

    func setSyncing(_ syncing: Bool) {
        isSyncing = syncing
    }

    func markLastSyncFinished() {
        let now = Date()
        lastImportFinishedAt = now
        isSyncing = false
        UserDefaults.standard.set(now, forKey: Self.lastSyncFinishedAtKey)
    }

    private static func loadPersistedLastSyncFinishedAt() -> Date? {
        UserDefaults.standard.object(forKey: lastSyncFinishedAtKey) as? Date
    }

    func reportError(_ message: String?) {
        let trimmed = message?.trimmingCharacters(in: .whitespacesAndNewlines)
        lastErrorMessage = trimmed?.isEmpty == false ? trimmed : nil
        isSyncing = false
    }

    func clearLastError() {
        lastErrorMessage = nil
    }

    func updateInitialImportGate(shouldBlock: Bool) {
        isWaitingForInitialImport = shouldBlock
    }

    func bumpDataRefresh() {
        dataRefreshGeneration = UUID()
    }
}
