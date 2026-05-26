import Foundation
import SwiftData

@MainActor
enum AppPreferencesConsolidation {
    static func consolidateIfNeeded(in context: ModelContext) {
        let targetId = PersistenceConfiguration.preferencesSingletonId
        let descriptor = FetchDescriptor<AppPreferences>(
            predicate: #Predicate { $0.singletonId == targetId }
        )
        guard let rows = try? context.fetch(descriptor), rows.count > 1 else { return }

        guard let canonical = rows.max(by: { $0.updatedAt < $1.updatedAt }) else { return }
        for duplicate in rows where duplicate.persistentModelID != canonical.persistentModelID {
            if duplicate.updatedAt > canonical.updatedAt {
                canonical.themeModeRaw = duplicate.themeModeRaw
                canonical.languageRaw = duplicate.languageRaw
                canonical.emotionAlertEnabled = duplicate.emotionAlertEnabled
                canonical.emotionAlertHighRiskOnly = duplicate.emotionAlertHighRiskOnly
                canonical.emotionAlertCooldownDays = duplicate.emotionAlertCooldownDays
                canonical.patternMinCount = duplicate.patternMinCount
                canonical.patternMinRatio = duplicate.patternMinRatio
                canonical.emotionIconStyleRaw = duplicate.emotionIconStyleRaw
                canonical.iCloudSyncEnabled = duplicate.iCloudSyncEnabled
                canonical.updatedAt = duplicate.updatedAt
            }
            context.delete(duplicate)
        }
        try? context.save()
    }
}
