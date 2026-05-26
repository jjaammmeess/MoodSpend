import UIKit

enum DeviceIdentity {
    static var shortID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
    }
}
