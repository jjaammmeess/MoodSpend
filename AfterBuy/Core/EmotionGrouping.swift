import Foundation
import SwiftData

/// Buckets used on the home hero (有效快乐 / 情绪性消费 / 刚需必要) and related analytics.
enum EmotionBucket: String, CaseIterable, Sendable {
    case effective
    case emotional
    case necessary
}

enum EmotionGrouping {
    /// Stored on `TransactionRecord.emotionRaw` for user-defined moods.
    static let customEmotionIdPrefix = "custom.emotion."

    static func bucket(for record: TransactionRecord, customEmotions: [CustomOption]) -> EmotionBucket {
        let emotionRaw = record.emotionRaw
        if let emotion = EmotionTag.from(raw: emotionRaw) {
            switch emotion {
            case .pamper, .ritual:
                return .effective
            case .necessity:
                return .necessary
            case .impulse, .stress, .social:
                return .emotional
            }
        }
        guard emotionRaw.hasPrefix(Self.customEmotionIdPrefix) else {
            return .emotional
        }
        if let snap = record.emotionBucketRaw, let b = EmotionBucket(rawValue: snap) {
            return b
        }
        let name = String(emotionRaw.dropFirst(Self.customEmotionIdPrefix.count))
        guard let opt = customEmotions.first(where: { $0.kind == .emotion && $0.name == name }) else {
            return .emotional
        }
        guard let raw = opt.emotionBucketRaw, let b = EmotionBucket(rawValue: raw) else {
            return .emotional
        }
        return b
    }

    static func isEffective(_ record: TransactionRecord, customEmotions: [CustomOption]) -> Bool {
        bucket(for: record, customEmotions: customEmotions) == .effective
    }

    static func isEmotional(_ record: TransactionRecord, customEmotions: [CustomOption]) -> Bool {
        bucket(for: record, customEmotions: customEmotions) == .emotional
    }

    static func isNecessary(_ record: TransactionRecord, customEmotions: [CustomOption]) -> Bool {
        bucket(for: record, customEmotions: customEmotions) == .necessary
    }
}

/// Fills `emotionBucketRaw` and `emotionIconSymbolRaw` on bills that still use a `custom.emotion.*` id when a matching `CustomOption` exists (e.g. user recreated a deleted tag, or first launch after upgrade).
enum EmotionBucketSnapshotSync {
    @MainActor
    static func syncNilSnapshotsFromMatchingOptions(modelContext: ModelContext) {
        guard let records = try? modelContext.fetch(FetchDescriptor<TransactionRecord>()) else { return }
        guard let options = try? modelContext.fetch(FetchDescriptor<CustomOption>()) else { return }
        let emotionOptions = options.filter { $0.kind == .emotion }
        var didMutate = false
        for record in records {
            guard record.emotionRaw.hasPrefix(EmotionGrouping.customEmotionIdPrefix) else { continue }
            let name = String(record.emotionRaw.dropFirst(EmotionGrouping.customEmotionIdPrefix.count))
            guard let opt = emotionOptions.first(where: { $0.name == name }) else { continue }
            var touched = false
            if record.emotionBucketRaw == nil {
                if let raw = opt.emotionBucketRaw, EmotionBucket(rawValue: raw) != nil {
                    record.emotionBucketRaw = raw
                } else {
                    record.emotionBucketRaw = EmotionBucket.emotional.rawValue
                }
                touched = true
            }
            if record.emotionIconSymbolRaw == nil {
                record.emotionIconSymbolRaw = CustomIconCatalog.normalizedEmotionSymbol(opt.iconSymbolRaw)
                touched = true
            }
            if touched {
                didMutate = true
            }
        }
        if didMutate {
            try? modelContext.save()
        }
    }
}
