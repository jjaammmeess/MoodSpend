import Foundation
import SwiftData

@Model
final class SyncedAppNotification {
    var id: UUID = UUID()
    var typeRaw: String = AppNotificationType.system.rawValue
    var priorityRaw: String = AppNotificationPriority.medium.rawValue
    var title: String = ""
    var message: String = ""
    var createdAt: Date = Date()
    var isRead: Bool = false
    var isPinned: Bool = false
    var actionRaw: String = AppNotificationAction.none.rawValue
    var warningEmotionRaw: String?
    var warningCount: Int?
    var warningAmount: Double?
    var dedupKey: String?
    var linkedRecordId: UUID?
    /// Device-local deep link token; optional and may be nil after cross-device sync.
    var linkedRecordPersistentToken: String?

    init(
        id: UUID = UUID(),
        typeRaw: String,
        priorityRaw: String = AppNotificationPriority.medium.rawValue,
        title: String,
        message: String,
        createdAt: Date = Date(),
        isRead: Bool = false,
        isPinned: Bool = false,
        actionRaw: String = AppNotificationAction.none.rawValue,
        warningEmotionRaw: String? = nil,
        warningCount: Int? = nil,
        warningAmount: Double? = nil,
        dedupKey: String? = nil,
        linkedRecordId: UUID? = nil,
        linkedRecordPersistentToken: String? = nil
    ) {
        self.id = id
        self.typeRaw = typeRaw
        self.priorityRaw = priorityRaw
        self.title = title
        self.message = message
        self.createdAt = createdAt
        self.isRead = isRead
        self.isPinned = isPinned
        self.actionRaw = actionRaw
        self.warningEmotionRaw = warningEmotionRaw
        self.warningCount = warningCount
        self.warningAmount = warningAmount
        self.dedupKey = dedupKey
        self.linkedRecordId = linkedRecordId
        self.linkedRecordPersistentToken = linkedRecordPersistentToken
    }

    convenience init(from item: AppNotificationItem) {
        self.init(
            id: item.id,
            typeRaw: item.type.rawValue,
            priorityRaw: item.priority.rawValue,
            title: item.title,
            message: item.message,
            createdAt: item.createdAt,
            isRead: item.isRead,
            isPinned: item.isPinned,
            actionRaw: item.action.rawValue,
            warningEmotionRaw: item.warningEmotionRaw,
            warningCount: item.warningCount,
            warningAmount: item.warningAmount,
            dedupKey: item.dedupKey,
            linkedRecordId: item.linkedRecordId,
            linkedRecordPersistentToken: item.linkedRecordPersistentToken
        )
    }

    func toAppNotificationItem() -> AppNotificationItem {
        AppNotificationItem(
            id: id,
            type: AppNotificationType(rawValue: typeRaw) ?? .system,
            priority: AppNotificationPriority(rawValue: priorityRaw) ?? .medium,
            title: title,
            message: message,
            createdAt: createdAt,
            isRead: isRead,
            isPinned: isPinned,
            action: AppNotificationAction(rawValue: actionRaw) ?? .none,
            warningEmotionRaw: warningEmotionRaw,
            warningCount: warningCount,
            warningAmount: warningAmount,
            dedupKey: dedupKey,
            linkedRecordId: linkedRecordId,
            linkedRecordPersistentToken: linkedRecordPersistentToken
        )
    }
}
