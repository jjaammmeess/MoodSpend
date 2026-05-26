import SwiftUI

struct HomeHeroBucketDetailSession: Identifiable {
    let bucket: EmotionBucket
    var id: String { bucket.rawValue }
}

struct HomeHeroBucketDetailSheet: View {
    let bucket: EmotionBucket
    let monthExpenses: [TransactionRecord]
    let monthTotalExpense: Double
    let customEmotions: [CustomOption]

    @EnvironmentObject private var localization: LocalizationManager

    private var bucketRecords: [TransactionRecord] {
        monthExpenses
            .filter { EmotionGrouping.bucket(for: $0, customEmotions: customEmotions) == bucket }
    }

    private var navigationTitle: String {
        let bucketName = localization.text(bucketTitleKey)
        return String(
            format: localization.text(.homeHeroBucketDetailTitle),
            locale: localization.locale,
            arguments: [bucketName]
        )
    }

    private var bucketTitleKey: LKey {
        switch bucket {
        case .effective: return .homeEffectiveSpend
        case .emotional: return .homeEmotionalSpend
        case .necessary: return .homeNecessarySpend
        }
    }

    private var scopeNoteKey: LKey {
        switch bucket {
        case .effective: return .homeHeroBucketDetailScopeNoteEffective
        case .emotional: return .homeHeroBucketDetailScopeNoteEmotional
        case .necessary: return .homeHeroBucketDetailScopeNoteNecessary
        }
    }

    var body: some View {
        EmotionExpenseDetailSheet(
            navigationTitle: navigationTitle,
            records: bucketRecords,
            periodTotalExpense: monthTotalExpense,
            emptyStateTitle: localization.text(.homeHeroBucketDetailEmpty),
            shareOfPeriodFormatKey: .homeHeroBucketDetailShareOfMonth,
            scopeNote: localization.text(scopeNoteKey),
            footerNote: nil,
            presentation: .homeBucket(bucket)
        )
    }
}
