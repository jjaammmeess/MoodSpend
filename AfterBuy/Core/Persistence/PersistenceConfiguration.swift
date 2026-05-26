import Foundation

enum PersistenceConfiguration {
    static let cloudKitContainerIdentifier = "iCloud.JamesLiu.AfterBuy"

    /// When `false`, SwiftData opens without CloudKit mirroring (user preference or previews).
    static var cloudKitSyncEnabled: Bool {
        CloudSyncStorage.isUserSyncEnabled
    }

    /// SwiftData default on disk before a dedicated CloudKit store was introduced.
    static let legacyLocalStoreFilename = "default.store"
    /// Fresh sqlite file used with CloudKit mirroring (do not reuse `default.store`).
    static let cloudKitStoreFilename = "AfterBuyCloud.store"

    static let profileSingletonId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let preferencesSingletonId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    static var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    static var legacyStoreURL: URL {
        applicationSupportDirectory.appendingPathComponent(legacyLocalStoreFilename)
    }

    static var cloudKitStoreURL: URL {
        applicationSupportDirectory.appendingPathComponent(cloudKitStoreFilename)
    }

    /// Primary on-disk store. Keeps the same file when toggling iCloud so data is not stranded.
    static var activeStoreURL: URL {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: cloudKitStoreURL.path) {
            return cloudKitStoreURL
        }
        if fileManager.fileExists(atPath: legacyStoreURL.path) {
            return legacyStoreURL
        }
        return cloudKitSyncEnabled ? cloudKitStoreURL : legacyStoreURL
    }
}
