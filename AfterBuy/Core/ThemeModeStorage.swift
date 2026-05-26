import Foundation

/// Keys and defaults for theme mode persistence (SwiftData + legacy migration).
enum ThemeModeStorage {
    /// Pre–SwiftData `UserDefaults` key; read only during one-time migration.
    static let legacyUserDefaultsKey = "settings.themeMode"
}
