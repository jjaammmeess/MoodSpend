import Foundation
import SwiftData

@Model
final class RecordAttachment {
    var attachmentId: UUID = UUID()
    var recordPublicId: UUID = UUID()
    var sortOrder: Int = 0
    @Attribute(.externalStorage) var imageData: Data = Data()
    var createdAt: Date = Date()
    var record: TransactionRecord?

    init(
        attachmentId: UUID = UUID(),
        recordPublicId: UUID,
        sortOrder: Int,
        imageData: Data,
        createdAt: Date = Date(),
        record: TransactionRecord? = nil
    ) {
        self.attachmentId = attachmentId
        self.recordPublicId = recordPublicId
        self.sortOrder = sortOrder
        self.imageData = imageData
        self.createdAt = createdAt
        self.record = record
    }
}
