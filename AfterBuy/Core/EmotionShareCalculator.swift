import Foundation

// MARK: - Unified emotion amount shares (heat ring, report poster, export)

enum EmotionShareCalculator {
    struct Item: Identifiable, Equatable {
        let emotionRaw: String
        var id: String { emotionRaw }
        let amount: Double
        let count: Int
        /// Share of period total expense by amount (0–100), rounded half-up.
        let sharePercent: Int
    }

    struct Breakdown: Equatable {
        let totalExpense: Double
        /// Sorted by amount descending.
        let items: [Item]
    }

    static func sharePercent(amount: Double, total: Double) -> Int {
        guard total > 0, amount > 0 else { return 0 }
        return Int((amount / total * 100).rounded())
    }

    static func breakdown(from records: [TransactionRecord]) -> Breakdown {
        let expenses = records.filter { $0.type == .expense }
        let total = expenses.reduce(0) { $0 + $1.amount }
        guard total > 0 else {
            return Breakdown(totalExpense: 0, items: [])
        }

        var amountByRaw: [String: Double] = [:]
        var countByRaw: [String: Int] = [:]
        for record in expenses {
            amountByRaw[record.emotionRaw, default: 0] += record.amount
            countByRaw[record.emotionRaw, default: 0] += 1
        }

        let items = amountByRaw.keys
            .map { raw in
                let amount = amountByRaw[raw, default: 0]
                return Item(
                    emotionRaw: raw,
                    amount: amount,
                    count: countByRaw[raw, default: 0],
                    sharePercent: sharePercent(amount: amount, total: total)
                )
            }
            .sorted { $0.amount > $1.amount }

        return Breakdown(totalExpense: total, items: items)
    }

    static func topItems(from breakdown: Breakdown, limit: Int) -> [Item] {
        Array(breakdown.items.prefix(limit))
    }

    /// Spend share not covered by the top `limit` emotions (by amount), rounded.
    static func residualSharePercent(afterTop limit: Int, in breakdown: Breakdown) -> Int {
        guard breakdown.totalExpense > 0, limit > 0 else { return 0 }
        let topAmount = breakdown.items.prefix(limit).reduce(0) { $0 + $1.amount }
        return sharePercent(amount: max(0, breakdown.totalExpense - topAmount), total: breakdown.totalExpense)
    }
}
