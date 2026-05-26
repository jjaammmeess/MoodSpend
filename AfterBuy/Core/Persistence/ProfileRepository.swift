import Foundation
import SwiftData

@MainActor
enum ProfileRepository {
    static func fetchOrCreate(in context: ModelContext) throws -> UserProfile {
        UserProfileConsolidation.consolidateIfNeeded(in: context)

        let singletonId = PersistenceConfiguration.profileSingletonId
        var descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.singletonId == singletonId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let profile = UserProfile()
        context.insert(profile)
        try context.save()
        return profile
    }

    static func save(
        displayName: String,
        avatarImageData: Data?,
        avatarPresetID: String?,
        in context: ModelContext
    ) throws {
        let profile = try fetchOrCreate(in: context)
        profile.displayName = displayName
        profile.avatarImageData = avatarImageData
        profile.avatarPresetID = avatarPresetID
        profile.updatedAt = Date()
        try context.save()
    }
}
