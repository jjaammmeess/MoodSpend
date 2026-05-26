import Foundation
import SwiftData

enum RetrospectiveReviewService {
    /// Stable dedup id for retrospective tasks; always derived from `publicId` (not row token).
    static func retrospectiveDedupKey(publicId: UUID) -> String {
        "retrospective.\(publicId.uuidString)"
    }

    static func recordsNeedingReview(
        from records: [TransactionRecord],
        now: Date = Date()
    ) -> [TransactionRecord] {
        records.filter { record in
            guard record.type == .expense else { return false }
            guard record.retrospectiveWorthRaw == nil else { return false }
            return now.timeIntervalSince(record.createdAt) >= AnalysisChartMetrics.retrospectiveMinAge
        }
    }

    /// Whether this row should get an in-app **push** reminder (stricter than manual review in record detail).
    static func isEligibleForRetrospectivePush(
        record: TransactionRecord,
        customEmotions: [CustomOption]
    ) -> Bool {
        let bucket = EmotionGrouping.bucket(for: record, customEmotions: customEmotions)
        let amount = record.amount
        switch bucket {
        case .emotional:
            return amount >= AnalysisChartMetrics.retrospectivePushSmallAmountThreshold
        case .necessary:
            return amount >= AnalysisChartMetrics.retrospectivePushNecessityLargeAmountThreshold
        case .effective:
            return false
        }
    }

    @MainActor
    static func enqueueReviewNotifications(
        records: [TransactionRecord],
        customEmotions: [CustomOption],
        store: NotificationCenterStore,
        localizedText: (LKey) -> String,
        title: String,
        messageTemplate: (String, String, String) -> String,
        money: (Double) -> String,
        displayEmotion: (TransactionRecord) -> String,
        calendar: Calendar = .current,
        now: Date = Date()
    ) {
        store.deduplicateRetrospectiveTasks()

        let pending = recordsNeedingReview(from: records, now: now)
            .filter { isEligibleForRetrospectivePush(record: $0, customEmotions: customEmotions) }
            .sorted {
                if $0.amount != $1.amount { return $0.amount > $1.amount }
                return $0.createdAt < $1.createdAt
            }

        let weekExisting = store.retrospectiveNotificationCount(inSameWeekAs: now, calendar: calendar)
        var slotsRemaining = max(0, AnalysisChartMetrics.retrospectivePushWeeklyCap - weekExisting)

        for record in pending {
            let linkToken = RetrospectiveRecordLink.persistentToken(for: record)
            let dedupKey = retrospectiveDedupKey(publicId: record.publicId)
            let already = store.hasRetrospectiveTask(forPublicId: record.publicId)
            if !already, slotsRemaining <= 0 { continue }

            let emotion = displayEmotion(record)
            let amountText = money(record.amount)
            let destination = record.retrospectiveDestinationSummary(noteMaxLength: 40, localizedText: localizedText)
            store.upsertTask(
                dedupKey: dedupKey,
                title: title,
                message: messageTemplate(emotion, amountText, destination),
                action: .openRecordRetrospective,
                linkedRecordId: record.publicId,
                linkedRecordPersistentToken: linkToken,
                createdAt: record.createdAt.addingTimeInterval(AnalysisChartMetrics.retrospectiveMinAge)
            )
            if !already {
                slotsRemaining -= 1
            }
        }
    }

    /// Resolves the bill linked from a retrospective notification, if still present in the store.
    ///
    /// Uses a `publicId` fetch only. `modelContext.model(for: persistentID)` can return a
    /// tombstoned instance after delete; reading `emotionRaw` on it traps at runtime.
    static func linkedRecord(for item: AppNotificationItem, modelContext: ModelContext) -> TransactionRecord? {
        guard item.action == .openRecordRetrospective else { return nil }
        guard let uuid = item.linkedRecordId else { return nil }
        return fetchRecord(publicId: uuid, modelContext: modelContext)
    }

    private static func fetchRecord(publicId: UUID, modelContext: ModelContext) -> TransactionRecord? {
        let predicate = #Predicate<TransactionRecord> { $0.publicId == publicId && $0.deletedAt == nil }
        var descriptor = FetchDescriptor<TransactionRecord>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    /// Deletes a bill and clears its in-app retrospective notification, if any.
    @MainActor
    static func deleteRecord(
        _ record: TransactionRecord,
        modelContext: ModelContext,
        notificationStore: NotificationCenterStore
    ) {
        notificationStore.removeRetrospectiveTask(for: record)
        record.markDeleted()
        try? modelContext.save()
    }

    /// Rebuilds the persisted notification body using the **current** locale and strings (e.g. after language change).
    static func retrospectiveNotificationBody(
        record: TransactionRecord,
        locale: Locale,
        localizedText: (LKey) -> String,
        formatMoney: (Double) -> String
    ) -> String {
        let emotion: String = {
            if let preset = EmotionTag.from(raw: record.emotionRaw) {
                return localizedText(preset.key)
            }
            return record.safeEmotionName
        }()
        let amountText = formatMoney(record.amount)
        let destination = record.retrospectiveDestinationSummary(noteMaxLength: 40, localizedText: localizedText)
        return String(
            format: localizedText(.notificationRetrospectiveBody),
            locale: locale,
            arguments: [emotion, amountText, destination]
        )
    }
}
