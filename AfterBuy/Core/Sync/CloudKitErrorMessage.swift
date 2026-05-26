import CloudKit
import Foundation

enum CloudKitErrorMessage {
    static func userFacing(_ error: Error?) -> String {
        guard let error else {
            return localized("mine.cloudSync.error.generic", fallback: "iCloud 同步失败，请稍后重试。")
        }

        if let ckError = error as? CKError {
            if ckError.code == .partialFailure, let partialErrors = ckError.partialErrorsByItemID {
                for partial in partialErrors.values {
                    let message = userFacing(partial)
                    if !message.isEmpty {
                        return message
                    }
                }
            }

            switch ckError.code {
            case .serverRejectedRequest:
                return localized(
                    "mine.cloudSync.error.serverRejected",
                    fallback: "CloudKit 无法初始化同步区域。请删除 App 后重装；若仍失败，请在 CloudKit 控制台重置 Development 环境。"
                )
            case .partialFailure:
                return localized(
                    "mine.cloudSync.error.partialFailure",
                    fallback: "iCloud 同步部分失败，请检查网络后重试。"
                )
            case .notAuthenticated, .permissionFailure:
                return localized(
                    "mine.cloudSync.error.notAuthenticated",
                    fallback: "请在本机登录 iCloud 并允许「花钱了」使用 iCloud。"
                )
            case .networkUnavailable, .networkFailure:
                return localized(
                    "mine.cloudSync.error.network",
                    fallback: "网络不可用，暂时无法同步。"
                )
            case .quotaExceeded:
                return localized(
                    "mine.cloudSync.error.quota",
                    fallback: "iCloud 存储空间不足，无法同步。"
                )
            default:
                break
            }
        }

        return error.localizedDescription
    }

    private static func localized(_ key: String, fallback: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: .main, value: fallback, comment: "")
    }
}
