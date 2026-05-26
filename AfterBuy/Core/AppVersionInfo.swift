import Foundation

enum AppVersionInfo {
    static let supportEmail = "octboyu@gmail.com"

    /// Display format: `1.1.3(14)` from Info.plist (`CFBundleShortVersionString` + `CFBundleVersion`).
    static var displayString: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let version = (short?.isEmpty == false) ? short! : "1.1.3"
        let buildNumber = (build?.isEmpty == false) ? build! : "14"
        return "\(version)(\(buildNumber))"
    }

    static var mailtoURL: URL? {
        URL(string: "mailto:\(supportEmail)")
    }
}
