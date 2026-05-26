import Combine
import Foundation
import SwiftData

enum AppNotificationType: String, Codable, CaseIterable, Identifiable {
    case warning
    case task
    case system

    var id: String { rawValue }
}

enum AppNotificationPriority: String, Codable {
    case high
    case medium
    case low
}

enum AppNotificationAction: String, Codable {
    case none
    case openAnalysis
    case openAddRecord
    case openRecordRetrospective
}

enum NotificationFilterTab: String, CaseIterable, Identifiable {
    case all
    case warning
    case task
    case system

    var id: String { rawValue }
}

struct AppNotificationItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let type: AppNotificationType
    let priority: AppNotificationPriority
    let title: String
    let message: String
    let createdAt: Date
    var isRead: Bool
    var isPinned: Bool
    let action: AppNotificationAction
    let warningEmotionRaw: String?
    let warningCount: Int?
    let warningAmount: Double?
    let dedupKey: String?
    let linkedRecordId: UUID?
    /// Base64 JSON of `PersistentIdentifier`; preferred over `linkedRecordId` for opening the correct row.
    let linkedRecordPersistentToken: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case priority
        case title
        case message
        case createdAt
        case isRead
        case isPinned
        case action
        case warningEmotionRaw
        case warningCount
        case warningAmount
        case dedupKey
        case linkedRecordId
        case linkedRecordPersistentToken
    }

    init(
        id: UUID,
        type: AppNotificationType,
        priority: AppNotificationPriority,
        title: String,
        message: String,
        createdAt: Date,
        isRead: Bool,
        isPinned: Bool,
        action: AppNotificationAction,
        warningEmotionRaw: String? = nil,
        warningCount: Int? = nil,
        warningAmount: Double? = nil,
        dedupKey: String?,
        linkedRecordId: UUID? = nil,
        linkedRecordPersistentToken: String? = nil
    ) {
        self.id = id
        self.type = type
        self.priority = priority
        self.title = title
        self.message = message
        self.createdAt = createdAt
        self.isRead = isRead
        self.isPinned = isPinned
        self.action = action
        self.warningEmotionRaw = warningEmotionRaw
        self.warningCount = warningCount
        self.warningAmount = warningAmount
        self.dedupKey = dedupKey
        self.linkedRecordId = linkedRecordId
        self.linkedRecordPersistentToken = linkedRecordPersistentToken
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(AppNotificationType.self, forKey: .type)
        priority = try container.decodeIfPresent(AppNotificationPriority.self, forKey: .priority) ?? .medium
        title = try container.decode(String.self, forKey: .title)
        message = try container.decode(String.self, forKey: .message)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isRead = try container.decode(Bool.self, forKey: .isRead)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        action = try container.decodeIfPresent(AppNotificationAction.self, forKey: .action) ?? .none
        warningEmotionRaw = try container.decodeIfPresent(String.self, forKey: .warningEmotionRaw)
        warningCount = try container.decodeIfPresent(Int.self, forKey: .warningCount)
        warningAmount = try container.decodeIfPresent(Double.self, forKey: .warningAmount)
        dedupKey = try container.decodeIfPresent(String.self, forKey: .dedupKey)
        linkedRecordId = try container.decodeIfPresent(UUID.self, forKey: .linkedRecordId)
        linkedRecordPersistentToken = try container.decodeIfPresent(String.self, forKey: .linkedRecordPersistentToken)
    }
}

@MainActor
final class NotificationCenterStore: ObservableObject {
    private enum Keys {
        static let seeded = "notificationCenter.seeded"
    }

    @Published private(set) var items: [AppNotificationItem] = [] {
        didSet { persistToSwiftDataIfNeeded() }
    }

    /// Set from notification action; Analysis tab consumes to open retrospective sheet.
    @Published var pendingRetrospectivePublicId: UUID?
    /// Preferred pending link when the notification carries a stable SwiftData row token.
    @Published var pendingRetrospectivePersistentToken: String?

    private let defaults: UserDefaults
    private var modelContext: ModelContext?
    private var isApplyingRemoteValues = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func configure(modelContext: ModelContext) {
        guard self.modelContext == nil else { return }
        self.modelContext = modelContext
        PersistenceController.shared.configure(modelContext)

        isApplyingRemoteValues = true
        if let loaded = try? NotificationRepository.fetchAllSorted(in: modelContext), !loaded.isEmpty {
            items = loaded
        }
        isApplyingRemoteValues = false

        finishLoadingFromStore(modelContext: modelContext)
    }

    func reloadFromSwiftData() {
        guard let modelContext else { return }
        isApplyingRemoteValues = true
        if let loaded = try? NotificationRepository.fetchAllSorted(in: modelContext) {
            items = loaded
        }
        isApplyingRemoteValues = false
        finishLoadingFromStore(modelContext: modelContext)
    }

    private func finishLoadingFromStore(modelContext: ModelContext) {
        migrateLegacyWarningMetadataIfNeeded()
        deduplicateRetrospectiveTasks()
        pruneOrphanedRetrospectiveTasks(modelContext: modelContext)
        pruneOlderThan(days: 30)
    }

    var unreadCount: Int {
        items.filter { !$0.isRead }.count
    }

    func filteredItems(tab: NotificationFilterTab) -> [AppNotificationItem] {
        switch tab {
        case .all:
            return items
        case .warning:
            return items.filter { $0.type == .warning }
        case .task:
            return items.filter { $0.type == .task }
        case .system:
            return items.filter { $0.type == .system }
        }
    }

    func markRead(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        guard !items[index].isRead else { return }
        items[index].isRead = true
    }

    func markAllRead(tab: NotificationFilterTab) {
        for index in items.indices {
            switch tab {
            case .all:
                items[index].isRead = true
            case .warning where items[index].type == .warning:
                items[index].isRead = true
            case .task where items[index].type == .task:
                items[index].isRead = true
            case .system where items[index].type == .system:
                items[index].isRead = true
            default:
                continue
            }
        }
    }

    func togglePin(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned.toggle()
        sortByDisplayOrder()
    }

    func containsNotification(withDedupKey key: String) -> Bool {
        items.contains { $0.dedupKey == key }
    }

    func hasRetrospectiveTask(forPublicId publicId: UUID) -> Bool {
        items.contains { $0.action == .openRecordRetrospective && $0.linkedRecordId == publicId }
    }

    /// Retrospective reminder rows whose `createdAt` falls in the same week as `date` (per `calendar`).
    func retrospectiveNotificationCount(inSameWeekAs date: Date, calendar: Calendar = .current) -> Int {
        let recordIds = items.compactMap { item -> UUID? in
            guard item.action == .openRecordRetrospective,
                  let publicId = item.linkedRecordId,
                  calendar.isDate(item.createdAt, equalTo: date, toGranularity: .weekOfYear) else {
                return nil
            }
            return publicId
        }
        let legacyRows = items.filter { item in
            guard item.action == .openRecordRetrospective, item.linkedRecordId == nil,
                  let dk = item.dedupKey, dk.hasPrefix("retrospective.") else { return false }
            return calendar.isDate(item.createdAt, equalTo: date, toGranularity: .weekOfYear)
        }.count
        return Set(recordIds).count + legacyRows
    }

    /// Collapses duplicate retrospective rows for the same bill (legacy token vs publicId dedup keys).
    func deduplicateRetrospectiveTasks() {
        var grouped = [UUID: [Int]]()
        for (index, item) in items.enumerated() {
            guard item.action == .openRecordRetrospective, let publicId = item.linkedRecordId else { continue }
            grouped[publicId, default: []].append(index)
        }

        var removeIndices = Set<Int>()
        var replacements: [Int: AppNotificationItem] = [:]

        for (publicId, indices) in grouped {
            let canonicalKey = RetrospectiveReviewService.retrospectiveDedupKey(publicId: publicId)
            let keeperIndex = indices.first { items[$0].dedupKey == canonicalKey }
                ?? indices.min(by: { items[$0].createdAt < items[$1].createdAt })!
            let mergedIsRead = indices.allSatisfy { items[$0].isRead }
            for index in indices where index != keeperIndex {
                removeIndices.insert(index)
            }
            let keeper = items[keeperIndex]
            if keeper.dedupKey != canonicalKey || keeper.isRead != mergedIsRead {
                replacements[keeperIndex] = AppNotificationItem(
                    id: keeper.id,
                    type: keeper.type,
                    priority: keeper.priority,
                    title: keeper.title,
                    message: keeper.message,
                    createdAt: keeper.createdAt,
                    isRead: mergedIsRead,
                    isPinned: keeper.isPinned,
                    action: keeper.action,
                    warningEmotionRaw: keeper.warningEmotionRaw,
                    warningCount: keeper.warningCount,
                    warningAmount: keeper.warningAmount,
                    dedupKey: canonicalKey,
                    linkedRecordId: keeper.linkedRecordId,
                    linkedRecordPersistentToken: keeper.linkedRecordPersistentToken
                )
            }
        }

        guard !removeIndices.isEmpty || !replacements.isEmpty else { return }

        items = items.enumerated().compactMap { offset, item in
            if removeIndices.contains(offset) { return nil }
            return replacements[offset] ?? item
        }
        sortByDisplayOrder()
    }

    func delete(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    /// Removes the in-app retrospective reminder for a bill (answered, deleted, etc.).
    func removeRetrospectiveTask(for record: TransactionRecord) {
        let publicId = record.publicId
        var keys = Set<String>()
        if let token = RetrospectiveRecordLink.persistentToken(for: record) {
            keys.insert("retrospective.\(token)")
        }
        keys.insert("retrospective.\(publicId.uuidString)")
        items.removeAll { item in
            guard item.action == .openRecordRetrospective else { return false }
            if item.linkedRecordId == publicId { return true }
            if let dk = item.dedupKey, keys.contains(dk) { return true }
            return false
        }
    }

    /// Drops every retrospective task row (e.g. clear-all data).
    func removeAllRetrospectiveTasks() {
        items.removeAll { $0.action == .openRecordRetrospective }
    }

    /// Removes retrospective tasks whose linked bill no longer exists in the store.
    func pruneOrphanedRetrospectiveTasks(modelContext: ModelContext) {
        let before = items.count
        items.removeAll { item in
            guard item.action == .openRecordRetrospective else { return false }
            return RetrospectiveReviewService.linkedRecord(for: item, modelContext: modelContext) == nil
        }
        guard items.count != before else { return }
        sortByDisplayOrder()
    }

    func deleteAll(tab: NotificationFilterTab) {
        switch tab {
        case .all:
            items.removeAll()
        case .warning:
            items.removeAll { $0.type == .warning }
        case .task:
            items.removeAll { $0.type == .task }
        case .system:
            items.removeAll { $0.type == .system }
        }
    }

    func seedIfNeeded(systemTitle: String, systemMessage: String, taskTitle: String, taskMessage: String) {
        guard !defaults.bool(forKey: Keys.seeded) else { return }
        let now = Date()
        items.insert(
            AppNotificationItem(
                id: UUID(),
                type: .system,
                priority: .low,
                title: systemTitle,
                message: systemMessage,
                createdAt: now,
                isRead: false,
                isPinned: true,
                action: .none,
                dedupKey: "system.welcome",
                linkedRecordId: nil,
                linkedRecordPersistentToken: nil
            ),
            at: 0
        )
        items.insert(
            AppNotificationItem(
                id: UUID(),
                type: .task,
                priority: .medium,
                title: taskTitle,
                message: taskMessage,
                createdAt: now.addingTimeInterval(-60),
                isRead: false,
                isPinned: false,
                action: .openAddRecord,
                dedupKey: "task.first.record",
                linkedRecordId: nil,
                linkedRecordPersistentToken: nil
            ),
            at: 0
        )
        sortByDisplayOrder()
        defaults.set(true, forKey: Keys.seeded)
    }

    func refreshSeedLocalization(
        systemTitle: String,
        systemMessage: String,
        taskTitle: String,
        taskMessage: String
    ) {
        for index in items.indices {
            switch items[index].dedupKey {
            case "system.welcome":
                items[index] = AppNotificationItem(
                    id: items[index].id,
                    type: items[index].type,
                    priority: items[index].priority,
                    title: systemTitle,
                    message: systemMessage,
                    createdAt: items[index].createdAt,
                    isRead: items[index].isRead,
                    isPinned: items[index].isPinned,
                    action: items[index].action,
                    warningEmotionRaw: items[index].warningEmotionRaw,
                    warningCount: items[index].warningCount,
                    warningAmount: items[index].warningAmount,
                    dedupKey: items[index].dedupKey,
                    linkedRecordId: items[index].linkedRecordId,
                    linkedRecordPersistentToken: items[index].linkedRecordPersistentToken
                )
            case "task.first.record":
                items[index] = AppNotificationItem(
                    id: items[index].id,
                    type: items[index].type,
                    priority: items[index].priority,
                    title: taskTitle,
                    message: taskMessage,
                    createdAt: items[index].createdAt,
                    isRead: items[index].isRead,
                    isPinned: items[index].isPinned,
                    action: items[index].action,
                    warningEmotionRaw: items[index].warningEmotionRaw,
                    warningCount: items[index].warningCount,
                    warningAmount: items[index].warningAmount,
                    dedupKey: items[index].dedupKey,
                    linkedRecordId: items[index].linkedRecordId,
                    linkedRecordPersistentToken: items[index].linkedRecordPersistentToken
                )
            default:
                continue
            }
        }
        sortByDisplayOrder()
    }

    func upsertTask(
        dedupKey: String,
        title: String,
        message: String,
        action: AppNotificationAction,
        linkedRecordId: UUID? = nil,
        linkedRecordPersistentToken: String? = nil,
        createdAt: Date = Date()
    ) {
        if let index = items.firstIndex(where: { $0.dedupKey == dedupKey }) {
            let existing = items[index]
            items[index] = AppNotificationItem(
                id: existing.id,
                type: .task,
                priority: .medium,
                title: title,
                message: message,
                createdAt: existing.createdAt,
                isRead: existing.isRead,
                isPinned: existing.isPinned,
                action: action,
                dedupKey: dedupKey,
                linkedRecordId: linkedRecordId,
                linkedRecordPersistentToken: linkedRecordPersistentToken
            )
            sortByDisplayOrder()
            return
        }
        items.insert(
            AppNotificationItem(
                id: UUID(),
                type: .task,
                priority: .medium,
                title: title,
                message: message,
                createdAt: createdAt,
                isRead: false,
                isPinned: false,
                action: action,
                dedupKey: dedupKey,
                linkedRecordId: linkedRecordId,
                linkedRecordPersistentToken: linkedRecordPersistentToken
            ),
            at: 0
        )
        sortByDisplayOrder()
        pruneOlderThan(days: 30)
    }

    func addWarning(title: String, message: String, emotionRaw: String, count: Int, amount: Double) {
        let dedupKey = warningDedupKey(for: emotionRaw, date: Date())
        guard !items.contains(where: { $0.dedupKey == dedupKey }) else { return }
        items.insert(
            AppNotificationItem(
                id: UUID(),
                type: .warning,
                priority: .high,
                title: title,
                message: message,
                createdAt: Date(),
                isRead: false,
                isPinned: false,
                action: .openAnalysis,
                warningEmotionRaw: emotionRaw,
                warningCount: count,
                warningAmount: amount,
                dedupKey: dedupKey,
                linkedRecordId: nil,
                linkedRecordPersistentToken: nil
            ),
            at: 0
        )
        sortByDisplayOrder()
        pruneOlderThan(days: 30)
    }

    func refreshWarningLocalization(locale: Locale, text: (LKey) -> String) {
        for index in items.indices {
            guard items[index].type == .warning,
                  let emotionRaw = items[index].warningEmotionRaw,
                  let count = items[index].warningCount,
                  let amount = items[index].warningAmount else {
                continue
            }
            let emotionName: String = {
                if let emotion = EmotionTag.from(raw: emotionRaw) {
                    return text(emotion.key)
                }
                return emotionRaw
            }()
            let message = String(
                format: text(.alertTemplate),
                locale: locale,
                arguments: [emotionName, "\(count)", localizedMoney(amount: amount, locale: locale)]
            )
            items[index] = AppNotificationItem(
                id: items[index].id,
                type: items[index].type,
                priority: items[index].priority,
                title: text(.alertTitle),
                message: message,
                createdAt: items[index].createdAt,
                isRead: items[index].isRead,
                isPinned: items[index].isPinned,
                action: items[index].action,
                warningEmotionRaw: items[index].warningEmotionRaw,
                warningCount: items[index].warningCount,
                warningAmount: items[index].warningAmount,
                dedupKey: items[index].dedupKey,
                linkedRecordId: items[index].linkedRecordId,
                linkedRecordPersistentToken: items[index].linkedRecordPersistentToken
            )
        }
        sortByDisplayOrder()
    }

    /// Re-localizes retrospective task rows (title + message) from the linked `TransactionRecord` when possible.
    func refreshRetrospectiveTaskLocalization(
        modelContext: ModelContext,
        locale: Locale,
        localizedText: (LKey) -> String,
        formatMoney: (Double) -> String
    ) {
        deduplicateRetrospectiveTasks()
        pruneOrphanedRetrospectiveTasks(modelContext: modelContext)
        var copy = items
        var changed = false
        for index in copy.indices {
            guard copy[index].action == .openRecordRetrospective else { continue }
            let newTitle = localizedText(.notificationRetrospectiveTitle)
            let newMessage: String
            if let record = RetrospectiveReviewService.linkedRecord(for: copy[index], modelContext: modelContext) {
                newMessage = RetrospectiveReviewService.retrospectiveNotificationBody(
                    record: record,
                    locale: locale,
                    localizedText: localizedText,
                    formatMoney: formatMoney
                )
            } else {
                newMessage = copy[index].message
            }
            guard newTitle != copy[index].title || newMessage != copy[index].message else { continue }
            let old = copy[index]
            copy[index] = AppNotificationItem(
                id: old.id,
                type: old.type,
                priority: old.priority,
                title: newTitle,
                message: newMessage,
                createdAt: old.createdAt,
                isRead: old.isRead,
                isPinned: old.isPinned,
                action: old.action,
                warningEmotionRaw: old.warningEmotionRaw,
                warningCount: old.warningCount,
                warningAmount: old.warningAmount,
                dedupKey: old.dedupKey,
                linkedRecordId: old.linkedRecordId,
                linkedRecordPersistentToken: old.linkedRecordPersistentToken
            )
            changed = true
        }
        guard changed else { return }
        items = copy
        sortByDisplayOrder()
    }

    private func warningDedupKey(for emotionRaw: String, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return "warning.\(emotionRaw).\(formatter.string(from: date))"
    }

    private func localizedMoney(amount: Double, locale: Locale) -> String {
        AppFormatter.moneyString(from: amount, locale: locale)
    }

    private func migrateLegacyWarningMetadataIfNeeded() {
        var changed = false
        for index in items.indices {
            guard items[index].type == .warning else { continue }
            guard items[index].warningEmotionRaw == nil else { continue }
            guard let dedupKey = items[index].dedupKey,
                  let parsedEmotionRaw = parseWarningEmotionRaw(from: dedupKey) else {
                continue
            }
            items[index] = AppNotificationItem(
                id: items[index].id,
                type: items[index].type,
                priority: items[index].priority,
                title: items[index].title,
                message: items[index].message,
                createdAt: items[index].createdAt,
                isRead: items[index].isRead,
                isPinned: items[index].isPinned,
                action: items[index].action,
                warningEmotionRaw: parsedEmotionRaw,
                warningCount: items[index].warningCount,
                warningAmount: items[index].warningAmount,
                dedupKey: items[index].dedupKey,
                linkedRecordId: items[index].linkedRecordId,
                linkedRecordPersistentToken: items[index].linkedRecordPersistentToken
            )
            changed = true
        }
        if changed {
            sortByDisplayOrder()
        }
    }

    private func parseWarningEmotionRaw(from dedupKey: String) -> String? {
        let components = dedupKey.split(separator: ".")
        guard components.count >= 3 else { return nil }
        guard components.first == "warning" else { return nil }
        return String(components[1])
    }

    private func sortByDisplayOrder() {
        items.sort { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private func pruneOlderThan(days: Int) {
        guard days > 0 else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date.distantPast
        items.removeAll { !$0.isPinned && $0.createdAt < cutoff }
        sortByDisplayOrder()
    }

    private func persistToSwiftDataIfNeeded() {
        guard !isApplyingRemoteValues, let modelContext else { return }
        try? NotificationRepository.replaceAll(items, in: modelContext)
    }

    // MARK: - Backup / restore

    /// Replaces or merges in-app notification rows from a JSON backup.
    func applyBackupRestore(_ incoming: [AppNotificationItem], mode: RestoreMode) -> Int {
        let countBefore = items.count
        switch mode {
        case .replace:
            items = incoming
        case .merge:
            var existingDedupKeys = Set(items.compactMap(\.dedupKey))
            var existingIDs = Set(items.map(\.id))
            var merged = items
            for item in incoming {
                if let dedupKey = item.dedupKey {
                    guard !existingDedupKeys.contains(dedupKey) else { continue }
                    existingDedupKeys.insert(dedupKey)
                } else {
                    guard !existingIDs.contains(item.id) else { continue }
                }
                merged.append(item)
                existingIDs.insert(item.id)
            }
            items = merged
        }
        if !incoming.isEmpty {
            defaults.set(true, forKey: Keys.seeded)
        }
        deduplicateRetrospectiveTasks()
        sortByDisplayOrder()
        pruneOlderThan(days: 30)
        switch mode {
        case .replace:
            return incoming.count
        case .merge:
            return max(0, items.count - countBefore)
        }
    }
}
