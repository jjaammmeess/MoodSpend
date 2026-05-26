import Foundation
import SwiftData
import SwiftUI

@Model
final class TransactionRecord {
    var amount: Double = 0
    var typeRaw: String = RecordType.expense.rawValue
    var categoryKey: String = LKey.categoryOther.rawValue
    var categoryName: String = ""
    var emotionRaw: String = EmotionTag.necessity.rawValue
    var emotionName: String = ""
    var emotionColorHex: String = EmotionTag.necessity.colorHex
    /// For `custom.emotion.*` moods: snapshot of `EmotionBucket.rawValue` at save time so totals stay correct after the `CustomOption` is removed.
    var emotionBucketRaw: String?
    /// For `custom.category.*`: SF Symbol snapshot for badges after the `CustomOption` is removed.
    var categoryIconSymbolRaw: String?
    /// For `custom.emotion.*`: SF Symbol snapshot for grids after the `CustomOption` is removed.
    var emotionIconSymbolRaw: String?
    var note: String = ""
    /// Legacy single attachment; migrated into `attachments` (M0). Do not write new data here.
    var imageData: Data?
    /// Legacy multi-attachment blobs; migrated into `attachments` (M0).
    var imageAttachmentDatas: [Data] = []
    @Relationship(deleteRule: .cascade, inverse: \RecordAttachment.record)
    var attachments: [RecordAttachment]? = nil
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deletedAt: Date? = nil
    var lastModifiedDeviceId: String = ""
    /// Stable id for notifications / deep links (SwiftData `persistentModelID` is awkward to persist).
    var publicId: UUID = UUID()
    /// `RetrospectiveWorth.rawValue` when user completes a post-purchase review.
    var retrospectiveWorthRaw: String?

    init(
        amount: Double,
        type: RecordType,
        categoryKey: String,
        categoryName: String,
        emotionRaw: String,
        emotionName: String,
        emotionColorHex: String,
        emotionBucketRaw: String? = nil,
        categoryIconSymbolRaw: String? = nil,
        emotionIconSymbolRaw: String? = nil,
        note: String,
        imageData: Data? = nil,
        imageAttachmentDatas: [Data] = [],
        createdAt: Date = Date(),
        publicId: UUID = UUID(),
        retrospectiveWorthRaw: String? = nil
    ) {
        self.amount = amount
        self.typeRaw = type.rawValue
        self.categoryKey = categoryKey
        self.categoryName = categoryName
        self.emotionRaw = emotionRaw
        self.emotionName = emotionName
        self.emotionColorHex = emotionColorHex
        self.emotionBucketRaw = emotionBucketRaw
        self.categoryIconSymbolRaw = categoryIconSymbolRaw
        self.emotionIconSymbolRaw = emotionIconSymbolRaw
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.publicId = publicId
        self.retrospectiveWorthRaw = retrospectiveWorthRaw
        self.lastModifiedDeviceId = DeviceIdentity.shortID

        let capped = Array(imageAttachmentDatas.prefix(Self.maxImageAttachmentCount))
        if capped.isEmpty, let imageData, !imageData.isEmpty {
            applyImageAttachments([imageData])
        } else if !capped.isEmpty {
            applyImageAttachments(capped)
        } else {
            self.imageAttachmentDatas = []
            self.imageData = nil
            self.attachments = nil
        }
    }

    var isDeleted: Bool {
        deletedAt != nil
    }

    var retrospectiveWorth: RetrospectiveWorth? {
        get {
            guard let raw = retrospectiveWorthRaw else { return nil }
            return RetrospectiveWorth(rawValue: raw)
        }
        set {
            retrospectiveWorthRaw = newValue?.rawValue
        }
    }

    var type: RecordType {
        get { RecordType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var emotion: EmotionTag {
        get { EmotionTag(rawValue: emotionRaw) ?? .necessity }
        set {
            emotionRaw = newValue.rawValue
            emotionName = newValue.rawValue
            emotionColorHex = newValue.colorHex
            emotionBucketRaw = nil
            emotionIconSymbolRaw = nil
        }
    }

    /// UI swatch: preset moods always use the current preset color; custom moods use the stored snapshot.
    var displayEmotionColorHex: String {
        if let preset = EmotionTag.from(raw: emotionRaw) {
            return preset.colorHex
        }
        let hex = emotionColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        return hex.isEmpty ? EmotionTag.necessity.colorHex : hex
    }

    var emotionColor: Color {
        Color(hex: displayEmotionColorHex)
    }

    var safeCategoryName: String {
        categoryName.isEmpty ? categoryKey : categoryName
    }

    var safeEmotionName: String {
        if !emotionName.isEmpty { return emotionName }
        if let preset = EmotionTag.from(raw: emotionRaw) { return preset.rawValue }
        return emotionRaw
    }
}
