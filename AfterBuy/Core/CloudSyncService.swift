import Foundation

protocol CloudSyncServicing {
    var isEnabled: Bool { get }
    var isUserSyncEnabled: Bool { get }
    var providerName: String { get }
    func syncIfNeeded() async
}

struct CloudSyncService: CloudSyncServicing {
    var isEnabled: Bool {
        CloudSyncStorage.isSyncActive
    }

    var isUserSyncEnabled: Bool {
        CloudSyncStorage.isUserSyncEnabled
    }

    var providerName: String {
        "CloudKit"
    }

    func syncIfNeeded() async {
        guard isEnabled else { return }
        // NSPersistentCloudKitContainer syncs automatically via push + local edits.
    }
}
