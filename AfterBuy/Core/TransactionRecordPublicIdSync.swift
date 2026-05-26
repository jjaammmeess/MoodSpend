import Foundation
import SwiftData

/// Ensures every bill has a **stable, unique** `publicId` for notifications / deep links.
/// Older rows or restored backups may collide; duplicates after the first (by `createdAt`) get new UUIDs.
enum TransactionRecordPublicIdSync {
    @MainActor
    static func ensureUniquePublicIds(modelContext: ModelContext) {
        guard let records = try? modelContext.fetch(FetchDescriptor<TransactionRecord>()) else { return }
        guard !records.isEmpty else { return }

        let sorted = records.sorted { $0.createdAt < $1.createdAt }
        var used = Set<UUID>()
        var didMutate = false

        for record in sorted {
            if used.contains(record.publicId) {
                var newId = UUID()
                while used.contains(newId) {
                    newId = UUID()
                }
                record.publicId = newId
                record.touchUpdatedAt()
                didMutate = true
            }
            used.insert(record.publicId)
        }

        if didMutate {
            try? modelContext.save()
        }
    }
}
