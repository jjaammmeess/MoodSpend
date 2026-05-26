import Foundation
import SwiftData

@MainActor
enum NotificationRepository {
    static func fetchAllSorted(in context: ModelContext) throws -> [AppNotificationItem] {
        let descriptor = FetchDescriptor<SyncedAppNotification>(
            sortBy: [SortDescriptor(\SyncedAppNotification.createdAt, order: .reverse)]
        )
        let rows = try context.fetch(descriptor)
        return rows.map { $0.toAppNotificationItem() }.sorted(by: displayOrder)
    }

    static func replaceAll(_ items: [AppNotificationItem], in context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<SyncedAppNotification>())
        for row in existing {
            context.delete(row)
        }
        for item in items {
            context.insert(SyncedAppNotification(from: item))
        }
        try context.save()
    }

    static func upsert(_ item: AppNotificationItem, in context: ModelContext) throws {
        let targetId = item.id
        var descriptor = FetchDescriptor<SyncedAppNotification>(
            predicate: #Predicate { $0.id == targetId }
        )
        descriptor.fetchLimit = 1
        if let row = try context.fetch(descriptor).first {
            apply(item, to: row)
        } else {
            context.insert(SyncedAppNotification(from: item))
        }
        try context.save()
    }

    static func delete(id: UUID, in context: ModelContext) throws {
        var descriptor = FetchDescriptor<SyncedAppNotification>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        if let row = try context.fetch(descriptor).first {
            context.delete(row)
            try context.save()
        }
    }

    private static func apply(_ item: AppNotificationItem, to row: SyncedAppNotification) {
        row.typeRaw = item.type.rawValue
        row.priorityRaw = item.priority.rawValue
        row.title = item.title
        row.message = item.message
        row.createdAt = item.createdAt
        row.isRead = item.isRead
        row.isPinned = item.isPinned
        row.actionRaw = item.action.rawValue
        row.warningEmotionRaw = item.warningEmotionRaw
        row.warningCount = item.warningCount
        row.warningAmount = item.warningAmount
        row.dedupKey = item.dedupKey
        row.linkedRecordId = item.linkedRecordId
        row.linkedRecordPersistentToken = item.linkedRecordPersistentToken
    }

    private static func displayOrder(_ lhs: AppNotificationItem, _ rhs: AppNotificationItem) -> Bool {
        if lhs.isPinned != rhs.isPinned {
            return lhs.isPinned && !rhs.isPinned
        }
        return lhs.createdAt > rhs.createdAt
    }
}
