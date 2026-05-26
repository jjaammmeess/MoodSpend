import SwiftUI
import UIKit

struct CloudSyncSettingsSection: View {
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var appSettings: AppSettings
    @EnvironmentObject private var appSyncState: AppSyncState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var pendingSyncEnabled: Bool?
    @State private var showSyncConfirm = false
    @State private var showRestartRequired = false
    @State private var showSignInRequired = false
    @State private var manualSyncIconRotation: Double = 0

    private let cloudSyncService: CloudSyncServicing = CloudSyncService()

    private var statusKind: CloudSyncStatusKind {
        CloudSyncStatusPresentation.statusKind(
            appSyncState: appSyncState,
            userSyncEnabled: appSettings.iCloudSyncEnabled,
            syncActive: cloudSyncService.isEnabled
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MineSettingsGroupHeader(title: localization.text(.mineCloudSync))

            MineSettingsCard {
                MineSettingsToggleRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: localization.text(.mineAutoSync),
                    isOn: syncToggleBinding
                )

                if appSettings.iCloudSyncEnabled {
                    MineSettingsDivider()
                    lastSyncRow

                    if let error = appSyncState.lastErrorMessage, !error.isEmpty {
                        syncErrorHint(message: error)
                    }
                }
            }
        }
        .task(id: scenePhase) {
            await CloudKitAccountProbe.refreshStatus(into: appSyncState)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            appSyncState.refreshICloudAvailability()
            Task {
                await CloudKitAccountProbe.refreshStatus(into: appSyncState)
            }
        }
        .confirmationDialog(
            localization.text(syncConfirmTitleKey),
            isPresented: $showSyncConfirm,
            titleVisibility: .visible
        ) {
            Button(localization.text(.mineCloudSyncConfirmApply), role: .none) {
                applyPendingSyncPreference()
            }
            Button(localization.text(.commonCancel), role: .cancel) {
                pendingSyncEnabled = nil
            }
        } message: {
            Text(localization.text(syncConfirmMessageKey))
        }
        .alert(
            localization.text(.mineCloudSyncRestartTitle),
            isPresented: $showRestartRequired
        ) {
            Button(localization.text(.mineCloudSyncDismissError)) {
                pendingSyncEnabled = nil
            }
        } message: {
            Text(localization.text(.mineCloudSyncRestartMessage))
        }
        .alert(
            localization.text(.mineCloudSyncSignInTitle),
            isPresented: $showSignInRequired
        ) {
            Button(localization.text(.mineCloudSyncOpenSettings)) {
                openSystemSettings()
            }
            Button(localization.text(.commonCancel), role: .cancel) {}
        } message: {
            Text(localization.text(.mineCloudSyncSignInMessage))
        }
    }

    private var syncToggleBinding: Binding<Bool> {
        Binding(
            get: { appSettings.iCloudSyncEnabled },
            set: { newValue in
                guard newValue != appSettings.iCloudSyncEnabled else { return }
                if newValue, !appSyncState.isICloudAvailable {
                    showSignInRequired = true
                    return
                }
                pendingSyncEnabled = newValue
                showSyncConfirm = true
            }
        )
    }

    private var syncConfirmTitleKey: LKey {
        pendingSyncEnabled == true ? .mineCloudSyncEnableConfirmTitle : .mineCloudSyncDisableConfirmTitle
    }

    private var syncConfirmMessageKey: LKey {
        pendingSyncEnabled == true ? .mineCloudSyncEnableConfirmMessage : .mineCloudSyncDisableConfirmMessage
    }

    private func applyPendingSyncPreference() {
        guard let enabled = pendingSyncEnabled else { return }
        appSettings.applyICloudSyncPreference(enabled)
        showRestartRequired = true
    }

    // MARK: - Last sync (status + manual refresh)

    private var lastSyncRow: some View {
        HStack(alignment: .center, spacing: 12) {
            lastSyncStatusIcon
            Text(
                CloudSyncStatusPresentation.lastSyncText(
                    lastImportFinishedAt: appSyncState.lastImportFinishedAt,
                    localization: localization
                )
            )
            .font(.system(size: 15))
            .foregroundStyle(AppTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 50)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            handleLastSyncTap()
        }
    }

    private var lastSyncStatusIcon: some View {
        Image(systemName: lastSyncIconSymbol)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(lastSyncIconForeground)
            .frame(width: AppTheme.mineIconWellSize, height: AppTheme.mineIconWellSize)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.mineIconWellCornerRadius, style: .continuous)
                    .fill(lastSyncIconWellFill)
            )
            .rotationEffect(.degrees(manualSyncIconRotation))
    }

    private var lastSyncIconSymbol: String {
        switch statusKind {
        case .active:
            return "clock"
        case .syncing:
            return "clock"
        case .error, .unavailable:
            return "exclamationmark.triangle"
        case .userDisabled:
            return "clock"
        }
    }

    private var lastSyncIconForeground: Color {
        switch statusKind {
        case .active:
            return Color.green.opacity(0.8)
        case .syncing:
            return Color.green.opacity(0.65)
        case .error:
            return AppTheme.accentWarning.opacity(0.72)
        case .unavailable:
            return AppTheme.textSecondary.opacity(0.72)
        case .userDisabled:
            return AppTheme.textSecondary
        }
    }

    private var lastSyncIconWellFill: Color {
        switch statusKind {
        case .active, .syncing:
            return Color.green.opacity(0.12)
        case .error:
            return AppTheme.accentWarning.opacity(0.12)
        case .unavailable, .userDisabled:
            return AppTheme.textSecondary.opacity(0.1)
        }
    }

    private func handleLastSyncTap() {
        guard appSettings.iCloudSyncEnabled else { return }

        if !appSyncState.isICloudAvailable || appSyncState.accountStatusHint == .noAccount {
            openSystemSettings()
            return
        }

        withAnimation(.easeInOut(duration: 0.65)) {
            manualSyncIconRotation += 360
        }

        Task {
            await CloudSyncManualRefresh.trigger(appSyncState: appSyncState)
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    private func syncErrorHint(message: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(message)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(localization.text(.mineCloudSyncDismissError)) {
                withAnimation(.easeOut(duration: 0.2)) {
                    appSyncState.clearLastError()
                }
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(AppTheme.textSecondary.opacity(0.9))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .transition(.opacity)
    }
}
