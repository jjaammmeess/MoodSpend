import Foundation
import SwiftUI

struct EmotionAlertResult {
    let title: String
    let message: String
    let color: Color
}

struct EmotionAlertCandidate {
    let emotionRaw: String
    let count: Int
    let amount: Double
    let title: String
    let message: String
    let color: Color
}

enum EmotionAlertService {
    static func detectCandidate(
        records: [TransactionRecord],
        customEmotions: [CustomOption],
        highRiskOnly: Bool,
        locale: Locale,
        text: (LKey) -> String
    ) -> EmotionAlertCandidate? {
        let calendar = Calendar.current
        let since = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date.distantPast
        let recent = records.filter {
            $0.type == .expense && $0.createdAt >= since
        }
        guard !recent.isEmpty else { return nil }

        let emotionalItems = recent.filter { EmotionGrouping.isEmotional($0, customEmotions: customEmotions) }
        let totalAmount = recent.reduce(0) { $0 + $1.amount }
        let emotionalAmount = emotionalItems.reduce(0) { $0 + $1.amount }
        guard totalAmount > 0 else { return nil }

        let emotionalRatio = emotionalAmount / totalAmount
        let triggerThreshold = highRiskOnly ? 0.45 : 0.35
        guard emotionalRatio >= triggerThreshold else { return nil }
        guard emotionalItems.count >= 3 else { return nil }

        let targets: [EmotionTag] = [.impulse, .stress, .social]
        var best: (emotion: EmotionTag, count: Int, amount: Double)?

        for emotion in targets {
            let items = recent.filter { $0.emotionRaw == emotion.rawValue }
            guard !items.isEmpty else { continue }
            let amount = items.reduce(0) { $0 + $1.amount }
            let candidate = (emotion: emotion, count: items.count, amount: amount)
            if let bestCurrent = best {
                if candidate.count > bestCurrent.count || (candidate.count == bestCurrent.count && candidate.amount > bestCurrent.amount) {
                    best = candidate
                }
            } else {
                best = candidate
            }
        }

        guard let best else { return nil }
        let emotionName = text(best.emotion.key)
        let countText = "\(best.count)"
        let amountText = AppFormatter.moneyString(from: best.amount, locale: locale)

        let title = text(.alertTitle)
        let message = String(
            format: text(.alertTemplate),
            locale: locale,
            arguments: [emotionName, countText, amountText]
        )
        return EmotionAlertCandidate(
            emotionRaw: best.emotion.rawValue,
            count: best.count,
            amount: best.amount,
            title: title,
            message: message,
            color: best.emotion.color
        )
    }
}
