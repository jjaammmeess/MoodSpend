import SwiftUI

/// User-selected appearance; persisted as `themeModeRaw` on `AppPreferences`.
enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// First install, missing preference, and invalid stored values all resolve here.
    static let defaultMode: AppThemeMode = .system

    static let defaultRawValue = defaultMode.rawValue

    /// Resolves a persisted raw string. Never forces light or dark unless explicitly stored.
    static func resolved(from rawValue: String?) -> AppThemeMode {
        guard let rawValue, !rawValue.isEmpty else { return defaultMode }
        return AppThemeMode(rawValue: rawValue) ?? defaultMode
    }

    /// `nil` means follow the system (`preferredColorScheme` unset).
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
