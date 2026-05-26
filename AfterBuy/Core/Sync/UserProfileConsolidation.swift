import Foundation
import SwiftData

/// CloudKit may sync multiple `UserProfile` rows that share the same `singletonId` (one per device).
/// Keep a single canonical row and merge avatar/name from duplicates so custom photos sync correctly.
@MainActor
enum UserProfileConsolidation {
    static func consolidateIfNeeded(in context: ModelContext) {
        let targetId = PersistenceConfiguration.profileSingletonId
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.singletonId == targetId }
        )
        guard let profiles = try? context.fetch(descriptor), profiles.count > 1 else { return }

        guard let canonical = profiles.max(by: { rank($0) < rank($1) }) else { return }
        var didChange = false

        for duplicate in profiles where duplicate.persistentModelID != canonical.persistentModelID {
            if mergeFields(from: duplicate, into: canonical) {
                didChange = true
            }
            context.delete(duplicate)
            didChange = true
        }

        if didChange {
            canonical.updatedAt = Date()
            try? context.save()
        }
    }

    private static func rank(_ profile: UserProfile) -> (Int, Date) {
        let hasAvatar = profile.avatarImageData.map { !$0.isEmpty } ?? false
        return (hasAvatar ? 1 : 0, profile.updatedAt)
    }

    @discardableResult
    private static func mergeFields(from source: UserProfile, into target: UserProfile) -> Bool {
        var changed = false

        if let data = source.avatarImageData, !data.isEmpty {
            let targetEmpty = target.avatarImageData.map { $0.isEmpty } ?? true
            if targetEmpty {
                target.avatarImageData = data
                target.avatarPresetID = nil
                changed = true
            }
        } else if target.avatarImageData.map({ $0.isEmpty }) ?? true,
                  let preset = source.avatarPresetID, !preset.isEmpty {
            target.avatarPresetID = preset
            changed = true
        }

        let targetName = target.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceName = source.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if (targetName.isEmpty || AppBranding.isLegacyDefaultDisplayName(targetName)),
           !sourceName.isEmpty,
           !AppBranding.isLegacyDefaultDisplayName(sourceName) {
            target.displayName = sourceName
            changed = true
        }

        if source.updatedAt > target.updatedAt {
            target.updatedAt = source.updatedAt
        }

        return changed
    }
}
