import Foundation

/// Free vs Pro limits for optional note and photo attachments on a transaction.
enum RecordAttachmentLimits {
    static let freeNoteMaxLength = 50
    static let proNoteMaxLength = 200
    static let freePhotoMaxCount = 1

    static var proPhotoMaxCount: Int { TransactionRecord.maxImageAttachmentCount }

    static func noteLengthCeiling(isPro: Bool, existingNoteLength: Int) -> Int {
        if isPro { return proNoteMaxLength }
        return max(freeNoteMaxLength, existingNoteLength)
    }

    static func photoCountCeiling(isPro: Bool, existingPhotoCount: Int) -> Int {
        if isPro { return proPhotoMaxCount }
        return max(freePhotoMaxCount, existingPhotoCount)
    }
}
