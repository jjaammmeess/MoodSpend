import Combine
import SwiftUI

enum AppRootTab: String {
    case home
    case bills
    case analysis
    case mine
}

final class RootTabCoordinator: ObservableObject {
    @Published var selected: AppRootTab = .home
    @Published var showQuickRecordSheet = false
    @Published var showNotificationCenter = false
    @Published var pendingHandledNotification: AppNotificationItem?

    /// Presents the global quick-record sheet (Tab “+” and notification CTA share this).
    func presentQuickRecord(afterDelayMs: UInt64 = 0) {
        Task { @MainActor in
            if afterDelayMs > 0 {
                try? await Task.sleep(for: .milliseconds(afterDelayMs))
            }
            showQuickRecordSheet = true
        }
    }

    /// Switches the root tab; optional delay for chaining after a sheet dismiss animation.
    func selectTab(_ tab: AppRootTab, afterDelayMs: UInt64 = 0, contentAnimation: Bool = true) {
        let apply = { [weak self] in
            guard let self else { return }
            if contentAnimation {
                self.selected = tab
            } else {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    self.selected = tab
                }
            }
        }

        guard afterDelayMs > 0 else {
            apply()
            return
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(afterDelayMs))
            apply()
        }
    }
}
