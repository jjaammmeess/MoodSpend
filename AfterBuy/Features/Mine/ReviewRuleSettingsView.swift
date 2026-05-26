import SwiftData
import SwiftUI

struct ReviewRuleSettingsView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var appSettings: AppSettings
    @Query(filter: #Predicate<TransactionRecord> { $0.deletedAt == nil }) private var records: [TransactionRecord]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                MineSettingsCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label(localization.text(.mineRuleMinCount), systemImage: "number.circle")
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Stepper(value: $appSettings.patternMinCount, in: 1...10) {
                                Text("\(appSettings.patternMinCount)")
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(localization.text(.mineRuleMinRatio), systemImage: "percent")
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                Text("\(Int(appSettings.patternMinRatio * 100))%")
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $appSettings.patternMinRatio, in: 0.1...0.8, step: 0.05)
                                .tint(AppTheme.actionBlue)
                        }

                        Button(localization.text(.mineRuleReset)) {
                            appSettings.resetPatternRules()
                        }
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.actionBlue)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(localization.text(.mineRuleCurrent))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                Spacer()
                                Text(localization.text(currentRuleModeTitleKey))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(ruleModeColor)
                            }
                            Text(localization.text(currentRuleHintKey))
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(localization.text(.mineRulePreviewTitle))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            Text(localizedRulePreviewCount)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                                .monospacedDigit()
                            Text(localizedRulePreviewFilter)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                            Text(localizedRulePreviewHitTypes)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .padding(16)
                }

                reviewRuleTipCard
                    .padding(.top, 6)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle(localization.text(.mineRuleTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.pageBackground, for: .navigationBar)
    }

    private var reviewRuleTipCard: some View {
        MineSettingsExplanationTipCard(
            icon: "chart.bar.doc.horizontal",
            glowTint: AppTheme.accentInsight
        ) {
            Text(localization.text(.mineReviewRuleFooter))
                .lineSpacing(4)
        }
    }

    private var currentRuleModeTitleKey: LKey {
        switch ruleMode {
        case .relaxed: .mineRuleModeRelaxed
        case .balanced: .mineRuleModeBalanced
        case .strict: .mineRuleModeStrict
        }
    }

    private var currentRuleHintKey: LKey {
        switch ruleMode {
        case .relaxed: .mineRuleHintRelaxed
        case .balanced: .mineRuleHintBalanced
        case .strict: .mineRuleHintStrict
        }
    }

    private var ruleModeColor: Color {
        switch ruleMode {
        case .relaxed: AppTheme.accentSecondary
        case .balanced: AppTheme.actionBlue
        case .strict: AppTheme.accentInsight
        }
    }

    private var ruleMode: ReviewRuleMode {
        let countScore = Double(appSettings.patternMinCount) / 10.0
        let ratioScore = appSettings.patternMinRatio
        let score = (countScore * 0.45) + (ratioScore * 0.55)
        if score < 0.26 { return .relaxed }
        if score < 0.52 { return .balanced }
        return .strict
    }

    private var localizedRulePreviewCount: String {
        localizedTemplate(.mineRulePreviewCount, "\(estimatedKeptRules)")
    }

    private var localizedRulePreviewFilter: String {
        localizedTemplate(.mineRulePreviewFilter, localization.text(dynamicFilterStrengthKey))
    }

    private var estimatedKeptRules: Int {
        min(2, matchedRuleCount)
    }

    private var localizedRulePreviewHitTypes: String {
        let hitTypeLabels = matchedRuleTypes.map { localization.text($0) }
        let joined = hitTypeLabels.isEmpty
            ? localization.text(.mineRuleTypeNone)
            : hitTypeLabels.joined(separator: " + ")
        return localizedTemplate(.mineRulePreviewHitTypes, joined)
    }

    private func localizedTemplate(_ key: LKey, _ args: CVarArg...) -> String {
        String(format: localization.text(key), locale: localization.locale, arguments: args)
    }

    private var currentPeriodExpenses: [TransactionRecord] {
        records.filter { $0.type == .expense && DateFilter.month.includes($0.createdAt) }
    }

    private var matchedRuleCount: Int {
        matchedRuleTypes.count
    }

    private var matchedRuleTypes: [LKey] {
        let expenses = currentPeriodExpenses
        guard !expenses.isEmpty else { return [] }
        let total = expenses.count
        var types: [LKey] = []

        let weekdayCount = Dictionary(grouping: expenses, by: { Calendar.current.component(.weekday, from: $0.createdAt) })
        if let topWeekday = weekdayCount.max(by: { $0.value.count < $1.value.count }),
           isHighConfidence(topWeekday.value.count, total: total) {
            types.append(.mineRuleTypeWeekday)
        }

        let timeCount = Dictionary(grouping: expenses, by: { ReviewInsightTimeBucket.bucket(for: $0.createdAt) })
        if let topTime = timeCount.max(by: { $0.value.count < $1.value.count }),
           isHighConfidence(topTime.value.count, total: total) {
            types.append(.mineRuleTypeTime)
        }

        let categoryCount = Dictionary(grouping: expenses, by: \.categoryKey)
        if let topCategory = categoryCount.max(by: { $0.value.count < $1.value.count }),
           isHighConfidence(topCategory.value.count, total: total) {
            types.append(.mineRuleTypeCategory)
        }

        return types
    }

    private var dynamicFilterStrengthKey: LKey {
        switch matchedRuleCount {
        case 3: .mineRuleFilterLow
        case 2: .mineRuleFilterMid
        default: .mineRuleFilterHigh
        }
    }

    private func isHighConfidence(_ count: Int, total: Int) -> Bool {
        guard total > 0 else { return false }
        let ratio = Double(count) / Double(total)
        return count >= appSettings.patternMinCount && ratio >= appSettings.patternMinRatio
    }
}

private enum ReviewRuleMode {
    case relaxed
    case balanced
    case strict
}

private enum ReviewInsightTimeBucket: Hashable {
    case morning
    case afternoon
    case evening
    case night

    static func bucket(for date: Date) -> ReviewInsightTimeBucket {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return .morning
        case 12..<18: return .afternoon
        case 18..<23: return .evening
        default: return .night
        }
    }
}
