import Foundation

/// Why the paywall was presented — drives contextual headline and benefit bullets (Plan A).
enum PaywallSource: Equatable {
    case general
    case monthHistory
    case yearView
    case customRange
    case recordAttachments
    case billTopExpense
    case emotionTrend60Day
}

extension PaywallSource {
    var headlineKey: LKey {
        switch self {
        case .general: return .paywallHeadlineGeneral
        case .monthHistory: return .paywallHeadlineMonthHistory
        case .yearView: return .paywallHeadlineYearView
        case .customRange: return .paywallHeadlineCustomRange
        case .recordAttachments: return .paywallHeadlineRecordAttachments
        case .billTopExpense: return .paywallHeadlineBillTopExpense
        case .emotionTrend60Day: return .paywallHeadlineEmotionTrend60Day
        }
    }

    var subtitleKey: LKey? {
        switch self {
        case .general: return .paywallSubtitleGeneral
        case .monthHistory: return .paywallSubtitleMonthHistory
        case .yearView: return .paywallSubtitleYearView
        case .customRange: return .paywallSubtitleCustomRange
        case .recordAttachments: return .paywallSubtitleRecordAttachments
        case .billTopExpense: return .paywallSubtitleBillTopExpense
        case .emotionTrend60Day: return .paywallSubtitleEmotionTrend60Day
        }
    }

    /// Up to four Pro bullets; leading items match the trigger context.
    var proBulletKeys: [LKey] {
        switch self {
        case .monthHistory, .yearView, .customRange, .emotionTrend60Day:
            return [.paywallBulletTimeline, .paywallBulletNotesPhotos, .paywallBulletReport, .paywallBulletBillTop]
        case .recordAttachments:
            return [.paywallBulletNotesPhotos, .paywallBulletTimeline, .paywallBulletReport, .paywallBulletBillTop]
        case .billTopExpense:
            return [.paywallBulletBillTop, .paywallBulletTimeline, .paywallBulletNotesPhotos, .paywallBulletReport]
        case .general:
            return [.paywallBulletTimeline, .paywallBulletNotesPhotos, .paywallBulletReport, .paywallBulletBillTop]
        }
    }
}
