import Foundation
import StoreKit
import UIKit

/// Coordinates in-app App Store review prompts with frequency and mood guards.
@MainActor
final class AppReviewManager {
    static let shared = AppReviewManager()

    private enum StorageKey {
        static let totalTransactionCount = "appReview.totalTransactionCount"
        static let lastReviewRequestedDate = "appReview.lastReviewRequestedDate"
        static let reviewRequestedCountInYear = "appReview.reviewRequestedCountInYear"
        static let reviewQuotaYear = "appReview.reviewQuotaYear"
    }

    /// Milestone saves that may trigger a review (also requires `minimumTransactionCount`).
    static let reviewMilestones: Set<Int> = [7, 21, 50, 100]

    private static let minimumTransactionCount = 7
    private static let cooldownInterval: TimeInterval = 30 * 24 * 60 * 60
    private static let maxPromptsPerCalendarYear = 3
    /// Block when distress (impulse + stress + emotional bucket) expense share is at or above this ratio.
    private static let distressShareBlockThreshold = 0.5

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        refreshYearlyQuotaIfNeeded()
    }

    // MARK: - Public API

    /// Aligns stored count with persisted expenses (no review). Call after SwiftData is ready.
    func reconcileTransactionCount(with persistedExpenseCount: Int) {
        refreshYearlyQuotaIfNeeded()
        let stored = defaults.integer(forKey: StorageKey.totalTransactionCount)
        if persistedExpenseCount > stored {
            defaults.set(persistedExpenseCount, forKey: StorageKey.totalTransactionCount)
        }
    }

    /// Call after a **new** expense record is saved successfully. No emotion guard on this path.
    func recordNewTransactionSaved() {
        refreshYearlyQuotaIfNeeded()

        let newCount = defaults.integer(forKey: StorageKey.totalTransactionCount) + 1
        defaults.set(newCount, forKey: StorageKey.totalTransactionCount)

        guard newCount >= Self.minimumTransactionCount else { return }
        guard Self.reviewMilestones.contains(newCount) else { return }

        requestReviewIfNeeded(applyEmotionGuard: false)
    }

    /// Call after Pro custom-range emotion dashboard has applied and the view has refreshed.
    func considerReviewAfterCustomEmotionDashboard(distressShareOfTotal: Double) {
        refreshYearlyQuotaIfNeeded()
        requestReviewIfNeeded(
            applyEmotionGuard: true,
            distressShareOfTotal: distressShareOfTotal
        )
    }

    // MARK: - Review request

    private func requestReviewIfNeeded(
        applyEmotionGuard: Bool,
        distressShareOfTotal: Double = 0
    ) {
        let now = Date().timeIntervalSince1970
        let lastRequested = defaults.double(forKey: StorageKey.lastReviewRequestedDate)

        guard now - lastRequested > Self.cooldownInterval else { return }
        guard defaults.integer(forKey: StorageKey.reviewRequestedCountInYear) < Self.maxPromptsPerCalendarYear else { return }
        guard defaults.integer(forKey: StorageKey.totalTransactionCount) >= Self.minimumTransactionCount else { return }

        if applyEmotionGuard {
            guard distressShareOfTotal < Self.distressShareBlockThreshold else { return }
        }

        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }

        AppStore.requestReview(in: scene)

        defaults.set(now, forKey: StorageKey.lastReviewRequestedDate)
        let count = defaults.integer(forKey: StorageKey.reviewRequestedCountInYear) + 1
        defaults.set(count, forKey: StorageKey.reviewRequestedCountInYear)
    }

    private func refreshYearlyQuotaIfNeeded() {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let storedYear = defaults.integer(forKey: StorageKey.reviewQuotaYear)

        if storedYear == 0 {
            defaults.set(currentYear, forKey: StorageKey.reviewQuotaYear)
            return
        }

        if storedYear != currentYear {
            defaults.set(currentYear, forKey: StorageKey.reviewQuotaYear)
            defaults.set(0, forKey: StorageKey.reviewRequestedCountInYear)
        }
    }
}
