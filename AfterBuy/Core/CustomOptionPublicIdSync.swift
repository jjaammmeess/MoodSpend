import Foundation
import SwiftData

/// Ensures every custom tag row has a stable unique `publicId` for CloudKit merges.
enum CustomOptionPublicIdSync {
    @MainActor
    static func ensureUniquePublicIds(modelContext: ModelContext) {
        guard let options = try? modelContext.fetch(FetchDescriptor<CustomOption>()) else { return }
        guard !options.isEmpty else { return }

        let sorted = options.sorted { $0.createdAt < $1.createdAt }
        var used = Set<UUID>()
        var didMutate = false

        for option in sorted {
            if used.contains(option.publicId) {
                var newId = UUID()
                while used.contains(newId) {
                    newId = UUID()
                }
                option.publicId = newId
                option.updatedAt = Date()
                didMutate = true
            }
            used.insert(option.publicId)
        }

        if didMutate {
            try? modelContext.save()
        }
    }
}
