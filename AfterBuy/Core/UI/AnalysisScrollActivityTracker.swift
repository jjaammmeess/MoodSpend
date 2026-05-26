import Combine
import Foundation

/// Tracks whether the analysis tab scroll view is actively moving (drag or deceleration).
@MainActor
final class AnalysisScrollActivityTracker: ObservableObject {
    private(set) var isScrolling = false

    private var idleTask: Task<Void, Never>?

    /// Marks scroll activity; clears `isScrolling` after a short idle window.
    func noteScrollActivity(idleMilliseconds: UInt64 = 180) {
        isScrolling = true
        idleTask?.cancel()
        idleTask = Task {
            try? await Task.sleep(for: .milliseconds(idleMilliseconds))
            guard !Task.isCancelled else { return }
            isScrolling = false
        }
    }

    /// Waits until scrolling stops, or until `maxWait` elapses.
    func waitUntilIdle(maxWaitMilliseconds: UInt64 = 3_000) async {
        if !isScrolling { return }

        let deadline = ContinuousClock.now + .milliseconds(maxWaitMilliseconds)
        while isScrolling, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }
}
