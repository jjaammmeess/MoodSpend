import Foundation

/// User-controlled iCloud sync preference. Mirrored in `AppPreferences` and read at launch before SwiftData opens.
enum CloudSyncStorage {
    static let userEnabledKey = "settings.iCloudSyncEnabled"

    /// Default for first install: sync on (matches product positioning).
    static let defaultUserEnabled = true

    /// Persisted user intent (independent of iCloud sign-in).
    static var isUserSyncEnabled: Bool {
        get {
            guard UserDefaults.standard.object(forKey: userEnabledKey) != nil else {
                return defaultUserEnabled
            }
            return UserDefaults.standard.bool(forKey: userEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userEnabledKey)
        }
    }

    /// User wants sync and this device can reach iCloud.
    static var isSyncActive: Bool {
        isUserSyncEnabled && ICloudAvailability.isSignedIn
    }
}
