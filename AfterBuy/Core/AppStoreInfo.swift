import Foundation

/// App Store listing for WhySpend / 花钱了 (App Store Connect Apple ID).
enum AppStoreInfo {
    static let appleID = "6771243456"

    static var appStoreURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appleID)")!
    }

    /// Opens the App Store review composer for this app.
    static var writeReviewURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appleID)?action=write-review")!
    }
}
