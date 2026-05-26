import Foundation
import SwiftUI

enum CloudSyncStatusKind {
    case userDisabled
    case unavailable
    case syncing
    case error
    case active
}

enum CloudSyncStatusPresentation {
    @MainActor
    static func statusKind(
        appSyncState: AppSyncState,
        userSyncEnabled: Bool,
        syncActive: Bool
    ) -> CloudSyncStatusKind {
        guard userSyncEnabled else { return .userDisabled }
        guard syncActive else {
            if appSyncState.lastErrorMessage != nil { return .error }
            return .unavailable
        }
        if appSyncState.lastErrorMessage != nil { return .error }
        if appSyncState.isSyncing { return .syncing }
        return .active
    }

    @MainActor
    static func statusTitle(
        kind: CloudSyncStatusKind,
        localization: LocalizationManager
    ) -> String {
        switch kind {
        case .userDisabled:
            return localization.text(.mineCloudSyncUserDisabled)
        case .unavailable:
            return localization.text(.mineCloudSyncUnavailable)
        case .syncing:
            return localization.text(.mineCloudSyncSyncing)
        case .error:
            return localization.text(.mineCloudSyncErrorTitle)
        case .active:
            return localization.text(.mineCloudSyncActive)
        }
    }

    static func statusColor(kind: CloudSyncStatusKind) -> Color {
        switch kind {
        case .userDisabled, .unavailable:
            return AppTheme.textSecondary
        case .syncing:
            return AppTheme.actionBlue
        case .error:
            return AppTheme.accentRisk
        case .active:
            return Color(hex: "2E7D32")
        }
    }

    @MainActor
    static func accountHintText(
        hint: AppSyncState.AccountStatusHint?,
        localization: LocalizationManager
    ) -> String? {
        guard let hint else { return nil }
        switch hint {
        case .noAccount:
            return localization.text(.mineCloudSyncAccountNoAccount)
        case .restricted:
            return localization.text(.mineCloudSyncAccountRestricted)
        case .temporarilyUnavailable:
            return localization.text(.mineCloudSyncAccountTemporarilyUnavailable)
        case .couldNotDetermine:
            return localization.text(.mineCloudSyncAccountUnknown)
        }
    }

    @MainActor
    static func lastSyncText(
        lastImportFinishedAt: Date?,
        localization: LocalizationManager
    ) -> String {
        guard let lastImportFinishedAt else {
            return localization.text(.mineCloudSyncLastSyncNever)
        }
        let formatted = AppFormatter.dayTimeString(from: lastImportFinishedAt, locale: localization.locale)
        return String(
            format: localization.text(.mineCloudSyncLastSyncFormat),
            locale: localization.locale,
            arguments: [formatted]
        )
    }

}
