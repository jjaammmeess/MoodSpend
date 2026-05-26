import Foundation

enum ICloudAvailability {
    /// `nil` when the user is not signed into iCloud on this device.
    static var ubiquityIdentityToken: (any NSCopying & NSObjectProtocol)? {
        FileManager.default.ubiquityIdentityToken
    }

    static var isSignedIn: Bool {
        ubiquityIdentityToken != nil
    }
}
