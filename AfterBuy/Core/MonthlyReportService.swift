import Foundation

struct MonthlyReportData {
    let generatedAt: Date
    let totalExpense: Double
    let totalCount: Int
    let topEmotionName: String
    let topEmotionAmount: Double
    /// Share of (effective + emotional) spend — excludes necessary.
    let effectiveRatio: Double
    /// Shares of total expense (sum ≈ 100% with rounding).
    let effectiveShareOfTotal: Double
    let emotionalShareOfTotal: Double
    let necessaryShareOfTotal: Double
    /// Remaining mood share not shown in the top-3 palette.
    let otherEmotionSharePercent: Int
    let patternLines: [String]
    let warmTip: String
}

enum MonthlyReportService {
    static func generate(
        records: [TransactionRecord],
        locale: Locale,
        text: (LKey) -> String,
        appSettings: AppSettings,
        customEmotions: [CustomOption]
    ) -> MonthlyReportData {
        let totalExpense = records.reduce(0) { $0 + $1.amount }
        let grouped = Dictionary(grouping: records, by: { $0.emotionRaw })
        let top = grouped.max { lhs, rhs in
            lhs.value.reduce(0) { $0 + $1.amount } < rhs.value.reduce(0) { $0 + $1.amount }
        }
        let topName = top.flatMap { $0.value.first }.map { displayEmotionName($0, text: text) } ?? text(.commonNoData)
        let topAmount = top?.value.reduce(0) { $0 + $1.amount } ?? 0

        let effective = records
            .filter { EmotionGrouping.isEffective($0, customEmotions: customEmotions) }
            .reduce(0) { $0 + $1.amount }
        let emotional = records
            .filter { EmotionGrouping.isEmotional($0, customEmotions: customEmotions) }
            .reduce(0) { $0 + $1.amount }
        let necessary = records
            .filter { EmotionGrouping.isNecessary($0, customEmotions: customEmotions) }
            .reduce(0) { $0 + $1.amount }
        let moodDenominator = effective + emotional
        let effectiveRatio = moodDenominator > 0 ? effective / moodDenominator : 0
        let effectiveShareOfTotal = totalExpense > 0 ? effective / totalExpense : 0
        let emotionalShareOfTotal = totalExpense > 0 ? emotional / totalExpense : 0
        let necessaryShareOfTotal = totalExpense > 0 ? necessary / totalExpense : 0
        let breakdown = EmotionShareCalculator.breakdown(from: records)
        let otherEmotionSharePercent = EmotionShareCalculator.residualSharePercent(
            afterTop: 3,
            in: breakdown
        )

        let patternLines = generatePatternLines(records: records, locale: locale, text: text, appSettings: appSettings)
        let warmTip = generateWarmTip(
            effectiveRatio: effectiveRatio,
            necessaryShareOfTotal: necessaryShareOfTotal,
            text: text,
            locale: locale
        )

        return MonthlyReportData(
            generatedAt: Date(),
            totalExpense: totalExpense,
            totalCount: records.count,
            topEmotionName: topName,
            topEmotionAmount: topAmount,
            effectiveRatio: effectiveRatio,
            effectiveShareOfTotal: effectiveShareOfTotal,
            emotionalShareOfTotal: emotionalShareOfTotal,
            necessaryShareOfTotal: necessaryShareOfTotal,
            otherEmotionSharePercent: otherEmotionSharePercent,
            patternLines: patternLines,
            warmTip: warmTip
        )
    }

    static func buildReportText(
        data: MonthlyReportData,
        locale: Locale,
        text: (LKey) -> String,
        title: String,
        expenseLabelKey: LKey
    ) -> String {
        let money = AppFormatter.moneyString(from: data.totalExpense, locale: locale)
        let topMoney = AppFormatter.moneyString(from: data.topEmotionAmount, locale: locale)
        let generatedAt = AppFormatter.dayString(from: data.generatedAt, locale: locale)
        let ratio = "\(Int(data.effectiveRatio * 100))%"
        let spendStructure = spendStructureLine(data: data, text: text, locale: locale)
        let patterns = data.patternLines.map { "- \($0)" }.joined(separator: "\n")
        return [
            title,
            text(.analysisReportSubtitle),
            "",
            "\(text(.analysisReportGeneratedAt)): \(generatedAt)",
            "\(text(expenseLabelKey)): \(money)",
            spendStructure,
            "\(text(.analysisReportTotalCount)): \(data.totalCount)",
            "\(text(.analysisReportTopEmotion)): \(data.topEmotionName) (\(topMoney))",
            "\(text(.analysisReportEffectiveRatio)): \(ratio) (\(text(.analysisReportHeroMetricEffectiveRatioHint)))",
            "",
            "\(text(.analysisReportRulesTitle)):",
            patterns.isEmpty ? "- \(text(.analysisPatternFallback))" : patterns,
            "",
            "\(text(.analysisReportWarmTipTitle)): \(data.warmTip)"
        ].joined(separator: "\n")
    }

    private static func generatePatternLines(
        records: [TransactionRecord],
        locale: Locale,
        text: (LKey) -> String,
        appSettings: AppSettings
    ) -> [String] {
        guard !records.isEmpty else { return [text(.analysisPatternFallback)] }
        let total = records.count
        var candidates: [(String, Int)] = []

        let weekdayCount = Dictionary(grouping: records, by: { Calendar.current.component(.weekday, from: $0.createdAt) })
        if let topWeekday = weekdayCount.max(by: { $0.value.count < $1.value.count }),
           isHighConfidence(topWeekday.value.count, total: total, appSettings: appSettings) {
            let line = localizedTemplate(
                text: text,
                locale: locale,
                key: .analysisPatternRuleWeekday,
                args: [localizedWeekdayName(index: topWeekday.key, locale: locale), "\(topWeekday.value.count)"]
            )
            candidates.append((line, topWeekday.value.count))
        }

        let timeCount = Dictionary(grouping: records, by: { timeBucket(for: $0.createdAt) })
        if let topTime = timeCount.max(by: { $0.value.count < $1.value.count }),
           isHighConfidence(topTime.value.count, total: total, appSettings: appSettings) {
            let line = localizedTemplate(
                text: text,
                locale: locale,
                key: .analysisPatternRuleTime,
                args: [localizedTimeName(bucket: topTime.key, text: text), "\(topTime.value.count)"]
            )
            candidates.append((line, topTime.value.count))
        }

        let categoryCount = Dictionary(grouping: records, by: \.categoryKey)
        if let topCategory = categoryCount.max(by: { $0.value.count < $1.value.count }),
           isHighConfidence(topCategory.value.count, total: total, appSettings: appSettings),
           let sample = topCategory.value.first {
            let categoryName = sample.resolvedCategoryForRetrospectiveDisplay(localizedText: text)
            let line = localizedTemplate(
                text: text,
                locale: locale,
                key: .analysisPatternRuleCategory,
                args: [categoryName, "\(topCategory.value.count)"]
            )
            candidates.append((line, topCategory.value.count))
        }

        let topLines = candidates.sorted { $0.1 > $1.1 }.prefix(2).map(\.0)
        return topLines.isEmpty ? [text(.analysisPatternFallback)] : Array(topLines)
    }

    static func spendStructureLine(
        data: MonthlyReportData,
        text: (LKey) -> String,
        locale: Locale
    ) -> String {
        String(
            format: text(.analysisReportSpendStructure),
            locale: locale,
            arguments: [
                text(.homeEffectiveSpend),
                percentText(data.effectiveShareOfTotal),
                text(.homeEmotionalSpend),
                percentText(data.emotionalShareOfTotal),
                text(.homeNecessarySpend),
                percentText(data.necessaryShareOfTotal),
            ] as [CVarArg]
        )
    }

    private static func generateWarmTip(
        effectiveRatio: Double,
        necessaryShareOfTotal: Double,
        text: (LKey) -> String,
        locale: Locale
    ) -> String {
        let ineffectiveRatio = percentText(1 - effectiveRatio)
        let effectivePercent = percentText(effectiveRatio)
        let necessaryPercent = percentText(necessaryShareOfTotal)
        let args = [ineffectiveRatio, effectivePercent, necessaryPercent] as [CVarArg]
        if effectiveRatio < 0.45 {
            return String(format: text(.analysisWarmGeneratedHigh), locale: locale, arguments: args)
        }
        if effectiveRatio < 0.7 {
            return String(format: text(.analysisWarmGeneratedMid), locale: locale, arguments: args)
        }
        return String(format: text(.analysisWarmGeneratedLow), locale: locale, arguments: args)
    }

    private static func percentText(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }

    private static func isHighConfidence(_ count: Int, total: Int, appSettings: AppSettings) -> Bool {
        guard total > 0 else { return false }
        let ratio = Double(count) / Double(total)
        return count >= appSettings.patternMinCount && ratio >= appSettings.patternMinRatio
    }

    private static func displayEmotionName(_ record: TransactionRecord, text: (LKey) -> String) -> String {
        if let preset = EmotionTag.from(raw: record.emotionRaw) {
            return text(preset.key)
        }
        return record.safeEmotionName
    }

    private static func localizedWeekdayName(index: Int, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        let symbols = formatter.weekdaySymbols ?? []
        guard index > 0 && index <= symbols.count else { return "\(index)" }
        return symbols[index - 1]
    }

    private static func timeBucket(for date: Date) -> TimeBucket {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return TimeBucket.morning
        case 12..<18: return TimeBucket.afternoon
        case 18..<23: return TimeBucket.evening
        default: return TimeBucket.night
        }
    }

    private static func localizedTimeName(bucket: TimeBucket, text: (LKey) -> String) -> String {
        switch bucket {
        case .morning: text(.analysisTimeMorning)
        case .afternoon: text(.analysisTimeAfternoon)
        case .evening: text(.analysisTimeEvening)
        case .night: text(.analysisTimeNight)
        }
    }

    private static func localizedTemplate(text: (LKey) -> String, locale: Locale, key: LKey, args: [CVarArg]) -> String {
        String(format: text(key), locale: locale, arguments: args)
    }
}

private enum TimeBucket: Hashable {
    case morning
    case afternoon
    case evening
    case night
}
