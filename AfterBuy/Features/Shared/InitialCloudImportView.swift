import SwiftUI

struct InitialCloudImportView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var appSyncState: AppSyncState

    var onSkip: () -> Void

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView()
                    .controlSize(.large)
                Text(localization.text(.syncInitialImportTitle))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(localization.text(.syncInitialImportMessage))
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                if let error = appSyncState.lastErrorMessage, !error.isEmpty {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.accentRisk)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button(action: onSkip) {
                    Text(localization.text(.syncInitialImportSkip))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.actionBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }
        }
    }
}
