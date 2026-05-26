import Foundation

extension TransactionRecord {
    static let maxImageAttachmentCount = 9

    /// Legacy inline blobs (pre–`RecordAttachment` migration).
    var legacyImageAttachmentDatas: [Data] {
        if !imageAttachmentDatas.isEmpty {
            return imageAttachmentDatas
        }
        if let imageData, !imageData.isEmpty {
            return [imageData]
        }
        return []
    }

    /// All image blobs for this record (`RecordAttachment` first, then legacy fields).
    var resolvedImageAttachments: [Data] {
        if let attachments = attachments, !attachments.isEmpty {
            return attachments
                .sorted { $0.sortOrder < $1.sortOrder }
                .map(\.imageData)
                .filter { !$0.isEmpty }
        }
        return legacyImageAttachmentDatas
    }

    var hasImageAttachments: Bool {
        !resolvedImageAttachments.isEmpty
    }

    func applyImageAttachments(_ datas: [Data]) {
        let capped = Array(datas.prefix(Self.maxImageAttachmentCount))
        if let existing = attachments {
            for attachment in existing {
                attachment.record = nil
            }
        }
        if capped.isEmpty {
            attachments = nil
            imageAttachmentDatas = []
            imageData = nil
            return
        }

        attachments = capped.enumerated().map { index, data in
            RecordAttachment(
                recordPublicId: publicId,
                sortOrder: index,
                imageData: data,
                record: self
            )
        }
        imageAttachmentDatas = []
        imageData = nil
        touchUpdatedAt()
    }

    func touchUpdatedAt() {
        updatedAt = Date()
        lastModifiedDeviceId = DeviceIdentity.shortID
    }
}
