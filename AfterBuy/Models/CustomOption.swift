import Foundation
import SwiftData

enum CustomOptionKind: String, Codable, CaseIterable {
    case category
    case emotion
}

@Model
final class CustomOption {
    var publicId: UUID = UUID()
    var kindRaw: String = CustomOptionKind.category.rawValue
    var name: String = ""
    var colorHex: String?
    /// When `kind` is `.emotion`, maps to `EmotionBucket.rawValue` for home / analytics bucketing. Nil = legacy (treat as `.emotional`).
    var emotionBucketRaw: String?
    /// SF Symbol name from `CustomIconCatalog` for this row (both `.category` and `.emotion`).
    var iconSymbolRaw: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deletedAt: Date? = nil

    init(
        kind: CustomOptionKind,
        name: String,
        colorHex: String? = nil,
        emotionBucketRaw: String? = nil,
        iconSymbolRaw: String = "",
        createdAt: Date = Date(),
        publicId: UUID = UUID()
    ) {
        self.publicId = publicId
        self.kindRaw = kind.rawValue
        self.name = name
        self.colorHex = colorHex
        self.emotionBucketRaw = kind == .emotion ? emotionBucketRaw : nil
        switch kind {
        case .category:
            self.iconSymbolRaw = CustomIconCatalog.normalizedCategorySymbol(iconSymbolRaw)
        case .emotion:
            self.iconSymbolRaw = CustomIconCatalog.normalizedEmotionSymbol(iconSymbolRaw)
        }
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    var isDeleted: Bool {
        deletedAt != nil
    }

    var kind: CustomOptionKind {
        get { CustomOptionKind(rawValue: kindRaw) ?? .category }
        set { kindRaw = newValue.rawValue }
    }
}
