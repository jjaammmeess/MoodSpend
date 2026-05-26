import Foundation
import SwiftData

@MainActor
enum PreferencesRepository {
    static func fetchOrCreate(in context: ModelContext) throws -> AppPreferences {
        AppPreferencesConsolidation.consolidateIfNeeded(in: context)

        let singletonId = PersistenceConfiguration.preferencesSingletonId
        var descriptor = FetchDescriptor<AppPreferences>(
            predicate: #Predicate { $0.singletonId == singletonId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            normalizeThemeModeIfNeeded(existing, in: context)
            return existing
        }
        let preferences = AppPreferences()
        context.insert(preferences)
        try context.save()
        return preferences
    }

    static func save(_ preferences: AppPreferences, in context: ModelContext) throws {
        preferences.updatedAt = Date()
        try context.save()
    }

    /// Ensures first-install and corrupted rows never pin light/dark by accident.
    private static func normalizeThemeModeIfNeeded(
        _ preferences: AppPreferences,
        in context: ModelContext
    ) {
        let resolved = AppThemeMode.resolved(from: preferences.themeModeRaw)
        guard preferences.themeModeRaw != resolved.rawValue else { return }
        preferences.themeModeRaw = resolved.rawValue
        try? save(preferences, in: context)
    }
}
