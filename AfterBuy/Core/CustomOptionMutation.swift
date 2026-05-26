import Foundation
import SwiftData

enum CustomOptionMutationError: Equatable, Error {
    case duplicateName
    case notFound
}

enum CustomOptionMutation {
    static let categoryPrefix = "custom.category."
    static let emotionPrefix = "custom.emotion."

    static func categoryKey(forName name: String) -> String {
        categoryPrefix + name
    }

    static func emotionRaw(forName name: String) -> String {
        emotionPrefix + name
    }

    static func customCategorySuffix(fromKey key: String) -> String? {
        guard key.hasPrefix(categoryPrefix) else { return nil }
        return String(key.dropFirst(categoryPrefix.count))
    }

    static func customEmotionSuffix(fromRaw raw: String) -> String? {
        guard raw.hasPrefix(emotionPrefix) else { return nil }
        return String(raw.dropFirst(emotionPrefix.count))
    }

    /// Renames a custom category: updates `CustomOption.name` and all matching `TransactionRecord` keys/names.
    static func renameCustomCategory(
        oldName: String,
        newName: String,
        customOptions: [CustomOption],
        in context: ModelContext
    ) throws {
        let old = oldName.trimmingCharacters(in: .whitespacesAndNewlines)
        let new = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !old.isEmpty, !new.isEmpty else { throw CustomOptionMutationError.notFound }
        guard old != new else { return }
        if customOptions.contains(where: { $0.kind == .category && $0.name == new }) {
            throw CustomOptionMutationError.duplicateName
        }
        guard let option = customOptions.first(where: { $0.kind == .category && $0.name == old }) else {
            throw CustomOptionMutationError.notFound
        }
        let oldKey = categoryKey(forName: old)
        let newKey = categoryKey(forName: new)
        let descriptor = FetchDescriptor<TransactionRecord>(
            predicate: #Predicate<TransactionRecord> { $0.categoryKey == oldKey }
        )
        for record in try context.fetch(descriptor) {
            record.categoryKey = newKey
            record.categoryName = new
        }
        option.name = new
        option.updatedAt = Date()
        try context.save()
    }

    /// Renames a custom emotion and updates all matching records; optionally updates bucket on `CustomOption`.
    static func renameCustomEmotion(
        oldName: String,
        newName: String,
        bucket: EmotionBucket,
        customOptions: [CustomOption],
        in context: ModelContext
    ) throws {
        let old = oldName.trimmingCharacters(in: .whitespacesAndNewlines)
        let new = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !old.isEmpty, !new.isEmpty else { throw CustomOptionMutationError.notFound }
        guard let option = customOptions.first(where: { $0.kind == .emotion && $0.name == old }) else {
            throw CustomOptionMutationError.notFound
        }
        if old != new, customOptions.contains(where: { $0.kind == .emotion && $0.name == new }) {
            throw CustomOptionMutationError.duplicateName
        }
        let oldRaw = emotionRaw(forName: old)
        let newRaw = emotionRaw(forName: new)
        if old != new {
            let descriptor = FetchDescriptor<TransactionRecord>(
                predicate: #Predicate<TransactionRecord> { $0.emotionRaw == oldRaw }
            )
            for record in try context.fetch(descriptor) {
                record.emotionRaw = newRaw
                record.emotionName = new
            }
            option.name = new
        }
        option.emotionBucketRaw = bucket.rawValue
        let finalRaw = emotionRaw(forName: new)
        let syncDescriptor = FetchDescriptor<TransactionRecord>(
            predicate: #Predicate<TransactionRecord> { $0.emotionRaw == finalRaw }
        )
        let iconSnap = CustomIconCatalog.normalizedEmotionSymbol(option.iconSymbolRaw)
        for record in try context.fetch(syncDescriptor) {
            record.emotionBucketRaw = bucket.rawValue
            record.emotionIconSymbolRaw = iconSnap
        }
        option.updatedAt = Date()
        try context.save()
    }

    /// Removes the custom category from the picker. Existing `TransactionRecord` rows keep `categoryKey` / `categoryName` unchanged (orphan key snapshot).
    static func deleteCustomCategory(name: String, customOptions: [CustomOption], in context: ModelContext) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CustomOptionMutationError.notFound }
        guard let option = customOptions.first(where: { $0.kind == .category && $0.name == trimmed }) else {
            throw CustomOptionMutationError.notFound
        }
        let key = categoryKey(forName: trimmed)
        let iconSnap = CustomIconCatalog.normalizedCategorySymbol(option.iconSymbolRaw)
        let descriptor = FetchDescriptor<TransactionRecord>(
            predicate: #Predicate<TransactionRecord> { $0.categoryKey == key }
        )
        for record in try context.fetch(descriptor) {
            record.categoryIconSymbolRaw = iconSnap
        }
        option.markDeleted()
        try context.save()
    }

    /// Removes the custom mood from the picker. Existing records keep `emotionRaw` / `emotionName` / `emotionColorHex` unchanged.
    /// Before removing the option, copies the home-summary bucket onto every matching bill so hero totals stay correct (orphan `custom.emotion.*`).
    static func deleteCustomEmotion(name: String, customOptions: [CustomOption], in context: ModelContext) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CustomOptionMutationError.notFound }
        guard let option = customOptions.first(where: { $0.kind == .emotion && $0.name == trimmed }) else {
            throw CustomOptionMutationError.notFound
        }
        let raw = emotionRaw(forName: trimmed)
        let bucketSnap: String
        if let br = option.emotionBucketRaw, let b = EmotionBucket(rawValue: br) {
            bucketSnap = b.rawValue
        } else {
            bucketSnap = EmotionBucket.emotional.rawValue
        }
        let iconSnap = CustomIconCatalog.normalizedEmotionSymbol(option.iconSymbolRaw)
        let descriptor = FetchDescriptor<TransactionRecord>(
            predicate: #Predicate<TransactionRecord> { $0.emotionRaw == raw }
        )
        for record in try context.fetch(descriptor) {
            record.emotionBucketRaw = bucketSnap
            record.emotionIconSymbolRaw = iconSnap
        }
        option.markDeleted()
        try context.save()
    }
}
