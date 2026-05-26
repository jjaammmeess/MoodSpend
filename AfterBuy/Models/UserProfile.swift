import Foundation
import SwiftData

@Model
final class UserProfile {
    var singletonId: UUID = PersistenceConfiguration.profileSingletonId
    var displayName: String = AppBranding.nameZhHans
    @Attribute(.externalStorage) var avatarImageData: Data?
    var avatarPresetID: String?
    var updatedAt: Date = Date()

    init(
        singletonId: UUID = PersistenceConfiguration.profileSingletonId,
        displayName: String = AppBranding.nameZhHans,
        avatarImageData: Data? = nil,
        avatarPresetID: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.singletonId = singletonId
        self.displayName = displayName
        self.avatarImageData = avatarImageData
        self.avatarPresetID = avatarPresetID
        self.updatedAt = updatedAt
    }
}
