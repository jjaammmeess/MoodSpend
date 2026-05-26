import SwiftUI

struct CloudSyncStatusIndicator: View {
    @EnvironmentObject private var appSyncState: AppSyncState

    var body: some View {
        if appSyncState.isSyncing {
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel(Text("Syncing"))
                .transition(.opacity)
        }
    }
}
