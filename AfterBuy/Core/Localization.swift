import Combine
import Foundation
import SwiftData

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case en = "en"

    var id: String { rawValue }

    static let defaultPreference: AppLanguage = .system

    /// Resolves `.system` from the device preferred language; other cases pass through.
    var resolved: AppLanguage {
        switch self {
        case .system:
            return Self.resolvedFromSystem()
        default:
            return self
        }
    }

    static func resolvedFromSystem() -> AppLanguage {
        let identifier = Locale.preferredLanguages.first ?? Locale.current.identifier
        let lowered = identifier.lowercased()
        if lowered.hasPrefix("zh-hant")
            || lowered.hasPrefix("zh-tw")
            || lowered.hasPrefix("zh-hk")
            || lowered.hasPrefix("zh-mo") {
            return .zhHant
        }
        if lowered.hasPrefix("zh") {
            return .zhHans
        }
        return .en
    }

    var locale: Locale {
        Locale(identifier: resolved.rawValue)
    }
}

enum LKey: String, CaseIterable {
    case tabHome = "tab.home"
    case tabBills = "tab.bills"
    case tabAnalysis = "tab.analysis"
    case tabMine = "tab.mine"

    case commonSave = "common.save"
    case commonCancel = "common.cancel"
    case commonOk = "common.ok"
    case commonDone = "common.done"
    case commonDelete = "common.delete"
    case commonIncome = "common.income"
    case commonExpense = "common.expense"
    case commonToday = "common.today"
    case commonYesterday = "common.yesterday"
    case commonNoData = "common.noData"
    case commonAll = "common.all"

    case homeTitle = "home.title"
    case homeQuickAdd = "home.quickAdd"
    case homeTodaySummary = "home.todaySummary"
    case homeWelcomeBack = "home.welcomeBack"
    case homeWelcomeName = "home.welcomeName"
    case homeHeroTitle = "home.hero.title"
    case homeHeroTitleCompact = "home.hero.title.compact"
    case homeEffectiveSpend = "home.effectiveSpend"
    case homeEffectiveSpendCompact = "home.effectiveSpend.compact"
    case homeEmotionalSpend = "home.emotionalSpend"
    case homeEmotionalSpendCompact = "home.emotionalSpend.compact"
    case homeNecessarySpend = "home.necessarySpend"
    case homeNecessarySpendCompact = "home.necessarySpend.compact"
    case homeHeroBucketDetailTitle = "home.hero.bucketDetail.title"
    case homeHeroBucketDetailSummary = "home.hero.bucketDetail.summary"
    case homeHeroBucketDetailShareOfMonth = "home.hero.bucketDetail.shareOfMonth"
    case homeHeroBucketDetailEmpty = "home.hero.bucketDetail.empty"
    case homeHeroBucketDetailEmotionBreakdown = "home.hero.bucketDetail.emotionBreakdown"
    case homeHeroBucketDetailOpenA11yHint = "home.hero.bucketDetail.openA11yHint"
    case homeHeroBucketDetailScopeNoteEffective = "home.hero.bucketDetail.scopeNote.effective"
    case homeHeroBucketDetailScopeNoteEmotional = "home.hero.bucketDetail.scopeNote.emotional"
    case homeHeroBucketDetailScopeNoteNecessary = "home.hero.bucketDetail.scopeNote.necessary"
    case homeHeroBucketDetailHeroSubtitleEffective = "home.hero.bucketDetail.heroSubtitle.effective"
    case homeHeroBucketDetailHeroSubtitleEmotional = "home.hero.bucketDetail.heroSubtitle.emotional"
    case homeHeroBucketDetailHeroSubtitleNecessary = "home.hero.bucketDetail.heroSubtitle.necessary"
    case analysisDashboardDetailHeroSubtitleDistress = "analysis.dashboard.detail.heroSubtitle.distress"
    case analysisDashboardDetailHeroSubtitleFulfillment = "analysis.dashboard.detail.heroSubtitle.fulfillment"
    case homeWeekDelta = "home.weekDelta"
    case homeWeekDeltaCompact = "home.weekDelta.compact"
    case homeWeekDeltaNone = "home.weekDelta.none"
    case homeWeekDeltaNoneCompact = "home.weekDelta.none.compact"
    case homeActionAdd = "home.action.add"
    case homeActionWeekTrend = "home.action.weekTrend"
    case homeActionCalendar = "home.action.calendar"
    case homeActionMore = "home.action.more"
    case homeRecentActivity = "home.recentActivity"
    case homeViewAll = "home.viewAll"
    case homePrimaryActionButton = "home.primaryAction.button"
    case homePrimaryActionSubtitleTodo = "home.primaryAction.subtitle.todo"
    case homePrimaryActionSubtitleDone = "home.primaryAction.subtitle.done"
    case homeDashboardTitle = "home.dashboard.title"
    case homeQualityScore = "home.qualityScore"
    case homeQualityHint = "home.qualityHint"
    case homeRiskLevel = "home.riskLevel"
    case homeRiskHint = "home.riskHint"
    case homeRiskLow = "home.risk.low"
    case homeRiskMedium = "home.risk.medium"
    case homeRiskHigh = "home.risk.high"
    case homeTopEmotionCard = "home.topEmotionCard"
    case homeTaskCard = "home.taskCard"
    case homeTaskCTA = "home.task.cta"
    case homeTaskCompleted = "home.task.completed"
    case homeTaskTodoSubtitle = "home.task.todoSubtitle"
    case homeTaskDoneSubtitle = "home.task.doneSubtitle"
    case homeSpendToday = "home.spend.today"
    case homeSpendWeek = "home.spend.week"
    case homeSpendMonth = "home.spend.month"
    case homeMetricCount = "home.metric.count"
    case homeMetricEmotionalRatio7d = "home.metric.emotionalRatio7d"
    case homeMetricEmotionalRatioDetail = "home.metric.emotionalRatioDetail"
    case homeMetricEmotionalRatioNoData = "home.metric.emotionalRatioNoData"
    case homeRecordsToday = "home.records.today"
    case homeRecordsWeek = "home.records.week"
    case homeRecordsMonth = "home.records.month"
    case homeRecentRecords = "home.recentRecords"
    case homeEmptyTip = "home.emptyTip"
    case homeEmotionShareTitle = "home.emotionShare.title"
    case homeEmotionShareSubtitle = "home.emotionShare.subtitle"
    case homeEmotionShareEmptyHint = "home.emotionShare.emptyHint"
    case homeEmotionShareScopeWeek = "home.emotionShare.scopeWeek"
    case homeEmotionShareDominant = "home.emotionShare.dominant"
    case homeEmotionShareDominantEmpty = "home.emotionShare.dominantEmpty"
    case homeTodayPeaceTitle = "home.today.peaceTitle"
    case homeTodayPeaceTitleCompact = "home.today.peaceTitle.compact"
    case homeTodayPeaceSubtitle = "home.today.peaceSubtitle"
    case homeTodayImpulseStressSummary = "home.today.impulseStressSummary"
    case homeSparklineTitle = "home.sparkline.title"
    case homeSparklineTitleCompact = "home.sparkline.title.compact"
    case homeSparklineHintEmpty = "home.sparkline.hintEmpty"
    case homeEmotionShareCompactTitle = "home.emotionShare.compact.title"
    case homeEmotionShareCompactA11y = "home.emotionShare.compact.a11y"
    case homeEmotionShare30dTitle = "home.emotionShare30d.title"
    case homeEmotionShare30dDominant = "home.emotionShare30d.dominant"
    case homeEmotionShare30dScattered = "home.emotionShare30d.scattered"
    case homeEmotionShare30dScatteredCompact = "home.emotionShare30d.scattered.compact"
    case homeEmotionShare30dEmpty = "home.emotionShare30d.empty"
    case homeEmotionShare30dA11y = "home.emotionShare30d.a11y"
    case homeMoodSpectrumLabel = "home.moodSpectrum.label"
    case homeMoodSpectrumSubtitle = "home.moodSpectrum.subtitle"
    case homeMoodSpectrumLongPressHint = "home.moodSpectrum.longPressHint"
    case homeMoodSpectrumGuideTitle = "home.moodSpectrum.guide.title"
    case homeMoodSpectrumGuideLegendTitle = "home.moodSpectrum.guide.legendTitle"
    case homeMoodSpectrumGuidePresetSection = "home.moodSpectrum.guide.presetSection"
    case homeMoodSpectrumGuidePresetHint = "home.moodSpectrum.guide.presetHint"
    case homeMoodSpectrumGuideCustomSection = "home.moodSpectrum.guide.customSection"
    case homeMoodSpectrumGuideCustomNote = "home.moodSpectrum.guide.customNote"
    case homeMoodSpectrumGuideCustomMetrics = "home.moodSpectrum.guide.customMetrics"
    case homeMoodSpectrumGuideReadingTitle = "home.moodSpectrum.guide.readingTitle"
    case homeMoodSpectrumGuideReadingBody = "home.moodSpectrum.guide.readingBody"
    case homeMoodSpectrumGuideOpenDetail = "home.moodSpectrum.guide.openDetail"
    case homeMoodSpectrumA11ySpectrumLabel = "home.moodSpectrum.a11y.spectrumLabel"
    case homeMoodSpectrumDetailTitle = "home.moodSpectrum.detail.title"
    case homeMoodSpectrumDetailFooter = "home.moodSpectrum.detail.footer"
    case homeMoodSpectrumDetailEmpty = "home.moodSpectrum.detail.empty"
    case homeMoodSpectrumDetailIndex = "home.moodSpectrum.detail.index"
    case homeMoodSpectrumA11yHint = "home.moodSpectrum.a11y.hint"
    case homeMoodSpectrumDominant = "home.moodSpectrum.dominant"
    case homeMoodSpectrumDualDominant = "home.moodSpectrum.dualDominant"
    case homeMoodSpectrumScattered = "home.moodSpectrum.scattered"
    case homeMoodSpectrumScatteredV1 = "home.moodSpectrum.scattered.v1"
    case homeMoodSpectrumScatteredV2 = "home.moodSpectrum.scattered.v2"
    case homeMoodSpectrumScatteredV3 = "home.moodSpectrum.scattered.v3"
    case homeMoodSpectrumScatteredV4 = "home.moodSpectrum.scattered.v4"
    case homeMoodSpectrumEmpty = "home.moodSpectrum.empty"
    case homeMoodSpectrumEmptyV1 = "home.moodSpectrum.empty.v1"
    case homeMoodSpectrumEmptyV2 = "home.moodSpectrum.empty.v2"
    case homeMoodSpectrumSparse = "home.moodSpectrum.sparse"
    case homeMoodSpectrumSparseV1 = "home.moodSpectrum.sparse.v1"
    case homeMoodSpectrumSparseV2 = "home.moodSpectrum.sparse.v2"
    case homeMoodSpectrumSparseV3 = "home.moodSpectrum.sparse.v3"
    case homeMoodSpectrumComfortStress = "home.moodSpectrum.comfort.stress"
    case homeMoodSpectrumComfortStressV1 = "home.moodSpectrum.comfort.stress.v1"
    case homeMoodSpectrumComfortStressV2 = "home.moodSpectrum.comfort.stress.v2"
    case homeMoodSpectrumComfortStressV3 = "home.moodSpectrum.comfort.stress.v3"
    case homeMoodSpectrumComfortImpulse = "home.moodSpectrum.comfort.impulse"
    case homeMoodSpectrumComfortImpulseV1 = "home.moodSpectrum.comfort.impulse.v1"
    case homeMoodSpectrumComfortImpulseV2 = "home.moodSpectrum.comfort.impulse.v2"
    case homeMoodSpectrumComfortImpulseV3 = "home.moodSpectrum.comfort.impulse.v3"
    case homeMoodSpectrumComfortSocial = "home.moodSpectrum.comfort.social"
    case homeMoodSpectrumComfortSocialV1 = "home.moodSpectrum.comfort.social.v1"
    case homeMoodSpectrumComfortSocialV2 = "home.moodSpectrum.comfort.social.v2"
    case homeMoodSpectrumComfortSocialV3 = "home.moodSpectrum.comfort.social.v3"
    case homeMoodSpectrumComfortPamper = "home.moodSpectrum.comfort.pamper"
    case homeMoodSpectrumComfortPamperV1 = "home.moodSpectrum.comfort.pamper.v1"
    case homeMoodSpectrumComfortPamperV2 = "home.moodSpectrum.comfort.pamper.v2"
    case homeMoodSpectrumComfortPamperV3 = "home.moodSpectrum.comfort.pamper.v3"
    case homeMoodSpectrumComfortRitual = "home.moodSpectrum.comfort.ritual"
    case homeMoodSpectrumComfortRitualV1 = "home.moodSpectrum.comfort.ritual.v1"
    case homeMoodSpectrumComfortRitualV2 = "home.moodSpectrum.comfort.ritual.v2"
    case homeMoodSpectrumComfortRitualV3 = "home.moodSpectrum.comfort.ritual.v3"
    case homeMoodSpectrumComfortNecessity = "home.moodSpectrum.comfort.necessity"
    case homeMoodSpectrumComfortNecessityV1 = "home.moodSpectrum.comfort.necessity.v1"
    case homeMoodSpectrumComfortNecessityV2 = "home.moodSpectrum.comfort.necessity.v2"
    case homeMoodSpectrumComfortNecessityV3 = "home.moodSpectrum.comfort.necessity.v3"
    case homeMoodSpectrumComfortScattered = "home.moodSpectrum.comfort.scattered"
    case homeMoodSpectrumComfortScatteredV1 = "home.moodSpectrum.comfort.scattered.v1"
    case homeMoodSpectrumComfortScatteredV2 = "home.moodSpectrum.comfort.scattered.v2"
    case homeMoodSpectrumComfortScatteredV3 = "home.moodSpectrum.comfort.scattered.v3"
    case homeMoodSpectrumComfortScatteredV4 = "home.moodSpectrum.comfort.scattered.v4"
    case homeMoodSpectrumComfortEmpty = "home.moodSpectrum.comfort.empty"
    case homeMoodSpectrumComfortEmptyV1 = "home.moodSpectrum.comfort.empty.v1"
    case homeMoodSpectrumComfortEmptyV2 = "home.moodSpectrum.comfort.empty.v2"
    case homeMoodSpectrumComfortEmptyV3 = "home.moodSpectrum.comfort.empty.v3"
    case homeMoodSpectrumComfortSparseV1 = "home.moodSpectrum.comfort.sparse.v1"
    case homeMoodSpectrumComfortSparseV2 = "home.moodSpectrum.comfort.sparse.v2"
    case homeMoodSpectrumComfortSparseV3 = "home.moodSpectrum.comfort.sparse.v3"
    case homeMoodSpectrumComfortEmotional = "home.moodSpectrum.comfort.emotional"
    case homeMoodSpectrumComfortEmotionalV1 = "home.moodSpectrum.comfort.emotional.v1"
    case homeMoodSpectrumComfortEmotionalV2 = "home.moodSpectrum.comfort.emotional.v2"
    case homeMoodSpectrumComfortEmotionalV3 = "home.moodSpectrum.comfort.emotional.v3"
    case homeMoodSpectrumComfortEffective = "home.moodSpectrum.comfort.effective"
    case homeMoodSpectrumComfortEffectiveV1 = "home.moodSpectrum.comfort.effective.v1"
    case homeMoodSpectrumComfortEffectiveV2 = "home.moodSpectrum.comfort.effective.v2"
    case homeMoodSpectrumComfortEffectiveV3 = "home.moodSpectrum.comfort.effective.v3"
    case homeMoodSpectrumComfortNecessaryBucketV1 = "home.moodSpectrum.comfort.necessaryBucket.v1"
    case homeMoodSpectrumComfortNecessaryBucketV2 = "home.moodSpectrum.comfort.necessaryBucket.v2"
    case homeMoodSpectrumComfortNecessaryBucketV3 = "home.moodSpectrum.comfort.necessaryBucket.v3"
    case homeMoodSpectrumComfortCustomEffectiveV1 = "home.moodSpectrum.comfort.custom.effective.v1"
    case homeMoodSpectrumComfortCustomEffectiveV2 = "home.moodSpectrum.comfort.custom.effective.v2"
    case homeMoodSpectrumComfortCustomEffectiveV3 = "home.moodSpectrum.comfort.custom.effective.v3"
    case homeMoodSpectrumComfortCustomEmotionalV1 = "home.moodSpectrum.comfort.custom.emotional.v1"
    case homeMoodSpectrumComfortCustomEmotionalV2 = "home.moodSpectrum.comfort.custom.emotional.v2"
    case homeMoodSpectrumComfortCustomEmotionalV3 = "home.moodSpectrum.comfort.custom.emotional.v3"
    case homeMoodSpectrumComfortCustomNecessaryV1 = "home.moodSpectrum.comfort.custom.necessary.v1"
    case homeMoodSpectrumComfortCustomNecessaryV2 = "home.moodSpectrum.comfort.custom.necessary.v2"
    case homeMoodSpectrumComfortCustomNecessaryV3 = "home.moodSpectrum.comfort.custom.necessary.v3"
    case homeSearchPlaceholder = "home.searchPlaceholder"
    case homeEmotionFilterAll = "home.emotionFilter.all"
    case homeAlertTitle = "home.alertTitle"
    case homeAlertNoRisk = "home.alert.noRisk"
    case homeAlertGeneratedLow = "home.alert.generated.low"
    case homeAlertGeneratedMid = "home.alert.generated.mid"
    case homeAlertGeneratedHigh = "home.alert.generated.high"
    case notificationCenterTitle = "notification.center.title"
    case notificationMarkAllRead = "notification.markAllRead"
    case notificationEmpty = "notification.empty"
    case notificationTabAll = "notification.tab.all"
    case notificationTabWarning = "notification.tab.warning"
    case notificationTabTask = "notification.tab.task"
    case notificationTabSystem = "notification.tab.system"
    case notificationSystemWelcomeTitle = "notification.system.welcome.title"
    case notificationSystemWelcomeMessage = "notification.system.welcome.message"
    case notificationTaskStarterTitle = "notification.task.starter.title"
    case notificationTaskStarterMessage = "notification.task.starter.message"
    case notificationDetailTitle = "notification.detail.title"
    case notificationActionReview = "notification.action.review"
    case notificationActionAddRecord = "notification.action.addRecord"
    case notificationDeleteAll = "notification.deleteAll"
    case notificationDeleteAllConfirmTitle = "notification.deleteAll.confirm.title"
    case notificationDeleteAllConfirmMessage = "notification.deleteAll.confirm.message"
    case notificationPin = "notification.pin"
    case notificationUnpin = "notification.unpin"
    case notificationPinned = "notification.pinned"
    case notificationTimeJustNow = "notification.time.justNow"
    case notificationTimeMinutesAgo = "notification.time.minutesAgo"
    case notificationTimeMinuteAgoSingle = "notification.time.minuteAgo.single"
    case notificationTimeHoursAgo = "notification.time.hoursAgo"
    case notificationTimeHourAgoSingle = "notification.time.hourAgo.single"
    case notificationTimeYesterday = "notification.time.yesterday"
    case notificationTimeDaysAgo = "notification.time.daysAgo"
    case notificationTimeDayAgoSingle = "notification.time.dayAgo.single"

    case recordTitle = "record.title"
    case recordNavTitle = "record.navTitle"
    case recordSubtitle = "record.subtitle"
    case recordAmountPlaceholder = "record.amountPlaceholder"
    case recordAmountZeroDisplay = "record.amountZeroDisplay"
    case recordAmountTip = "record.amountTip"
    case recordAmountCalculatorHint = "record.amountCalculatorHint"
    case recordDateTimeTitle = "record.dateTimeTitle"
    case recordDateTimeTip = "record.dateTimeTip"
    case recordPastTimeButtonA11y = "record.pastTimeButton.a11y"
    case recordPastTimeButtonA11yHint = "record.pastTimeButton.a11yHint"
    case recordPastTimePanelTitle = "record.pastTimePanel.title"
    case recordCategoryTitle = "record.categoryTitle"
    case recordEmotionTitle = "record.emotionTitle"
    case recordEmotionGuide = "record.emotionGuide"
    case recordEmotionDescriptionTitle = "record.emotionDescriptionTitle"
    case recordEmotionDescriptionCustom = "record.emotionDescriptionCustom"
    case recordEmotionDescPamper = "record.emotion.desc.pamper"
    case recordEmotionDescNecessity = "record.emotion.desc.necessity"
    case recordEmotionDescImpulse = "record.emotion.desc.impulse"
    case recordEmotionDescStress = "record.emotion.desc.stress"
    case recordEmotionDescSocial = "record.emotion.desc.social"
    case recordEmotionDescRitual = "record.emotion.desc.ritual"
    case recordNotePlaceholder = "record.notePlaceholder"
    case recordNoteCaption = "record.noteCaption"
    case recordNoteCaptionFree = "record.noteCaption.free"
    case recordNoteCaptionPro = "record.noteCaption.pro"
    case recordNoteCharacterCount = "record.noteCharacterCount"
    case recordPhotoProGate = "record.photo.proGate"
    case recordAddPhotoReceipt = "record.addPhotoReceipt"
    case recordAddMorePhotos = "record.addMorePhotos"
    case recordRemovePhoto = "record.removePhoto"
    case recordPhotoPlaceholder = "record.photoPlaceholder"
    case recordOptionalTip = "record.optionalTip"
    case recordValidationTip = "record.validationTip"
    case recordPhotoSelected = "record.photoSelected"
    case recordAddCustomCategory = "record.addCustomCategory"
    case recordAddCustomEmotion = "record.addCustomEmotion"
    case recordGridAdd = "record.grid.add"
    case recordGridAddCategoryA11y = "record.grid.addCategory.a11y"
    case recordGridAddEmotionA11y = "record.grid.addEmotion.a11y"
    case recordEmotionBucketSection = "record.emotionBucketSection"
    case recordEmotionBucketHint = "record.emotionBucketHint"
    case recordCustomInputPlaceholder = "record.customInputPlaceholder"
    case recordCustomSave = "record.customSave"
    case recordCustomEdit = "record.custom.edit"
    case recordCustomDelete = "record.custom.delete"
    case recordCustomEditCategoryTitle = "record.custom.editCategoryTitle"
    case recordCustomEditEmotionTitle = "record.custom.editEmotionTitle"
    case recordCustomIconSection = "record.custom.iconSection"
    case recordCustomDeleteConfirmTitle = "record.custom.deleteConfirmTitle"
    case recordCustomDeleteConfirmMessage = "record.custom.deleteConfirmMessage"
    case recordCustomDuplicateName = "record.custom.duplicateName"
    case recordDetailTitle = "record.detail.title"
    case recordDetailAmount = "record.detail.amount"
    case recordDetailCategory = "record.detail.category"
    case recordDetailEmotion = "record.detail.emotion"
    case recordDetailTime = "record.detail.time"
    case recordDetailNote = "record.detail.note"
    case recordDetailNoNote = "record.detail.noNote"
    case recordDetailReceipt = "record.detail.receipt"
    case recordDetailNoReceipt = "record.detail.noReceipt"
    case recordDetailDeleteConfirmTitle = "record.detail.deleteConfirm.title"
    case recordDetailDeleteConfirmMessage = "record.detail.deleteConfirm.message"

    case billsTitle = "bills.title"
    case billsFilterDay = "bills.filter.day"
    case billsFilterWeek = "bills.filter.week"
    case billsFilterMonth = "bills.filter.month"
    case billsFilterYear = "bills.filter.year"

    case billsPeriodDay = "bills.period.day"
    case billsPeriodWeek = "bills.period.week"
    case billsPeriodMonth = "bills.period.month"
    case billsPeriodYear = "bills.period.year"
    case billsPeriodCustom = "bills.period.custom"
    case billsPeriodNavMonth = "bills.period.nav.month"
    case billsPeriodNavYear = "bills.period.nav.year"
    case billsPeriodNavWeekRange = "bills.period.nav.weekRange"
    case billsPeriodNavWeekFallback = "bills.period.nav.weekFallback"
    case billsPeriodCustomLocked = "bills.period.custom.locked"
    case billsPeriodCustomUnset = "bills.period.custom.unset"
    case billsPeriodCustomPickerTitle = "bills.period.custom.pickerTitle"
    case billsPeriodCustomPickerPreview = "bills.period.custom.pickerPreview"
    case billsPeriodCustomConfirm = "bills.period.custom.confirm"
    case billsPeriodCustomPaywallHint = "bills.period.custom.paywallHint"
    case billsInsightPeriodPrefixCustom = "bills.insight.periodPrefix.custom"
    case billsInsightCustomClauseRange = "bills.insight.custom.clause.range"
    case billsInsightCustomClauseSingleMonth = "bills.insight.custom.clause.singleMonth"
    case billsInsightCustomRangeLabelRange = "bills.insight.custom.rangeLabel.range"
    case billsInsightCustomRangeLabelSingleMonth = "bills.insight.custom.rangeLabel.singleMonth"
    case billsInsightCategoryShareDominantCustom = "bills.insight.categoryShare.dominant.custom"
    case billsInsightCategoryShareSelectedCustom = "bills.insight.categoryShare.selected.custom"
    case billsInsightCategoryShareSelectedMany = "bills.insight.categoryShare.selectedMany"
    case billsInsightCategoryShareSelectedManyCustom = "bills.insight.categoryShare.selectedMany.custom"
    case billsInsightCompareUpCustom = "bills.insight.compare.up.custom"
    case billsInsightCompareDownCustom = "bills.insight.compare.down.custom"
    case billsDashboardTotalSpentCustom = "bills.dashboard.totalSpent.custom"
    case billsDashboardFrequencyCustom = "bills.dashboard.frequency.custom"
    case billsDashboardComparePeriodCustom = "bills.dashboard.comparePeriod.custom"
    case analysisPeriodCustomConfirm = "analysis.period.custom.confirm"
    case analysisPeriodCustomPaywallHint = "analysis.period.custom.paywallHint"
    case analysisDashboardComparePeriodCustom = "analysis.dashboard.comparePeriod.custom"
    case analysisDashboardDetailPeriodCustom = "analysis.dashboard.detail.period.custom"
    case analysisHeatmapSubtitleCustom = "analysis.heatmap.subtitle.custom"
    case analysisSpectrumTitleCustom = "analysis.spectrum.title.custom"
    case analysisSpectrumInsightCustomCalm = "analysis.spectrum.insight.custom.calm"
    case analysisSpectrumInsightCustomBalanced = "analysis.spectrum.insight.custom.balanced"
    case analysisSpectrumInsightCustomElevated = "analysis.spectrum.insight.custom.elevated"
    case analysisSpectrumGuidePeriodCustom = "analysis.spectrum.guide.period.custom"
    case billsEmptyTip = "bills.emptyTip"
    case billsEdit = "bills.edit"
    case billsMetricExpenseTitleDay = "bills.metric.expense.title.day"
    case billsMetricExpenseTitleWeek = "bills.metric.expense.title.week"
    case billsMetricExpenseTitleMonth = "bills.metric.expense.title.month"
    case billsMetricExpenseTitleYear = "bills.metric.expense.title.year"
    case billsMetricCountTitleDay = "bills.metric.count.title.day"
    case billsMetricCountTitleWeek = "bills.metric.count.title.week"
    case billsMetricCountTitleMonth = "bills.metric.count.title.month"
    case billsMetricCountTitleYear = "bills.metric.count.title.year"
    case billsMetricCountValue = "bills.metric.count.value"
    case billsDashboardTotalSpentDay = "bills.dashboard.totalSpent.day"
    case billsDashboardTotalSpentWeek = "bills.dashboard.totalSpent.week"
    case billsDashboardTotalSpentMonth = "bills.dashboard.totalSpent.month"
    case billsDashboardTotalSpentYear = "bills.dashboard.totalSpent.year"
    case billsDashboardFrequencyDay = "bills.dashboard.frequency.day"
    case billsDashboardFrequencyWeek = "bills.dashboard.frequency.week"
    case billsDashboardFrequencyMonth = "bills.dashboard.frequency.month"
    case billsDashboardFrequencyYear = "bills.dashboard.frequency.year"
    case billsDashboardEntries = "bills.dashboard.entries"
    case billsDashboardComparePeriodDay = "bills.dashboard.comparePeriod.day"
    case billsDashboardComparePeriodWeek = "bills.dashboard.comparePeriod.week"
    case billsDashboardComparePeriodMonth = "bills.dashboard.comparePeriod.month"
    case billsDashboardComparePeriodYear = "bills.dashboard.comparePeriod.year"
    case billsDashboardExpenseDeltaUp = "bills.dashboard.expenseDelta.up"
    case billsDashboardExpenseDeltaDown = "bills.dashboard.expenseDelta.down"
    case billsDashboardExpenseDeltaFlat = "bills.dashboard.expenseDelta.flat"
    case billsDashboardExpenseDeltaUnavailable = "bills.dashboard.expenseDelta.unavailable"
    case billsDashboardFreqDeltaUp = "bills.dashboard.freqDelta.up"
    case billsDashboardFreqDeltaDown = "bills.dashboard.freqDelta.down"
    case billsDashboardFreqDeltaFlat = "bills.dashboard.freqDelta.flat"
    case billsDashboardFreqDeltaUnavailable = "bills.dashboard.freqDelta.unavailable"
    case billsDashboardSparklineA11y = "bills.dashboard.sparkline.a11y"
    case billsInsightPeriodPrefixDay = "bills.insight.periodPrefix.day"
    case billsInsightPeriodPrefixWeek = "bills.insight.periodPrefix.week"
    case billsInsightPeriodPrefixMonth = "bills.insight.periodPrefix.month"
    case billsInsightPeriodPrefixYear = "bills.insight.periodPrefix.year"
    case billsInsightEmptyDay = "bills.insight.empty.day"
    case billsInsightCategoryShareSelected = "bills.insight.categoryShare.selected"
    case billsInsightCategoryShareDominant = "bills.insight.categoryShare.dominant"
    case billsInsightTrendFlat = "bills.insight.trend.flat"
    case billsInsightTrendRising = "bills.insight.trend.rising"
    case billsInsightTrendFalling = "bills.insight.trend.falling"
    case billsInsightCompareUp = "bills.insight.compare.up"
    case billsInsightCompareDown = "bills.insight.compare.down"
    case billsInsightFallback = "bills.insight.fallback"
    case billsFilterCategoryLabel = "bills.filter.category.label"
    case billsFilterCategorySummaryMany = "bills.filter.category.summaryMany"
    case billsFilterEmotionLabel = "bills.filter.emotion.label"
    case billsFilteredEmptyTitle = "bills.filtered.empty.title"
    case billsFilteredEmptyHint = "bills.filtered.empty.hint"
    case billsClearFilters = "bills.clearFilters"
    case billsFilterSheetTitle = "bills.filter.sheetTitle"
    case billsFilterSheetReset = "bills.filter.sheet.reset"
    case billsFilterEntryA11yHint = "bills.filter.entry.a11yHint"
    case billsMetricDetailTitleExpense = "bills.metricDetail.title.expense"
    case billsMetricDetailTitleFrequency = "bills.metricDetail.title.frequency"
    case billsMetricDetailNecessaryTitle = "bills.metricDetail.necessary.title"
    case billsMetricDetailNecessaryLabel = "bills.metricDetail.necessary.label"
    case billsMetricDetailPremiumLabel = "bills.metricDetail.premium.label"
    case billsMetricDetailNecessarySummary = "bills.metricDetail.necessary.summary"
    case billsMetricDetailStabilitySolid = "bills.metricDetail.stability.solid"
    case billsMetricDetailStabilityTrim = "bills.metricDetail.stability.trim"
    case billsMetricDetailTop3Title = "bills.metricDetail.top3.title"
    case billsMetricDetailTop3Empty = "bills.metricDetail.top3.empty"
    case billsMetricDetailTopRank = "bills.metricDetail.top.rank"
    case billsMetricDetailProLockHint = "bills.metricDetail.pro.lockHint"
    case billsMetricDetailAvgTicketTitle = "bills.metricDetail.avgTicket.title"
    case billsMetricDetailAvgTicketMicro = "bills.metricDetail.avgTicket.micro"
    case billsMetricDetailAvgTicketSteady = "bills.metricDetail.avgTicket.steady"
    case billsMetricDetailAvgTicketLarge = "bills.metricDetail.avgTicket.large"
    case billsMetricDetailPeakTimeTitle = "bills.metricDetail.peakTime.title"
    case billsMetricDetailPeakTimeBody = "bills.metricDetail.peakTime.body"
    case billsMetricDetailPeakTimeUnavailable = "bills.metricDetail.peakTime.unavailable"
    case billsMetricDetailFrequencyEmpty = "bills.metricDetail.frequency.empty"
    case billsMetricDetailDashboardExpenseA11yHint = "bills.metricDetail.dashboard.expense.a11yHint"
    case billsMetricDetailDashboardFrequencyA11yHint = "bills.metricDetail.dashboard.frequency.a11yHint"
    case billsRowAttachmentNoteA11y = "bills.row.attachment.note"
    case billsRowAttachmentPhotoA11y = "bills.row.attachment.photo"
    case billsRowAttachmentBothA11y = "bills.row.attachment.both"

    case analysisTitle = "analysis.title"
    case analysisSubtitle = "analysis.subtitle"
    case analysisOverview = "analysis.overview"
    case analysisOverviewDay = "analysis.overview.day"
    case analysisOverviewWeek = "analysis.overview.week"
    case analysisOverviewMonth = "analysis.overview.month"
    case analysisOverviewYear = "analysis.overview.year"
    case analysisDashboardDistressTitle = "analysis.dashboard.distress.title"
    case analysisDashboardFulfillmentTitle = "analysis.dashboard.fulfillment.title"
    case analysisDashboardEntries = "analysis.dashboard.entries"
    case analysisDashboardDistressShare = "analysis.dashboard.distress.share"
    case analysisDashboardDistressShareA11y = "analysis.dashboard.distress.share.a11y"
    case analysisDashboardDistressScaleA11y = "analysis.dashboard.distress.scale.a11y"
    case analysisDashboardPositiveRateDeltaUp = "analysis.dashboard.positiveRateDelta.up"
    case analysisDashboardPositiveRateDeltaDown = "analysis.dashboard.positiveRateDelta.down"
    case analysisDashboardPositiveRateDeltaFlat = "analysis.dashboard.positiveRateDelta.flat"
    case analysisDashboardPositiveRateDeltaUnavailable = "analysis.dashboard.positiveRateDelta.unavailable"
    case analysisDashboardDetailTitle = "analysis.dashboard.detail.title"
    case analysisDashboardDetailPeriodDay = "analysis.dashboard.detail.period.day"
    case analysisDashboardDetailPeriodWeek = "analysis.dashboard.detail.period.week"
    case analysisDashboardDetailPeriodMonth = "analysis.dashboard.detail.period.month"
    case analysisDashboardDetailPeriodYear = "analysis.dashboard.detail.period.year"
    case analysisDashboardDetailShareOfPeriod = "analysis.dashboard.detail.shareOfPeriod"
    case analysisDashboardDetailEmptyDistress = "analysis.dashboard.detail.empty.distress"
    case analysisDashboardDetailEmptyFulfillment = "analysis.dashboard.detail.empty.fulfillment"
    case analysisDashboardDetailOpenA11yHint = "analysis.dashboard.detail.openA11yHint"
    case analysisDashboardDetailDistressScopeNote = "analysis.dashboard.detail.distress.scopeNote"
    case analysisDashboardDetailFulfillmentScopeNote = "analysis.dashboard.detail.fulfillment.scopeNote"
    case analysisMetricExpenseTitle = "analysis.metric.expense.title"
    case analysisMetricCountTitle = "analysis.metric.count.title"
    case analysisMetricCountValue = "analysis.metric.count.value"
    case analysisMetricExpenseTitleDay = "analysis.metric.expense.title.day"
    case analysisMetricExpenseTitleWeek = "analysis.metric.expense.title.week"
    case analysisMetricExpenseTitleMonth = "analysis.metric.expense.title.month"
    case analysisMetricExpenseTitleYear = "analysis.metric.expense.title.year"
    case analysisMetricCountTitleDay = "analysis.metric.count.title.day"
    case analysisMetricCountTitleWeek = "analysis.metric.count.title.week"
    case analysisMetricCountTitleMonth = "analysis.metric.count.title.month"
    case analysisMetricCountTitleYear = "analysis.metric.count.title.year"
    case analysisTotalExpense = "analysis.totalExpense"
    case analysisTotalCount = "analysis.totalCount"
    case analysisDistribution = "analysis.distribution"
    case analysisDistributionEmptyHint = "analysis.distribution.emptyHint"
    case analysisTopEmotion = "analysis.topEmotion"
    case analysisPatternTitle = "analysis.patternTitle"
    case analysisPatternTip = "analysis.patternTip"
    case analysisPatternEmptyTip = "analysis.pattern.emptyTip"
    case analysisPatternGenerated = "analysis.pattern.generated"
    case analysisPatternFallback = "analysis.pattern.fallback"
    case analysisPatternRuleWeekday = "analysis.pattern.rule.weekday"
    case analysisPatternRuleTime = "analysis.pattern.rule.time"
    case analysisPatternRuleCategory = "analysis.pattern.rule.category"
    case analysisPatternIneffectiveShareLabel = "analysis.pattern.ineffectiveShareLabel"
    case analysisPatternBadgeCategory = "analysis.pattern.badge.category"
    case analysisPatternBadgeTime = "analysis.pattern.badge.time"
    case analysisPatternBadgeWeekday = "analysis.pattern.badge.weekday"
    case analysisPatternBadgeCount = "analysis.pattern.badge.count"
    case analysisPatternPrescriptionPause = "analysis.pattern.prescription.pause"
    case analysisPatternPrescriptionMid = "analysis.pattern.prescription.mid"
    case analysisPatternPrescriptionLow = "analysis.pattern.prescription.low"
    case analysisTimeMorning = "analysis.time.morning"
    case analysisTimeAfternoon = "analysis.time.afternoon"
    case analysisTimeEvening = "analysis.time.evening"
    case analysisTimeNight = "analysis.time.night"
    case analysisWarmGeneratedHigh = "analysis.warm.generated.high"
    case analysisWarmGeneratedMid = "analysis.warm.generated.mid"
    case analysisWarmGeneratedLow = "analysis.warm.generated.low"
    case analysisCalendarTitle = "analysis.calendarTitle"
    case analysisWarmLine = "analysis.warmLine"
    case analysisCalendarEmpty = "analysis.calendarEmpty"
    case analysisCalendarMonthPickerA11yLabel = "analysis.calendarMonthPicker.a11yLabel"
    case analysisCalendarMonthPickerA11yHint = "analysis.calendarMonthPicker.a11yHint"
    case analysisCalendarMonthPickerRestore = "analysis.calendarMonthPicker.restore"
    case analysisCalendarFutureDayA11yHint = "analysis.calendar.futureDay.a11yHint"
    case analysisCalendarMonthForwardDisabledA11yHint = "analysis.calendar.monthForward.disabled.a11yHint"
    case analysisCompareTitle = "analysis.compare.title"
    case analysisCompareEffective = "analysis.compare.effective"
    case analysisCompareIneffective = "analysis.compare.ineffective"
    case analysisCompareEffectiveRatio = "analysis.compare.effectiveRatio"
    case analysisCompareIneffectiveRatio = "analysis.compare.ineffectiveRatio"
    case analysisCompareDrainRatio = "analysis.compare.drainRatio"
    case analysisCompareMindBalanceEffectiveHeading = "analysis.compare.mindBalance.effectiveHeading"
    case analysisCompareMindBalanceIneffectiveHeading = "analysis.compare.mindBalance.ineffectiveHeading"
    case analysisCompareInsight = "analysis.compare.insight"
    case analysisCompareInsightHigh = "analysis.compare.insight.high"
    case analysisCompareInsightMid = "analysis.compare.insight.mid"
    case analysisCompareInsightLow = "analysis.compare.insight.low"
    case analysisCompareEmptyHint = "analysis.compare.emptyHint"
    case analysisDayBillsTitle = "analysis.dayBills.title"
    case analysisDayBillsEmpty = "analysis.dayBills.empty"
    case analysisDayBillsSummaryCount = "analysis.dayBills.summary.count"
    case analysisDayBillsSummaryTotal = "analysis.dayBills.summary.total"
    case analysisDayBillsHeroSpendToday = "analysis.dayBills.heroSpend.today"
    case analysisDayBillsHeroSpendDay = "analysis.dayBills.heroSpend.day"
    case analysisDayBillsGallerySummary = "analysis.dayBills.gallery.summary"
    case analysisReportGenerate = "analysis.report.generate"
    case analysisReportPickPeriodTitle = "analysis.report.pickPeriod.title"
    case analysisReportTitleForPeriod = "analysis.report.title.forPeriod"
    case analysisReportNavTitleForPeriod = "analysis.report.navTitle.forPeriod"
    case analysisReportHeroCaptionForPeriod = "analysis.report.hero.caption.forPeriod"
    case analysisReportNoDataForPeriod = "analysis.report.noData.forPeriod"
    case analysisReportCustomRangeRequired = "analysis.report.customRangeRequired"
    case analysisReportTitleDay = "analysis.report.title.day"
    case analysisReportTitleWeek = "analysis.report.title.week"
    case analysisReportTitleYear = "analysis.report.title.year"
    case analysisReportPosterTitleCustom = "analysis.report.title.custom"
    case analysisReportMonthOnlyHint = "analysis.report.monthOnlyHint"
    case analysisReportTitle = "analysis.report.title"
    case analysisReportSubtitle = "analysis.report.subtitle"
    case analysisReportPosterSubtitle = "analysis.report.poster.subtitle"
    case analysisReportHeroCaptionDay = "analysis.report.hero.caption.day"
    case analysisReportHeroCaptionWeek = "analysis.report.hero.caption.week"
    case analysisReportHeroCaptionMonth = "analysis.report.hero.caption.month"
    case analysisReportHeroCaptionYear = "analysis.report.hero.caption.year"
    case analysisReportHeroMetricCount = "analysis.report.hero.metric.count"
    case analysisReportHeroMetricCountValue = "analysis.report.hero.metric.countValue"
    case analysisReportHeroMetricTopMind = "analysis.report.hero.metric.topMind"
    case analysisReportHeroMetricEffectiveRatio = "analysis.report.hero.metric.effectiveRatio"
    case analysisReportHeroMetricEffectiveRatioHint = "analysis.report.hero.metric.effectiveRatio.hint"
    case analysisReportSpendStructure = "analysis.report.spendStructure"
    case analysisReportEmotionPaletteFootnote = "analysis.report.emotionPalette.footnote"
    case analysisReportGeneratedAt = "analysis.report.generatedAt"
    case analysisReportTotalExpense = "analysis.report.totalExpense"
    case analysisReportTotalCount = "analysis.report.totalCount"
    case analysisReportTopEmotion = "analysis.report.topEmotion"
    case analysisReportEffectiveRatio = "analysis.report.effectiveRatio"
    case analysisReportRulesTitle = "analysis.report.rulesTitle"
    case analysisReportWarmTipTitle = "analysis.report.warmTipTitle"
    case analysisReportExport = "analysis.report.export"
    case analysisReportShareImage = "analysis.report.shareImage"
    case analysisReportShareFailed = "analysis.report.shareFailed"
    case analysisReportNoData = "analysis.report.noData"
    case analysisReportEmotionPalette = "analysis.report.emotionPalette"
    case analysisReportPosterFooter = "analysis.report.posterFooter"
    case analysisReportPosterGeneratedAt = "analysis.report.poster.generatedAt"
    case analysisReportPosterAppStore = "analysis.report.poster.appStore"
    case analysisReportPosterGooglePlay = "analysis.report.poster.googlePlay"
    case analysisReportPosterDownloadCTA = "analysis.report.poster.downloadCTA"
    case analysisReportFilenameBase = "analysis.report.filename.base"
    case analysisEmotionTrendTitle = "analysis.emotionTrend.title"
    case analysisEmotionTrendWindowToday = "analysis.emotionTrend.window.today"
    case analysisEmotionTrendWindow7 = "analysis.emotionTrend.window.7"
    case analysisEmotionTrendWindow14 = "analysis.emotionTrend.window.14"
    case analysisEmotionTrendWindow30 = "analysis.emotionTrend.window.30"
    case analysisEmotionTrendWindow60 = "analysis.emotionTrend.window.60"
    case analysisEmotionTrendHintTodaySegment = "analysis.emotionTrend.hint.todaySegment"
    case analysisEmotionTrendHintLast7 = "analysis.emotionTrend.hint.last7"
    case analysisEmotionTrendHintLast14 = "analysis.emotionTrend.hint.last14"
    case analysisEmotionTrendHintLast30 = "analysis.emotionTrend.hint.last30"
    case analysisEmotionTrendHintLast60 = "analysis.emotionTrend.hint.last60"
    case analysisEmotionTrendBinHours = "analysis.emotionTrend.binHours"
    case analysisEmotionTrendLegendOther = "analysis.emotionTrend.legend.other"
    case analysisEmotionTrendEmptyHint = "analysis.emotionTrend.emptyHint"
    case analysisEmotionTrendInsightDominant = "analysis.emotionTrend.insight.dominant"
    case analysisEmotionTrendInsightPeak = "analysis.emotionTrend.insight.peak"
    case analysisEmotionTrendInsightEven = "analysis.emotionTrend.insight.even"
    case analysisHeatmapTitle = "analysis.heatmap.title"
    case analysisHeatmapSubtitleDay = "analysis.heatmap.subtitle.day"
    case analysisHeatmapSubtitleWeek = "analysis.heatmap.subtitle.week"
    case analysisHeatmapSubtitleMonth = "analysis.heatmap.subtitle.month"
    case analysisHeatmapSubtitleYear = "analysis.heatmap.subtitle.year"
    case analysisHeatmapMeasureAmount = "analysis.heatmap.measure.amount"
    case analysisHeatmapMeasureCount = "analysis.heatmap.measure.count"
    case analysisHeatmapGuideTitle = "analysis.heatmap.guide.title"
    case analysisHeatmapGuideSectionColor = "analysis.heatmap.guide.section.color"
    case analysisHeatmapGuideColorRule = "analysis.heatmap.guide.colorRule"
    case analysisHeatmapGuideSectionSize = "analysis.heatmap.guide.section.size"
    case analysisHeatmapGuideSizeRule = "analysis.heatmap.guide.sizeRule"
    case analysisHeatmapGuideSectionMeasure = "analysis.heatmap.guide.section.measure"
    case analysisHeatmapGuideMeasureRule = "analysis.heatmap.guide.measureRule"
    case analysisHeatmapGuideCustomEmotionNote = "analysis.heatmap.guide.customEmotionNote"
    case analysisHeatmapGuideReadingTitle = "analysis.heatmap.guide.readingTitle"
    case analysisHeatmapGuideReadingBody = "analysis.heatmap.guide.readingBody"
    case analysisChartGuideCustomNote = "analysis.chart.guide.customNote"
    case analysisHeatmapGuideOpenA11yLabel = "analysis.heatmap.guide.openA11yLabel"
    case analysisHeatmapGuideOpenA11yHint = "analysis.heatmap.guide.openA11yHint"
    case analysisDualEmotionTitle = "analysis.dualEmotion.title"
    case analysisDualEmotionSubtitle = "analysis.dualEmotion.subtitle"
    case analysisDualEmotionCountChart = "analysis.dualEmotion.countChart"
    case analysisDualEmotionAmountChart = "analysis.dualEmotion.amountChart"

    case analysisHeatRingTitle = "analysis.heatRing.title"
    case analysisHeatRingSubtitle = "analysis.heatRing.subtitle"
    case analysisHeatRingOther = "analysis.heatRing.other"
    case analysisHeatRingLegendAmount = "analysis.heatRing.legend.amount"
    case analysisHeatRingLegendCount = "analysis.heatRing.legend.count"
    case analysisHeatRingHabitInsight = "analysis.heatRing.habitInsight"
    case analysisHeatRingChipMetrics = "analysis.heatRing.chip.metrics"
    case analysisHeatRingChipPrimary = "analysis.heatRing.chip.primary"
    case analysisHeatRingChipSecondary = "analysis.heatRing.chip.secondary"
    case analysisHeatRingChipTxnCount = "analysis.heatRing.chip.txnCount"
    case analysisHeatRingChipA11y = "analysis.heatRing.chip.a11y"
    case analysisHeatRingGuideOverview = "analysis.heatRing.guide.overview"
    case analysisHeatRingGuideTitle = "analysis.heatRing.guide.title"
    case analysisHeatRingGuideSectionRing = "analysis.heatRing.guide.section.ring"
    case analysisHeatRingGuideRingBody = "analysis.heatRing.guide.ringBody"
    case analysisHeatRingGuideSectionChips = "analysis.heatRing.guide.section.chips"
    case analysisHeatRingGuideChipsBody = "analysis.heatRing.guide.chipsBody"
    case analysisHeatRingGuideSectionTopEmotions = "analysis.heatRing.guide.section.topEmotions"
    case analysisHeatRingGuideTopEmotionsBody = "analysis.heatRing.guide.topEmotionsBody"
    case analysisHeatRingGuideCustomEmotionNote = "analysis.heatRing.guide.customEmotionNote"
    case analysisHeatRingGuideOpenA11yLabel = "analysis.heatRing.guide.openA11yLabel"
    case analysisHeatRingGuideOpenA11yHint = "analysis.heatRing.guide.openA11yHint"
    case analysisHeatRingGuideReadingTitle = "analysis.heatRing.guide.readingTitle"
    case analysisHeatRingGuideReadingBody = "analysis.heatRing.guide.readingBody"

    case analysisCorrelationTitle = "analysis.correlation.title"
    case analysisCorrelationSubtitle = "analysis.correlation.subtitle"
    case analysisCorrelationEmptyHint = "analysis.correlation.emptyHint"
    case analysisCorrelationLegendExpense = "analysis.correlation.legend.expense"
    case analysisCorrelationLegendNegativity = "analysis.correlation.legend.negativity"
    case analysisCorrelationHowToRead = "analysis.correlation.howToRead"
    case analysisCorrelationWarmOverlap = "analysis.correlation.warmOverlap"
    case analysisCorrelationSelectHint = "analysis.correlation.selectHint"
    case analysisCorrelationBucketSummary = "analysis.correlation.bucketSummary"
    case analysisCorrelationOpenList = "analysis.correlation.openList"
    case analysisCorrelationClearSelection = "analysis.correlation.clearSelection"
    case analysisCorrelationGuideTitle = "analysis.correlation.guide.title"
    case analysisCorrelationGuideSectionRead = "analysis.correlation.guide.section.read"
    case analysisCorrelationGuideSectionInteract = "analysis.correlation.guide.section.interact"
    case analysisCorrelationGuideSectionInsight = "analysis.correlation.guide.section.insight"
    case analysisCorrelationGuideOpenA11yLabel = "analysis.correlation.guide.openA11yLabel"
    case analysisCorrelationGuideOpenA11yHint = "analysis.correlation.guide.openA11yHint"

    case recordDetailRetrospectiveAdd = "recordDetail.retrospective.add"
    case recordDetailRetrospectiveHint = "recordDetail.retrospective.hint"
    case recordDetailRetrospectiveResult = "recordDetail.retrospective.result"
    case recordDetailRetrospectiveButton = "recordDetail.retrospective.button"

    case analysisSpectrumTitleDay = "analysis.spectrum.title.day"
    case analysisSpectrumTitleWeek = "analysis.spectrum.title.week"
    case analysisSpectrumTitleMonth = "analysis.spectrum.title.month"
    case analysisSpectrumTitleYear = "analysis.spectrum.title.year"
    case analysisSpectrumSubtitle = "analysis.spectrum.subtitle"
    case analysisSpectrumInsightDayCalm = "analysis.spectrum.insight.day.calm"
    case analysisSpectrumInsightDayBalanced = "analysis.spectrum.insight.day.balanced"
    case analysisSpectrumInsightDayElevated = "analysis.spectrum.insight.day.elevated"
    case analysisSpectrumInsightWeekCalm = "analysis.spectrum.insight.week.calm"
    case analysisSpectrumInsightWeekBalanced = "analysis.spectrum.insight.week.balanced"
    case analysisSpectrumInsightWeekElevated = "analysis.spectrum.insight.week.elevated"
    case analysisSpectrumInsightMonthCalm = "analysis.spectrum.insight.month.calm"
    case analysisSpectrumInsightMonthBalanced = "analysis.spectrum.insight.month.balanced"
    case analysisSpectrumInsightMonthElevated = "analysis.spectrum.insight.month.elevated"
    case analysisSpectrumInsightYearCalm = "analysis.spectrum.insight.year.calm"
    case analysisSpectrumInsightYearBalanced = "analysis.spectrum.insight.year.balanced"
    case analysisSpectrumInsightYearElevated = "analysis.spectrum.insight.year.elevated"
    case analysisSpectrumGuideTitle = "analysis.spectrum.guide.title"
    case analysisSpectrumGuideSectionChart = "analysis.spectrum.guide.section.chart"
    case analysisSpectrumGuideChartBody = "analysis.spectrum.guide.chartBody"
    case analysisSpectrumGuideSectionEmptyBars = "analysis.spectrum.guide.section.emptyBars"
    case analysisSpectrumGuideEmptyBarsBody = "analysis.spectrum.guide.emptyBarsBody"
    case analysisSpectrumGuideSectionStrokeHeight = "analysis.spectrum.guide.section.strokeHeight"
    case analysisSpectrumGuideStrokeHeightBody = "analysis.spectrum.guide.strokeHeightBody"
    case analysisSpectrumGuideSectionPeriod = "analysis.spectrum.guide.section.period"
    case analysisSpectrumGuidePeriodDay = "analysis.spectrum.guide.period.day"
    case analysisSpectrumGuidePeriodWeek = "analysis.spectrum.guide.period.week"
    case analysisSpectrumGuidePeriodMonth = "analysis.spectrum.guide.period.month"
    case analysisSpectrumGuidePeriodYear = "analysis.spectrum.guide.period.year"
    case analysisSpectrumGuideSectionInsight = "analysis.spectrum.guide.section.insight"
    case analysisSpectrumGuideInsightBody = "analysis.spectrum.guide.insightBody"
    case analysisSpectrumGuideHomeContrast = "analysis.spectrum.guide.homeContrast"
    case analysisSpectrumGuideCustomEmotionNote = "analysis.spectrum.guide.customEmotionNote"
    case analysisSpectrumGuideReadingTitle = "analysis.spectrum.guide.readingTitle"
    case analysisSpectrumGuideReadingBody = "analysis.spectrum.guide.readingBody"
    case analysisSpectrumGuideOpenA11yLabel = "analysis.spectrum.guide.openA11yLabel"
    case analysisSpectrumGuideOpenA11yHint = "analysis.spectrum.guide.openA11yHint"

    case analysisRegretTitle = "analysis.regret.title"
    case analysisRegretSubtitle = "analysis.regret.subtitle"
    case analysisRegretEmpty = "analysis.regret.empty"
    case analysisRegretTapHint = "analysis.regret.tapHint"
    case analysisRegretChipCount = "analysis.regret.chipCount"
    case analysisRegretPickerEntryCount = "analysis.regret.picker.entryCount"
    case analysisRegretLegendWorthIt = "analysis.regret.legend.worthIt"
    case analysisRegretLegendNeutral = "analysis.regret.legend.neutral"
    case analysisRegretLegendRegret = "analysis.regret.legend.regret"
    case analysisRegretGuideTitle = "analysis.regret.guide.title"
    case analysisRegretGuideSectionSource = "analysis.regret.guide.section.source"
    case analysisRegretGuideSourceBody = "analysis.regret.guide.sourceBody"
    case analysisRegretGuideSectionAxes = "analysis.regret.guide.section.axes"
    case analysisRegretGuideAxesBody = "analysis.regret.guide.axesBody"
    case analysisRegretGuideSectionDotColor = "analysis.regret.guide.section.dotColor"
    case analysisRegretGuideSectionTags = "analysis.regret.guide.section.tags"
    case analysisRegretGuideTagsBody = "analysis.regret.guide.tagsBody"
    case analysisRegretGuideOpenA11yLabel = "analysis.regret.guide.openA11yLabel"
    case analysisRegretGuideOpenA11yHint = "analysis.regret.guide.openA11yHint"
    case analysisRegretGuideReadingTitle = "analysis.regret.guide.readingTitle"
    case analysisRegretGuideReadingBody = "analysis.regret.guide.readingBody"

    case retrospectiveTitle = "retrospective.title"
    case retrospectivePrompt = "retrospective.prompt"
    case retrospectiveWorthIt = "retrospective.worthIt"
    case retrospectiveNeutral = "retrospective.neutral"
    case retrospectiveRegret = "retrospective.regret"

    case notificationRetrospectiveTitle = "notification.retrospective.title"
    case notificationRetrospectiveBody = "notification.retrospective.body"
    case notificationRetrospectivePrompt = "notification.retrospective.prompt"
    case notificationActionRetrospective = "notification.action.retrospective"

    case mineTitle = "mine.title"
    case mineLanguage = "mine.language"
    case mineTheme = "mine.theme"
    case mineThemeSystem = "mine.theme.system"
    case mineThemeLight = "mine.theme.light"
    case mineThemeDark = "mine.theme.dark"
    case mineDays = "mine.days"
    case mineBackup = "mine.backup"
    case mineSectionBasic = "mine.section.basic"
    case mineFirstDayOfWeek = "mine.firstDayOfWeek"
    case mineFirstDayOfWeekMonday = "mine.firstDayOfWeek.monday"
    case mineFirstDayOfWeekSunday = "mine.firstDayOfWeek.sunday"
    case mineEmotionIconStyle = "mine.emotionIconStyle"
    case mineEmotionIconStyleRaster = "mine.emotionIconStyle.raster"
    case mineEmotionIconStyleSystem = "mine.emotionIconStyle.system"
    case mineSectionAdvanced = "mine.section.advanced"
    case mineSectionAbout = "mine.section.about"
    case mineAboutApp = "mine.about.app"
    case mineAboutHowToUse = "mine.about.howToUse"
    case mineAboutReviewOnboarding = "mine.about.reviewOnboarding"
    case aboutAppReviewOnboarding = "aboutApp.reviewOnboarding"

    case aboutAppNavTitle = "aboutApp.navTitle"
    case aboutAppBrandTagline = "aboutApp.brand.tagline"
    case aboutAppBrandSubtitle = "aboutApp.brand.subtitle"
    case aboutAppVersion = "aboutApp.version"
    case aboutAppContactEmail = "aboutApp.contactEmail"
    case aboutAppPrivacy = "aboutApp.privacy"
    case aboutAppTerms = "aboutApp.terms"
    case aboutAppShare = "aboutApp.share"
    case aboutAppShareMessage = "aboutApp.share.message"
    case aboutAppRate = "aboutApp.rate"
    case aboutAppComingSoonTitle = "aboutApp.comingSoon.title"
    case aboutAppComingSoonMessage = "aboutApp.comingSoon.message"
    case aboutAppComingSoonConfirm = "aboutApp.comingSoon.confirm"

    case paywallCloseA11y = "paywall.close.a11y"
    case paywallHeadlineGeneral = "paywall.headline.general"
    case paywallHeadlineMonthHistory = "paywall.headline.monthHistory"
    case paywallHeadlineYearView = "paywall.headline.yearView"
    case paywallHeadlineCustomRange = "paywall.headline.customRange"
    case paywallHeadlineRecordAttachments = "paywall.headline.recordAttachments"
    case paywallHeadlineBillTopExpense = "paywall.headline.billTopExpense"
    case paywallHeadlineEmotionTrend60Day = "paywall.headline.emotionTrend60Day"
    case paywallSubtitleGeneral = "paywall.subtitle.general"
    case paywallSubtitleMonthHistory = "paywall.subtitle.monthHistory"
    case paywallSubtitleYearView = "paywall.subtitle.yearView"
    case paywallSubtitleCustomRange = "paywall.subtitle.customRange"
    case paywallSubtitleRecordAttachments = "paywall.subtitle.recordAttachments"
    case paywallSubtitleBillTopExpense = "paywall.subtitle.billTopExpense"
    case paywallSubtitleEmotionTrend60Day = "paywall.subtitle.emotionTrend60Day"
    case paywallTileTimelineTitle = "paywall.tile.timeline.title"
    case paywallTileNotesPhotosTitle = "paywall.tile.notesPhotos.title"
    case paywallTileReportTitle = "paywall.tile.report.title"
    case paywallTileBillTopTitle = "paywall.tile.billTop.title"
    case paywallBulletTimeline = "paywall.bullet.timeline"
    case paywallBulletNotesPhotos = "paywall.bullet.notesPhotos"
    case paywallBulletReport = "paywall.bullet.report"
    case paywallBulletBillTop = "paywall.bullet.billTop"
    case paywallFreeIncludes = "paywall.freeIncludes"
    case paywallCtaUnlock = "paywall.cta.unlock"
    case paywallBestValue = "paywall.bestValue"
    case paywallPlanAnnualTitle = "paywall.plan.annual.title"
    case paywallPlanAnnualSubtitle = "paywall.plan.annual.subtitle"
    case paywallPlanLifetimeTitle = "paywall.plan.lifetime.title"
    case paywallPlanLifetimeSubtitle = "paywall.plan.lifetime.subtitle"
    case paywallPendingMessage = "paywall.pending.message"
    case paywallRestore = "paywall.restore"
    case paywallRestoreFailed = "paywall.restore.failed"
    case paywallLoadFailed = "paywall.load.failed"
    case paywallRetry = "paywall.retry"
    case paywallComplianceRenewal = "paywall.compliance.renewal"

    case mineProBannerUpgradeTitle = "mine.pro.banner.upgrade.title"
    case mineProBannerUpgradeSubtitle = "mine.pro.banner.upgrade.subtitle"
    case mineProBannerLearnMore = "mine.pro.banner.learnMore"
    case mineProBannerOwnedTitle = "mine.pro.banner.owned.title"
    case mineProBannerOwnedSubtitle = "mine.pro.banner.owned.subtitle"
    case mineProRestoreSuccess = "mine.pro.restore.success"

    case legalDocumentPrivacySubtitle = "legalDocument.privacy.subtitle"
    case legalDocumentTermsSubtitle = "legalDocument.terms.subtitle"
    case legalDocumentSupportSubtitle = "legalDocument.support.subtitle"
    case legalDocumentSupportTitle = "legalDocument.support.title"
    case legalDocumentUnavailableTitle = "legalDocument.unavailable.title"
    case legalDocumentUnavailableMessage = "legalDocument.unavailable.message"

    case onboardingBack = "onboarding.back"
    case onboardingDone = "onboarding.done"
    case onboardingCTA = "onboarding.cta"
    case onboardingPage1Title = "onboarding.page1.title"
    case onboardingPage1Body = "onboarding.page1.body"
    case onboardingPage2Title = "onboarding.page2.title"
    case onboardingPage2Body = "onboarding.page2.body"
    case onboardingPage3Title = "onboarding.page3.title"
    case onboardingPage3Body = "onboarding.page3.body"
    case onboardingPage4Title = "onboarding.page4.title"
    case onboardingPage4Body = "onboarding.page4.body"
    case onboardingPage5Title = "onboarding.page5.title"
    case onboardingPage5Body = "onboarding.page5.body"

    case howToUseNavTitle = "howToUse.navTitle"
    case howToUseHeaderTitle = "howToUse.header.title"
    case howToUseHeaderSubtitle = "howToUse.header.subtitle"
    case howToUseCardLedgerTitle = "howToUse.card.ledger.title"
    case howToUseCardLedgerBody = "howToUse.card.ledger.body"
    case howToUseCardHeatRingTitle = "howToUse.card.heatRing.title"
    case howToUseCardHeatRingBody = "howToUse.card.heatRing.body"
    case howToUseCardAlertsTitle = "howToUse.card.alerts.title"
    case howToUseCardAlertsBody = "howToUse.card.alerts.body"
    case howToUseCardCloudTitle = "howToUse.card.cloud.title"
    case howToUseCardCloudBody = "howToUse.card.cloud.body"
    case mineEmotionNotificationHub = "mine.emotionNotification.hub"
    case mineCurrencyHub = "mine.currency.hub"
    case mineCurrencySettingsTitle = "mine.currency.settingsTitle"
    case mineCurrencyFollowSystem = "mine.currency.followSystem"
    case mineDataManagementHub = "mine.dataManagement.hub"
    case mineDataDangerZone = "mine.data.dangerZone"
    case mineReminder = "mine.reminder"
    case mineAlertHighRiskOnly = "mine.alert.highRiskOnly"
    case mineAlertHighRiskOnlyHintOn = "mine.alert.highRiskOnly.hint.on"
    case mineAlertHighRiskOnlyHintOff = "mine.alert.highRiskOnly.hint.off"
    case mineAlertScope = "mine.alert.scope"
    case mineAlertCooldownTitle = "mine.alert.cooldownTitle"
    case mineAlertCooldownOption1 = "mine.alert.cooldown.option.1"
    case mineAlertCooldownOption3 = "mine.alert.cooldown.option.3"
    case mineAlertCooldownOption7 = "mine.alert.cooldown.option.7"
    case mineAlertCooldownHint = "mine.alert.cooldownHint"
    case mineExport = "mine.export"
    case mineComingSoon = "mine.comingSoon"
    case mineProductName = "mine.productName"
    case mineLanguageSystem = "mine.language.system"
    case mineLanguageChinese = "mine.language.zhHans"
    case mineLanguageTraditionalChinese = "mine.language.zhHant"
    case mineLanguageEnglish = "mine.language.en"
    case mineCloudSync = "mine.cloudSync"
    case mineAutoSync = "mine.autoSync"
    case mineCloudSyncDisabled = "mine.cloudSyncDisabled"
    case mineCloudSyncUserDisabled = "mine.cloudSync.userDisabled"
    case mineCloudSyncUserDisabledDetail = "mine.cloudSync.userDisabled.detail"
    case mineCloudSyncEnableConfirmTitle = "mine.cloudSync.enable.confirm.title"
    case mineCloudSyncEnableConfirmMessage = "mine.cloudSync.enable.confirm.message"
    case mineCloudSyncDisableConfirmTitle = "mine.cloudSync.disable.confirm.title"
    case mineCloudSyncDisableConfirmMessage = "mine.cloudSync.disable.confirm.message"
    case mineCloudSyncConfirmApply = "mine.cloudSync.confirm.apply"
    case mineCloudSyncRestartTitle = "mine.cloudSync.restart.title"
    case mineCloudSyncRestartMessage = "mine.cloudSync.restart.message"
    case mineCloudSyncSignInTitle = "mine.cloudSync.signIn.title"
    case mineCloudSyncSignInMessage = "mine.cloudSync.signIn.message"
    case mineCloudSyncUnavailable = "mine.cloudSync.unavailable"
    case mineCloudSyncSyncing = "mine.cloudSync.syncing"
    case mineCloudSyncActive = "mine.cloudSync.active"
    case mineCloudSyncActiveDetail = "mine.cloudSync.active.detail"
    case mineCloudSyncUnavailableHint = "mine.cloudSync.unavailable.hint"
    case mineCloudSyncLastSyncFormat = "mine.cloudSync.lastSync.format"
    case mineCloudSyncLastSyncNever = "mine.cloudSync.lastSync.never"
    case mineCloudSyncErrorTitle = "mine.cloudSync.error.title"
    case mineCloudSyncDismissError = "mine.cloudSync.dismiss.error"
    case mineCloudSyncOpenSettings = "mine.cloudSync.open.settings"
    case mineCloudSyncAccountNoAccount = "mine.cloudSync.account.noAccount"
    case mineCloudSyncAccountRestricted = "mine.cloudSync.account.restricted"
    case mineCloudSyncAccountTemporarilyUnavailable = "mine.cloudSync.account.temporarilyUnavailable"
    case mineCloudSyncAccountUnknown = "mine.cloudSync.account.unknown"
    case syncInitialImportTitle = "sync.initialImport.title"
    case syncInitialImportMessage = "sync.initialImport.message"
    case syncInitialImportSkip = "sync.initialImport.skip"
    case mineRuleTitle = "mine.rule.title"
    case mineReviewRuleFooter = "mine.reviewRule.footer"
    case mineRuleMinCount = "mine.rule.minCount"
    case mineRuleMinRatio = "mine.rule.minRatio"
    case mineRuleReset = "mine.rule.reset"
    case mineRuleCurrent = "mine.rule.current"
    case mineRuleModeRelaxed = "mine.rule.mode.relaxed"
    case mineRuleModeBalanced = "mine.rule.mode.balanced"
    case mineRuleModeStrict = "mine.rule.mode.strict"
    case mineRuleHintRelaxed = "mine.rule.hint.relaxed"
    case mineRuleHintBalanced = "mine.rule.hint.balanced"
    case mineRuleHintStrict = "mine.rule.hint.strict"
    case mineRulePreviewTitle = "mine.rule.preview.title"
    case mineRulePreviewCount = "mine.rule.preview.count"
    case mineRulePreviewFilter = "mine.rule.preview.filter"
    case mineRulePreviewHitTypes = "mine.rule.preview.hitTypes"
    case mineRuleFilterLow = "mine.rule.filter.low"
    case mineRuleFilterMid = "mine.rule.filter.mid"
    case mineRuleFilterHigh = "mine.rule.filter.high"
    case mineExportJSON = "mine.export.json"
    case mineExportCSV = "mine.export.csv"
    case mineImportBackup = "mine.import.backup"
    case mineImportSelect = "mine.import.select"
    case mineClearData = "mine.clearData"
    case mineClearDataConfirm = "mine.clearData.confirm"
    case mineClearDataMessage = "mine.clearData.message"
    case mineRestoreSuccess = "mine.restore.success"
    case mineRestoreFailed = "mine.restore.failed"
    case mineRestoreInvalid = "mine.restore.invalid"
    case mineRestoreModeTitle = "mine.restore.mode.title"
    case mineRestoreModeMerge = "mine.restore.mode.merge"
    case mineRestoreModeReplace = "mine.restore.mode.replace"
    case mineRestoreReplaceConfirmTitle = "mine.restore.replaceConfirm.title"
    case mineRestoreReplaceConfirmMessage = "mine.restore.replaceConfirm.message"
    case mineRestorePreview = "mine.restore.preview"
    case mineRestorePreviewProfileYes = "mine.restore.preview.profile.yes"
    case mineRestorePreviewProfileNo = "mine.restore.preview.profile.no"
    case mineRestorePreviewNoData = "mine.restore.preview.noData"
    case mineBackupScope = "mine.backup.scope"
    case mineExportFailed = "mine.export.failed"
    case mineExportFilenameBackupBase = "mine.export.filename.backup.base"
    case mineExportFilenameBillsBase = "mine.export.filename.bills.base"
    case mineRuleTypeWeekday = "mine.rule.type.weekday"
    case mineRuleTypeTime = "mine.rule.type.time"
    case mineRuleTypeCategory = "mine.rule.type.category"
    case mineRuleTypeNone = "mine.rule.type.none"
    case mineDisplayNamePlaceholder = "mine.displayName.placeholder"
    case mineDisplayNameHint = "mine.displayName.hint"
    case mineDisplayNameInvalid = "mine.displayName.invalid"
    case mineAvatarAlbum = "mine.avatar.album"
    case mineAvatarPreset = "mine.avatar.preset"
    case mineAvatarReset = "mine.avatar.reset"
    case mineAvatarPresetTitle = "mine.avatar.preset.title"
    case mineAvatarPresetSubtitle = "mine.avatar.preset.subtitle"
    case mineAvatarPresetDefault = "mine.avatar.preset.default"
    case mineAvatarLoadFailed = "mine.avatar.loadFailed"
    case mineAvatarEditTitle = "mine.avatar.edit.title"
    case mineAvatarSelectTitle = "mine.avatar.select.title"
    case mineAvatarDone = "mine.avatar.done"
    case mineAvatarCustomPhoto = "mine.avatar.customPhoto"
    case mineAvatarAlbumSelectTitle = "mine.avatar.album.selectTitle"
    case mineAvatarAlbumSelectHint = "mine.avatar.album.selectHint"
    case mineProfileNickname = "mine.profile.nickname"
    case mineHeroCardTitle = "mine.hero.cardTitle"
    case mineProfileStatsLine = "mine.profile.statsLine"
    case alertTitle = "alert.title"
    case alertTemplate = "alert.template"

    case typeExpense = "type.expense"
    case typeIncome = "type.income"

    case emotionPamper = "emotion.pamper"
    case emotionNecessity = "emotion.necessity"
    case emotionImpulse = "emotion.impulse"
    case emotionStress = "emotion.stress"
    case emotionSocial = "emotion.social"
    case emotionRitual = "emotion.ritual"
    case emotionShortPamper = "emotion.short.pamper"
    case emotionShortNecessity = "emotion.short.necessity"
    case emotionShortImpulse = "emotion.short.impulse"
    case emotionShortStress = "emotion.short.stress"
    case emotionShortSocial = "emotion.short.social"
    case emotionShortRitual = "emotion.short.ritual"

    case categoryFood = "category.food"
    case categoryDaily = "category.daily"
    case categoryTransport = "category.transport"
    case categoryDigital = "category.digital"
    case categoryPet = "category.pet"
    case categoryTravel = "category.travel"
    case categoryClothing = "category.clothing"
    case categoryEntertainment = "category.entertainment"
    case categorySocial = "category.social"
    case categoryMedical = "category.medical"
    case categoryLearning = "category.learning"
    case categoryHousing = "category.housing"
    case categoryOther = "category.other"
    case categoryShortFood = "category.short.food"
    case categoryShortDaily = "category.short.daily"
    case categoryShortTransport = "category.short.transport"
    case categoryShortDigital = "category.short.digital"
    case categoryShortPet = "category.short.pet"
    case categoryShortTravel = "category.short.travel"
    case categoryShortClothing = "category.short.clothing"
    case categoryShortEntertainment = "category.short.entertainment"
    case categoryShortSocial = "category.short.social"
    case categoryShortMedical = "category.short.medical"
    case categoryShortLearning = "category.short.learning"
    case categoryShortHousing = "category.short.housing"
    case categoryShortOther = "category.short.other"
}

@MainActor
final class LocalizationManager: ObservableObject {
    private static let persistedLanguageKey = "AfterBuy.appLanguage"

    private var modelContext: ModelContext?
    private var isApplyingRemoteValues = false

    @Published var language: AppLanguage = AppLanguage.defaultPreference {
        didSet {
            guard !isApplyingRemoteValues else {
                reloadActiveTable()
                return
            }
            persistLanguageIfNeeded()
            reloadActiveTable()
        }
    }
    @Published private var activeTable: [String: String] = [:]
    private var englishTable: [String: String] = [:]

    var effectiveLanguage: AppLanguage { language.resolved }

    var locale: Locale { effectiveLanguage.locale }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.persistedLanguageKey),
           let restored = AppLanguage(rawValue: raw) {
            language = restored
        } else {
            language = AppLanguage.defaultPreference
        }
        englishTable = LocalizationFileLoader.load(language: .en) ?? [:]
        reloadActiveTable()
        logLocalizationIntegrity()
    }

    func configure(modelContext: ModelContext) {
        guard self.modelContext == nil else { return }
        self.modelContext = modelContext
        PersistenceController.shared.configure(modelContext)

        isApplyingRemoteValues = true
        if let preferences = try? PreferencesRepository.fetchOrCreate(in: modelContext),
           let restored = AppLanguage(rawValue: preferences.languageRaw) {
            language = restored
        }
        isApplyingRemoteValues = false
    }

    func reloadFromSwiftData() {
        guard let modelContext else { return }
        isApplyingRemoteValues = true
        if let preferences = try? PreferencesRepository.fetchOrCreate(in: modelContext),
           let restored = AppLanguage(rawValue: preferences.languageRaw) {
            language = restored
        }
        isApplyingRemoteValues = false
    }

    private func persistLanguageIfNeeded() {
        guard let modelContext else {
            UserDefaults.standard.set(language.rawValue, forKey: Self.persistedLanguageKey)
            return
        }
        guard let preferences = try? PreferencesRepository.fetchOrCreate(in: modelContext) else { return }
        preferences.languageRaw = language.rawValue
        try? PreferencesRepository.save(preferences, in: modelContext)
    }

    func text(_ key: LKey) -> String {
        activeTable[key.rawValue]
        ?? englishTable[key.rawValue]
        ?? LocalizationFallbackTable.table[.en]?[key.rawValue]
        ?? key.rawValue
    }

    func refreshIfFollowingSystem() {
        guard language == .system else { return }
        reloadActiveTable()
    }

    private func reloadActiveTable() {
        let effective = language.resolved
        let fallback = LocalizationFallbackTable.table[effective] ?? [:]
        let fromFile = LocalizationFileLoader.load(language: effective)
        activeTable = fallback.merging(fromFile ?? [:]) { _, new in new }
    }

    private func logLocalizationIntegrity() {
        let allKeys = Set(LKey.allCases.map(\.rawValue))
        let zhFileKeys = Set((LocalizationFileLoader.load(language: .zhHans) ?? [:]).keys)
        let enFileKeys = Set((LocalizationFileLoader.load(language: .en) ?? [:]).keys)
        let zhFallbackKeys = Set((LocalizationFallbackTable.table[.zhHans] ?? [:]).keys)
        let enFallbackKeys = Set((LocalizationFallbackTable.table[.en] ?? [:]).keys)

        let zhMerged = zhFallbackKeys.union(zhFileKeys)
        let enMerged = enFallbackKeys.union(enFileKeys)
        let missingZH = allKeys.subtracting(zhMerged).count
        let missingEN = allKeys.subtracting(enMerged).count

        #if DEBUG
        guard missingZH > 0 || missingEN > 0 else { return }
        print(
            "Localization integrity -> total:\(allKeys.count), " +
            "bundle zh-Hans:\(zhFileKeys.count), bundle en:\(enFileKeys.count), " +
            "missing zh-Hans:\(missingZH), missing en:\(missingEN)"
        )
        #endif
    }
}

private enum LocalizationFileLoader {
    static func load(language: AppLanguage) -> [String: String]? {
        let candidates: [URL?] = [
            Bundle.main.url(
                forResource: language.rawValue,
                withExtension: "json",
                subdirectory: "Localization"
            ),
            Bundle.main.url(forResource: language.rawValue, withExtension: "json")
        ]

        guard let url = candidates.compactMap({ $0 }).first else {
            return nil
        }

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? JSONDecoder().decode([String: String].self, from: data)
    }
}

enum LocalizationFallbackTable {
    static let table: [AppLanguage: [String: String]] = [
        .zhHans: [
            "analysis.calendarEmpty": "当月暂无消费记录",
            "analysis.calendarMonthPicker.a11yHint": "滚动年份与月份即可切换日历；点「恢复」或下滑关闭可回到进入前的月份；点「完成」保留当前选择。",
            "analysis.calendarMonthPicker.a11yLabel": "选择月份与年份",
            "analysis.calendarMonthPicker.restore": "恢复",
            "analysis.calendar.futureDay.a11yHint": "未来日期不可查看",
            "analysis.calendar.monthForward.disabled.a11yHint": "已是当前月份，无法切换到未来",
            "analysis.calendarTitle": "每日消费心情日历",
            "analysis.compare.effective": "取悦自己 + 仪式感",
            "analysis.compare.effectiveRatio": "有效占比：%@",
            "analysis.compare.ineffective": "冲动 + 解压 + 面子",
            "analysis.compare.ineffectiveRatio": "无效占比：%@",
            "analysis.compare.drainRatio": "内耗占比：%@",
            "analysis.compare.mindBalance.effectiveHeading": "✨ (取悦+仪式感)",
            "analysis.compare.mindBalance.ineffectiveHeading": "🔥 (冲动+解压+面子)",
            "analysis.compare.insight": "真正让你获得长久快乐的消费占比",
            "analysis.compare.insight.high": "你这段时间花钱更贴近真实需求，状态很稳。",
            "analysis.compare.insight.low": "最近情绪性消费偏多，给自己一点慢下来的空间会更好。",
            "analysis.compare.insight.mid": "你正在平衡“情绪释放”和“真实快乐”，继续保持觉察。",
            "analysis.compare.title": "有效快乐消费 VS 无效情绪消费",
            "analysis.dayBills.empty": "当日暂无账单",
            "analysis.dayBills.gallery.summary": "共 %1$d 笔，合计 %2$@",
            "analysis.dayBills.summary.count": "笔数",
            "analysis.dayBills.summary.total": "总额",
            "analysis.dayBills.title": "当日账单",
            "analysis.distribution": "情绪消费分布",
            "analysis.distribution.emptyHint": "可尝试切换日/周/月/年筛选查看趋势。",
            "analysis.emotionTrend.title": "情绪支出结构走势",
            "analysis.emotionTrend.window.today": "今",
            "analysis.emotionTrend.window.7": "7天",
            "analysis.emotionTrend.window.14": "14天",
            "analysis.emotionTrend.window.30": "30天",
            "analysis.emotionTrend.window.60": "60天",
            "analysis.emotionTrend.hint.todaySegment": "按今日 4 小时分段",
            "analysis.emotionTrend.hint.last7": "最近 7 天 · 按日",
            "analysis.emotionTrend.hint.last14": "最近 14 天 · 按日",
            "analysis.emotionTrend.hint.last30": "最近 30 天 · 按日",
            "analysis.emotionTrend.hint.last60": "最近 60 天 · 按日",
            "analysis.emotionTrend.binHours": "%@–%@ 时",
            "analysis.emotionTrend.legend.other": "其他",
            "analysis.emotionTrend.emptyHint": "本期暂无支出记录，记一笔后即可查看走势。",
            "analysis.emotionTrend.insight.dominant": "「%1$@」约占本期情绪支出的 %2$@，是当前主力情绪消费。",
            "analysis.emotionTrend.insight.peak": "「%1$@」情绪支出合计 %2$@，为当前周期内的相对高点。",
            "analysis.emotionTrend.insight.even": "各时段情绪支出较分散，没有特别突出的单点高峰。",
            "analysis.heatmap.title": "消费时段热力",
            "analysis.heatmap.subtitle.day": "今日 · 星期 × 时段",
            "analysis.heatmap.subtitle.week": "本周 · 星期 × 时段",
            "analysis.heatmap.subtitle.month": "本月 · 星期 × 时段",
            "analysis.heatmap.subtitle.year": "本年 · 星期 × 时段",
            "analysis.heatmap.measure.amount": "金额",
            "analysis.heatmap.measure.count": "笔数",
            "analysis.heatmap.guide.title": "消费时段热力说明",
            "analysis.heatmap.guide.section.color": "颜色",
            "analysis.heatmap.guide.colorRule": "每个圆点的颜色，对应该星期×时段内按金额占比最高的记账情绪。",
            "analysis.heatmap.guide.section.size": "圆的大小",
            "analysis.heatmap.guide.sizeRule": "圆越大，表示该格在本筛选周期内的消费金额（或笔数）相对越高；无消费时仅显示极小灰点。",
            "analysis.heatmap.guide.section.measure": "金额与笔数",
            "analysis.heatmap.guide.measureRule": "右上角可切换「金额」或「笔数」；切换后圆的大小按所选维度重新计算，颜色规则不变。",
            "analysis.heatmap.guide.customEmotionNote": "自定义心情使用记一笔时所选的颜色。",
            "analysis.heatmap.guide.openA11yLabel": "图表说明",
            "analysis.heatmap.guide.openA11yHint": "打开消费时段热力的颜色与读图说明",
            "analysis.dualEmotion.title": "各情绪笔数与金额",
            "analysis.dualEmotion.subtitle": "与上图相同时间范围 · Top 5 与其他",
            "analysis.dualEmotion.countChart": "笔数",
            "analysis.dualEmotion.amountChart": "金额（元）",
            "analysis.overview": "本月消费总览",
            "analysis.overview.day": "今日消费总览",
            "analysis.overview.week": "本周消费总览",
            "analysis.overview.month": "本月消费总览",
            "analysis.overview.year": "本年消费总览",
            "analysis.dashboard.distress.title": "情绪内耗",
            "analysis.dashboard.fulfillment.title": "内心充实",
            "analysis.dashboard.entries": "笔",
            "analysis.dashboard.distress.share": "本期占比 %1$@%%",
            "analysis.dashboard.distress.share.a11y": "情绪内耗占本期支出 %1$@%%",
            "analysis.dashboard.distress.scale.a11y": "情绪内耗占比 %1$@/10",
            "analysis.dashboard.positiveRateDelta.up": "↑ 正向率较%2$@ +%1$@%%",
            "analysis.dashboard.positiveRateDelta.down": "↓ 正向率较%2$@ %1$@%%",
            "analysis.dashboard.positiveRateDelta.flat": "较%@ 正向率持平",
            "analysis.dashboard.positiveRateDelta.unavailable": "较%@ 正向率 —",
            "analysis.metric.expense.title": "本期总支出",
            "analysis.metric.count.title": "本期消费笔数",
            "analysis.metric.count.value": "%@ 笔",
            "analysis.metric.expense.title.day": "今日总支出",
            "analysis.metric.expense.title.week": "本周总支出",
            "analysis.metric.expense.title.month": "本月总支出",
            "analysis.metric.expense.title.year": "本年总支出",
            "analysis.metric.count.title.day": "今日消费笔数",
            "analysis.metric.count.title.week": "本周消费笔数",
            "analysis.metric.count.title.month": "本月消费笔数",
            "analysis.metric.count.title.year": "本年消费笔数",
            "analysis.totalCount": "共 %@ 笔消费",
            "analysis.pattern.fallback": "当前样本较少，继续记录几笔后会生成更清晰的规律。",
            "analysis.pattern.generated": "你在%@更容易产生%@消费，共%@笔。",
            "analysis.pattern.rule.category": "你本期在“%@”类目消费最多（%@笔）。",
            "analysis.pattern.rule.time": "你在%@消费更集中（%@笔）。",
            "analysis.pattern.rule.weekday": "你在%@消费更频繁（%@笔）。",
            "analysis.pattern.ineffectiveShareLabel": "本期无效情绪消费占比",
            "analysis.pattern.badge.category": "%@最多",
            "analysis.pattern.badge.time": "%@消费集中",
            "analysis.pattern.badge.weekday": "%@更频繁",
            "analysis.pattern.badge.count": "%@笔",
            "analysis.pattern.prescription.pause": "建议下次下单前先停 30 秒，问问自己是否真的需要。",
            "analysis.pattern.prescription.mid": "你正在调整中，保持记录会更容易看到变化。",
            "analysis.pattern.prescription.low": "你的消费节奏很稳，继续保持这种觉察感。",
            "analysis.patternTip": "根据你的记账数据，正在发现专属消费习惯",
            "analysis.patternTitle": "你的消费小规律",
            "analysis.report.effectiveRatio": "有效快乐消费占比",
            "analysis.report.emotionPalette": "本期心情花费 Top 3（占总额）",
            "analysis.report.emotionPalette.footnote": "其余心情合计约 %@（仅展示金额最高的 3 项）",
            "analysis.report.spendStructure": "占本期总支出：%@ %@ · %@ %@ · %@ %@",
            "analysis.report.hero.metric.effectiveRatio.hint": "占非刚需内",
            "analysis.report.export": "导出报告文本",
            "analysis.report.generate": "生成情绪消费报告",
            "analysis.report.pickPeriod.title": "选择报告周期",
            "analysis.report.title.forPeriod": "%@ 情绪消费报告",
            "analysis.report.navTitle.forPeriod": "%@",
            "analysis.report.hero.caption.forPeriod": "%@ 情绪资金变动",
            "analysis.report.noData.forPeriod": "%@ 暂无支出记录，记一笔后即可生成报告。",
            "analysis.report.customRangeRequired": "请先选择自定义区间后再生成报告。",
            "analysis.report.title.day": "今日情绪消费报告",
            "analysis.report.title.week": "本周情绪消费报告",
            "analysis.report.title.year": "本年情绪消费报告",
            "analysis.report.title.custom": "情绪消费报告",
            "analysis.report.monthOnlyHint": "仅支持月度报告，请切换到“月”",
            "analysis.report.generatedAt": "生成时间",
            "analysis.report.noData": "所选周期暂无支出记录，记一笔后即可生成报告。",
            "analysis.report.posterFooter": "花钱了 | 记的不仅是花销，更是花钱时的心情",
            "analysis.report.poster.generatedAt": "生成时间：%@",
            "analysis.report.poster.appStore": "App Store",
            "analysis.report.poster.googlePlay": "Google Play",
            "analysis.report.poster.downloadCTA": "即刻下载，倾听内心涟漪",
            "analysis.report.rulesTitle": "本期规律摘要",
            "analysis.report.shareFailed": "分享图片生成失败，请稍后重试。",
            "analysis.report.shareImage": "分享报告图片",
            "analysis.report.subtitle": "这是你的专属情绪消费账单，读懂自己，理性花钱，快乐生活",
            "analysis.report.poster.subtitle": "记的不仅是花销，更是花钱时的心情",
            "analysis.report.title": "本月情绪消费报告",
            "analysis.report.topEmotion": "本期TOP情绪",
            "analysis.report.totalCount": "本期消费笔数",
            "analysis.report.totalExpense": "本期总支出",
            "analysis.report.warmTipTitle": "温柔提醒",
            "analysis.subtitle": "看懂你的钱，都花在了哪一种情绪里",
            "analysis.time.afternoon": "下午",
            "analysis.time.evening": "晚上",
            "analysis.time.morning": "上午",
            "analysis.time.night": "深夜",
            "analysis.title": "情绪复盘",
            "analysis.topEmotion": "本期情绪消费 TOP1",
            "analysis.totalExpense": "本期总支出",
            "analysis.warm.generated.high": "在除刚需外的消费里，无效情绪消费约占 %@（有效快乐约 %@）。本期刚需必要约占总额的 %@。建议下次下单前先停 30 秒，问问自己是否真的需要。",
            "analysis.warm.generated.low": "在除刚需外的消费里，无效情绪消费约占 %@（有效快乐约 %@）。本期刚需必要约占总额的 %@。你的消费节奏很稳，继续保持这种觉察感。",
            "analysis.warm.generated.mid": "在除刚需外的消费里，无效情绪消费约占 %@（有效快乐约 %@）。本期刚需必要约占总额的 %@。你正在调整中，保持记录会更容易看到变化。",
            "analysis.warmLine": "消费不求节俭到底，只求每一笔都花得心甘情愿",
            "alert.template": "近7天你有%@消费 %@ 笔，共%@。慢下来想想，这笔钱是否真的想花。",
            "alert.title": "小暖心提醒",
            "bills.edit": "编辑",
            "bills.emptyTip": "暂无账单，点下方 + 记一笔吧",
            "bills.filter.day": "日",
            "bills.filter.month": "月",
            "bills.filter.week": "周",
            "bills.filter.year": "年",
            "bills.title": "账单列表",
            "bills.metric.expense.title.day": "今日总支出",
            "bills.metric.expense.title.week": "本周总支出",
            "bills.metric.expense.title.month": "本月总支出",
            "bills.metric.expense.title.year": "本年总支出",
            "bills.metric.count.title.day": "今日消费笔数",
            "bills.metric.count.title.week": "本周消费笔数",
            "bills.metric.count.title.month": "本月消费笔数",
            "bills.metric.count.title.year": "本年消费笔数",
            "bills.metric.count.value": "%@ 笔",
            "bills.dashboard.totalSpent.day": "今日总支出",
            "bills.dashboard.totalSpent.week": "本周总支出",
            "bills.dashboard.totalSpent.month": "本月总支出",
            "bills.dashboard.totalSpent.year": "本年总支出",
            "bills.dashboard.frequency.day": "今日消费频次",
            "bills.dashboard.frequency.week": "本周消费频次",
            "bills.dashboard.frequency.month": "本月消费频次",
            "bills.dashboard.frequency.year": "本年消费频次",
            "bills.dashboard.entries": "笔",
            "bills.dashboard.comparePeriod.day": "昨日",
            "bills.dashboard.comparePeriod.week": "上周",
            "bills.dashboard.comparePeriod.month": "上月",
            "bills.dashboard.comparePeriod.year": "去年",
            "bills.dashboard.expenseDelta.up": "↑ 较%2$@ +%1$@%%",
            "bills.dashboard.expenseDelta.down": "↓ 较%2$@ %1$@%%",
            "bills.dashboard.expenseDelta.flat": "较%@ 持平",
            "bills.dashboard.expenseDelta.unavailable": "较%@ —",
            "bills.dashboard.freqDelta.up": "↑ 较%2$@ +%1$@笔",
            "bills.dashboard.freqDelta.down": "↓ 较%2$@ %1$@笔",
            "bills.dashboard.freqDelta.flat": "较%@ 持平",
            "bills.dashboard.freqDelta.unavailable": "较%@ —",
            "bills.dashboard.sparkline.a11y": "本期支出走势",
            "bills.insight.periodPrefix.day": "今日截止目前",
            "bills.insight.periodPrefix.week": "本周截止目前",
            "bills.insight.periodPrefix.month": "本月截止目前",
            "bills.insight.periodPrefix.year": "本年截止目前",
            "bills.insight.custom.clause.range": "在 %1$d年%2$02d月–%3$02d月 这段区间里，",
            "bills.insight.custom.clause.singleMonth": "在 %1$d年%2$02d月 这一月里，",
            "bills.insight.custom.rangeLabel.range": "%1$d年%2$02d月–%3$02d月",
            "bills.insight.custom.rangeLabel.singleMonth": "%1$d年%2$02d月",
            "bills.insight.categoryShare.dominant.custom": "%1$@「%2$@」约占支出的 %3$@%%，是这段区间的大头。",
            "bills.insight.categoryShare.selected.custom": "%1$@你在「%2$@」上的开销已超过 %3$@%%。",
            "bills.insight.categoryShare.selectedMany": "你筛选的「%1$@」等 %2$@ 类合计约占 %3$@%%。",
            "bills.insight.categoryShare.selectedMany.custom": "%1$@你筛选的「%2$@」等 %3$@ 类合计约占 %4$@%%。",
            "bills.insight.compare.up.custom": "较上一段同等区间（%2$@），支出高出约 %1$@%%。",
            "bills.insight.compare.down.custom": "较上一段同等区间（%1$@），支出有所下降。",
            "bills.insight.empty.day": "今天尚未记账，看来是精打细算的一天。",
            "bills.insight.categoryShare.selected": "%3$@，你在「%1$@」上的开销已超过 %2$@%%。",
            "bills.insight.categoryShare.dominant": "%3$@，「%1$@」约占支出的 %2$@%%，是本期大头。",
            "bills.insight.trend.flat": "%1$@支出整体平缓，继续保持哦。",
            "bills.insight.trend.rising": "%1$@支出略有抬头，可以留意一下节奏。",
            "bills.insight.trend.falling": "%1$@支出在回落，节奏更从容了。",
            "bills.insight.compare.up": "较%2$@同期，本期支出高出约 %1$@%%。",
            "bills.insight.compare.down": "较%@同期，支出有所下降。",
            "bills.insight.fallback": "继续保持记账，趋势会越来越清晰。",
            "bills.dashboard.scale.a11y": "相对上期进度 %1$@/10",
            "bills.filter.category.label": "类目",
            "bills.filter.category.summaryMany": "%1$@ 等 %2$@ 类",
            "bills.filter.emotion.label": "心情",
            "bills.filtered.empty.title": "当前筛选下暂无账单",
            "bills.filtered.empty.hint": "可调整类目或心情，或清除筛选查看本周期全部消费。",
            "bills.clearFilters": "清除筛选",
            "bills.filter.sheetTitle": "筛选",
            "bills.filter.sheet.reset": "重置",
            "bills.filter.entry.a11yHint": "点按日周月年右侧的筛选图标，选择类目与心情。",
            "bills.metricDetail.title.expense": "总支出洞察",
            "bills.metricDetail.title.frequency": "消费频次洞察",
            "bills.metricDetail.necessary.title": "真实生活硬性成本",
            "bills.metricDetail.necessary.label": "硬性刚需",
            "bills.metricDetail.premium.label": "情绪溢价",
            "bills.metricDetail.necessary.summary": "硬性刚需开销 %1$@，其余 %2$@ 属于情绪溢价。",
            "bills.metricDetail.stability.solid": "你的财务底盘非常稳固。",
            "bills.metricDetail.stability.trim": "非刚需占比偏高，建议适当精简情绪性支出。",
            "bills.metricDetail.top3.title": "本期账单 Top 3 天花板",
            "bills.metricDetail.top3.empty": "当前筛选下暂无支出记录。",
            "bills.metricDetail.top.rank": "TOP %lld",
            "bills.metricDetail.pro.lockHint": "升级 Pro，解锁 Top 2、Top 3 完整榜单与逐笔下钻",
            "bills.metricDetail.avgTicket.title": "平均客单价",
            "bills.metricDetail.avgTicket.micro": "微观高频",
            "bills.metricDetail.avgTicket.steady": "稳健平稳",
            "bills.metricDetail.avgTicket.large": "大额少次",
            "bills.metricDetail.peakTime.title": "高频消费时段",
            "bills.metricDetail.peakTime.body": "你最容易在 %@ 集中下单。",
            "bills.metricDetail.peakTime.unavailable": "当前数据不足以识别时段规律。",
            "bills.metricDetail.frequency.empty": "当前筛选下暂无消费笔数。",
            "bills.metricDetail.dashboard.expense.a11yHint": "查看总支出洞察",
            "bills.metricDetail.dashboard.frequency.a11yHint": "查看消费频次洞察",
            "bills.row.attachment.both": "含备注及照片或小票",
            "bills.row.attachment.note": "含备注",
            "bills.row.attachment.photo": "含照片或小票",
            "category.clothing": "服饰美妆",
            "category.daily": "日常百货",
            "category.entertainment": "娱乐休闲",
            "category.food": "餐饮美食",
            "category.housing": "住房水电",
            "category.learning": "学习提升",
            "category.medical": "医疗健康",
            "category.other": "其他开销",
            "category.digital": "数码",
            "category.pet": "宠物",
            "category.social": "社交人情",
            "category.travel": "旅行",
            "category.transport": "交通出行",
            "category.short.clothing": "服饰美妆",
            "category.short.daily": "日常百货",
            "category.short.digital": "数码",
            "category.short.entertainment": "娱乐休闲",
            "category.short.food": "餐饮美食",
            "category.short.housing": "住房水电",
            "category.short.learning": "学习提升",
            "category.short.medical": "医疗健康",
            "category.short.other": "其他开销",
            "category.short.pet": "宠物",
            "category.short.social": "社交人情",
            "category.short.travel": "旅行",
            "category.short.transport": "交通出行",
            "common.all": "全部",
            "common.cancel": "取消",
            "common.ok": "好",
            "common.done": "完成",
            "common.delete": "删除",
            "common.expense": "支出",
            "common.income": "收入",
            "common.noData": "暂无数据",
            "common.save": "保存",
            "common.today": "今日",
            "emotion.impulse": "冲动消费",
            "emotion.necessity": "刚需必要",
            "emotion.pamper": "取悦自己",
            "emotion.ritual": "仪式感",
            "emotion.social": "面子社交",
            "emotion.stress": "解压发泄",
            "emotion.short.impulse": "冲动消费",
            "emotion.short.necessity": "刚需必要",
            "emotion.short.pamper": "取悦自己",
            "emotion.short.ritual": "仪式感",
            "emotion.short.social": "面子社交",
            "emotion.short.stress": "解压发泄",
            "home.alert.noRisk": "最近一周状态很稳，继续保持觉察消费。",
            "home.alertTitle": "近期情绪消费提醒",
            "home.emotionFilter.all": "全部情绪",
            "home.emptyTip": "暂无记账记录，点下方 + 记一笔吧",
            "home.emotionShare.title": "情绪支出占比",
            "home.emotionShare.subtitle": "基于全部历史支出",
            "home.emotionShare.emptyHint": "尚无支出记录时可前往「记一笔」添加。",
            "home.emotionShare.scopeWeek": "本周支出",
            "home.emotionShare.dominant": "主导：%1$@ · %2$@%%",
            "home.emotionShare.dominantEmpty": "本周暂无支出",
            "home.today.peaceTitle": "今天内心很平静",
            "home.today.peaceTitle.compact": "今日安好",
            "home.today.peaceSubtitle": "今日尚无支出记录",
            "home.today.impulseStressSummary": "今日冲动/解压 %1$@ 笔 · %2$@",
            "home.sparkline.title": "近7天情绪支出",
            "home.sparkline.title.compact": "近7天情绪支出",
            "home.sparkline.hintEmpty": "近7天暂无情绪性支出",
            "home.emotionShare.compact.title": "自首次记录至今",
            "home.emotionShare.compact.a11y": "自首次记录至今的情绪支出分布，点按前往分析。",
            "home.emotionShare30d.title": "近30天情绪",
            "home.emotionShare30d.dominant": "%@居多",
            "home.emotionShare30d.scattered": "情绪较分散",
            "home.emotionShare30d.scattered.compact": "情绪较分散",
            "home.emotionShare30d.empty": "近30天暂无支出",
            "home.emotionShare30d.a11y": "近30天情绪，%@，点按前往分析。",
            "home.quickAdd": "记一笔",
            "home.recentRecords": "今日消费明细",
            "home.recentActivity": "最新动态",
            "home.searchPlaceholder": "搜索类目、备注或情绪",
            "home.action.add": "记一笔",
            "home.action.calendar": "情绪日历",
            "home.action.more": "更多",
            "home.action.weekTrend": "本周趋势",
            "home.effectiveSpend": "有效快乐",
            "home.effectiveSpend.compact": "有效",
            "home.emotionalSpend": "情绪性消费",
            "home.emotionalSpend.compact": "情绪",
            "home.necessarySpend.compact": "刚需",
            "home.hero.title": "本月消费总览",
            "home.hero.title.compact": "消费·月",
            "home.metric.count": "共 %@ 笔",
            "home.metric.emotionalRatio7d": "近7天情绪消费占比",
            "home.metric.emotionalRatioDetail": "情绪性 %@ 笔 / 共 %@ 笔",
            "home.metric.emotionalRatioNoData": "--",
            "home.records.month": "本月消费明细",
            "home.records.today": "今日消费明细",
            "home.records.week": "本周消费明细",
            "home.spend.month": "本月花费",
            "home.spend.today": "今日花费",
            "home.spend.week": "本周花费",
            "home.title": "花钱了",
            "home.todaySummary": "今日概览",
            "home.viewAll": "全部",
            "home.weekDelta": "较上月 %@",
            "home.weekDelta.compact": "环比 %@",
            "home.weekDelta.none": "较上月 --",
            "home.weekDelta.none.compact": "环比 --",
            "home.welcomeBack": "欢迎回来",
            "home.welcomeName": "你好",
            "mine.backup": "数据备份与恢复",
            "mine.alert.cooldown.option.1": "1 天",
            "mine.alert.cooldown.option.3": "3 天",
            "mine.alert.cooldown.option.7": "7 天",
            "mine.alert.cooldownTitle": "提醒冷却周期",
            "mine.alert.highRiskOnly": "提高提醒门槛",
            "mine.alert.highRiskOnly.hint.off": "关闭后，近 7 天情绪性支出占比约 35% 即可提醒（更敏感）。",
            "mine.alert.highRiskOnly.hint.on": "开启后，占比需达到约 45% 才会提醒（更严格）。",
            "mine.alert.scope": "提醒仅出现在 App 内通知中心，内容围绕冲动、解压、面子社交三类消费。",
            "mine.alert.cooldownHint": "每天最多 1 次；同一种情绪需间隔 %@ 天；不同情绪在间隔内仍可能各提醒一次。",
            "mine.clearData": "清空所有数据",
            "mine.clearData.confirm": "确认清空",
            "mine.clearData.message": "此操作不可恢复，确定删除全部账单吗？",
            "mine.cloudSync": "iCloud 同步",
            "mine.cloudSyncDisabled": "已预留（暂未启用）",
            "mine.cloudSync.userDisabled": "iCloud 同步已关闭",
            "mine.cloudSync.userDisabled.detail": "账单仅保存在本机，不会上传至 iCloud。重新开启后需重启应用。",
            "mine.cloudSync.enable.confirm.title": "开启 iCloud 同步？",
            "mine.cloudSync.enable.confirm.message": "账单、设置与通知将在已登录 iCloud 的设备间自动同步。更改后请完全退出并重新打开应用。",
            "mine.cloudSync.disable.confirm.title": "关闭 iCloud 同步？",
            "mine.cloudSync.disable.confirm.message": "新数据将仅保存在本机，不再上传至 iCloud。已存在于云端的数据不会被自动删除。更改后请完全退出并重新打开应用。",
            "mine.cloudSync.confirm.apply": "确认",
            "mine.cloudSync.restart.title": "请重启应用",
            "mine.cloudSync.restart.message": "请从多任务界面完全关闭「花钱了」后重新打开，以应用 iCloud 同步设置。",
            "mine.cloudSync.signIn.title": "需要登录 iCloud",
            "mine.cloudSync.signIn.message": "请先在系统设置中登录 iCloud，再开启同步。",
            "mine.cloudSync.unavailable": "未登录 iCloud",
            "mine.cloudSync.syncing": "正在同步…",
            "mine.cloudSync.active": "CloudKit 已连接",
            "mine.cloudSync.active.detail": "账单、设置与通知会在已登录 iCloud 的设备间自动同步。",
            "mine.cloudSync.unavailable.hint": "请在本机登录 iCloud 后，数据才会同步到其他设备。",
            "mine.cloudSync.lastSync.format": "上次同步：%1$@",
            "mine.cloudSync.lastSync.never": "上次同步：尚未完成",
            "mine.cloudSync.error.title": "同步异常",
            "mine.cloudSync.dismiss.error": "知道了",
            "mine.cloudSync.open.settings": "打开系统设置",
            "mine.cloudSync.account.noAccount": "此 Apple ID 未启用 iCloud。",
            "mine.cloudSync.account.restricted": "iCloud 账户受限，无法同步。",
            "mine.cloudSync.account.temporarilyUnavailable": "iCloud 暂时不可用，请稍后重试。",
            "mine.cloudSync.account.unknown": "无法确认 iCloud 状态，请检查网络。",
            "sync.initialImport.title": "正在恢复云端数据",
            "sync.initialImport.message": "首次在本设备打开，正在从 iCloud 拉取你的账单与设置，请稍候。",
            "sync.initialImport.skip": "先进入应用，后台继续同步",
            "mine.comingSoon": "即将支持",
            "mine.days": "记账天数",
            "mine.export": "账单导出",
            "mine.export.csv": "导出账单（CSV）",
            "mine.export.failed": "导出失败，请检查可用存储空间后重试。",
            "mine.export.json": "导出备份（JSON）",
            "mine.import.backup": "恢复备份（JSON）",
            "mine.import.select": "选择文件",
            "mine.language": "语言",
            "mine.language.system": "跟随系统",
            "mine.language.en": "英文",
            "mine.language.zhHans": "简体中文",
            "mine.language.zhHant": "繁体中文",
            "mine.productName": "花钱了",
            "mine.reminder": "情绪消费提醒",
            "mine.restore.failed": "恢复失败，请确认所选文件为有效备份后重试。",
            "mine.restore.invalid": "备份文件无法识别，请选择由本应用导出的 JSON 备份。",
            "mine.restore.mode.merge": "合并导入",
            "mine.restore.mode.replace": "覆盖现有数据",
            "mine.restore.mode.title": "选择恢复方式",
            "mine.restore.replaceConfirm.message": "覆盖导入会先清空当前全部账单、自定义标签与通知中心，并恢复备份中的全部内容，且无法撤销。确认继续吗？",
            "mine.restore.replaceConfirm.title": "确认覆盖现有数据",
            "mine.restore.preview": "账单 %1$@ 条 · 自定义标签 %2$@ 个 · 通知 %3$@ 条\n个人资料：%4$@\n导出时间：%5$@\n记录范围：%6$@",
            "mine.restore.preview.profile.yes": "含头像与昵称",
            "mine.restore.preview.profile.no": "无",
            "mine.restore.preview.noData": "无可用记录范围",
            "mine.restore.success": "恢复完成：账单 %1$@ 条，自定义标签 %2$@ 个，通知 %3$@ 条",
            "mine.backup.scope": "JSON 备份包含：账单及附图、自定义类目/情绪、头像与昵称、通知中心、主题/语言及部分设置。",
            "mine.rule.current": "当前模式",
            "mine.rule.filter.high": "高",
            "mine.rule.filter.low": "低",
            "mine.rule.filter.mid": "中",
            "mine.rule.hint.balanced": "在信息量与准确度之间保持平衡，适合日常使用。",
            "mine.rule.hint.relaxed": "会展示更多规律，覆盖更广但可能包含弱信号。",
            "mine.rule.hint.strict": "仅展示高置信规律，信息更精炼但条目更少。",
            "mine.rule.minCount": "最小命中笔数",
            "mine.rule.minRatio": "最小命中占比",
            "mine.rule.mode.balanced": "平衡",
            "mine.rule.mode.relaxed": "更宽松",
            "mine.rule.mode.strict": "更严格",
            "mine.rule.preview.count": "预计保留规则：%@ 条（最多 2 条）",
            "mine.rule.preview.filter": "过滤强度：%@",
            "mine.rule.preview.hitTypes": "命中类型：%@",
            "mine.rule.preview.title": "示例预览",
            "mine.rule.reset": "恢复默认",
            "mine.rule.title": "复盘规则灵敏度",
            "mine.rule.type.category": "类目规律",
            "mine.rule.type.none": "暂无命中",
            "mine.rule.type.time": "时间段规律",
            "mine.rule.type.weekday": "星期规律",
            "mine.hero.cardTitle": "记账快照",
            "mine.profile.statsLine": "%@ 个记录日 · 本月 %@ 笔",
            "mine.title": "我的",
            "record.addCustomCategory": "+ 添加自定义类目",
            "record.addCustomEmotion": "+ 添加专属心情",
            "record.grid.add": "添加",
            "record.grid.addCategory.a11y": "添加自定义消费类目",
            "record.grid.addEmotion.a11y": "添加自定义花费心情",
            "record.emotionBucketSection": "统计归类",
            "record.emotionBucketHint": "决定该心情在首页「有效快乐 / 情绪性消费 / 刚需必要」中的归属。",
            "record.amountPlaceholder": "请输入消费金额",
            "record.amountZeroDisplay": "0.00",
            "record.amountTip": "点按金额打开计算器，可直接输入或用 + − × ÷ 计算；确认后写入。",
            "record.amountCalculatorHint": "打开计算器输入或计算金额。",
            "record.dateTimeTitle": "发生时间",
            "record.dateTimeTip": "可补记过去的时间，不能选择未来时间。",
            "record.pastTimeButton.a11y": "补记过去时间",
            "record.pastTimeButton.a11yHint": "未选择过去日期",
            "record.pastTimePanel.title": "补记发生时间",
            "record.categoryTitle": "消费类目",
            "record.customInputPlaceholder": "输入名称",
            "record.customSave": "添加",
            "record.custom.delete": "删除",
            "record.custom.deleteConfirmMessage": "将从记账时的可选列表中移除。已有账单里保存的类目、心情与金额都不会改动，仍可照常查看。",
            "record.custom.deleteConfirmTitle": "删除「%@」",
            "record.custom.duplicateName": "名称与其他自定义项重复，请换一个名称。",
            "record.custom.edit": "编辑",
            "record.custom.editCategoryTitle": "编辑自定义类目",
            "record.custom.editEmotionTitle": "编辑专属心情",
            "record.custom.iconSection": "图标",
            "record.detail.amount": "金额",
            "record.detail.category": "类目",
            "record.detail.deleteConfirm.message": "删除后将无法恢复，确认删除这条记录吗？",
            "record.detail.deleteConfirm.title": "确认删除记录",
            "record.detail.emotion": "动机",
            "record.detail.noNote": "暂无备注",
            "record.detail.noReceipt": "暂无小票或照片",
            "record.detail.note": "备注",
            "record.detail.receipt": "小票 / 照片",
            "record.detail.time": "时间",
            "record.detail.title": "账单详情",
            "record.emotion.desc.impulse": "一时上头、随手下单，买完就后悔 / 没必要",
            "record.emotion.desc.necessity": "生活必需、不得不花，无消费就无法正常生活",
            "record.emotion.desc.pamper": "真心喜欢、主动想要，花钱后觉得开心满足",
            "record.emotion.desc.ritual": "节日纪念、犒劳自己，为生活的小浪漫买单。",
            "record.emotion.desc.social": "碍于情面、攀比跟风，为了体面被动消费",
            "record.emotion.desc.stress": "压力大 / 心情差，靠花钱缓解情绪",
            "record.emotionDescriptionCustom": "这是你的专属心情标签，建议按当下真实动机来记录。",
            "record.emotionDescriptionTitle": "标签说明：",
            "record.emotionGuide": "选一项",
            "record.emotionTitle": "心情与动机",
            "record.noteCaption": "最多 200 字（可选）",
            "record.noteCaption.free": "最多 50 字（可选）",
            "record.noteCaption.pro": "最多 200 字（可选）",
            "record.noteCharacterCount": "%@ / %@",
            "record.photo.proGate": "添加更多照片 · Pro",
            "record.notePlaceholder": "留下一两句当时的碎碎念...",
            "record.addPhotoReceipt": "添加照片/小票",
            "record.addMorePhotos": "继续添加 (%lld/%lld)",
            "record.removePhoto": "移除照片",
            "record.optionalTip": "选填内容，不影响快速记账",
            "record.photoPlaceholder": "上传小票 / 商品照片（可选）",
            "record.photoSelected": "图片已选择",
            "record.subtitle": "花掉的钱，藏着你的心情",
            "record.title": "记录一笔消费",
            "record.navTitle": "记一笔",
            "record.validationTip": "请填写金额、类目和情绪标签",
            "tab.analysis": "复盘",
            "tab.bills": "账单",
            "tab.home": "首页",
            "tab.mine": "我的",
            "type.expense": "支出",
            "type.income": "收入"
        ],
        .zhHant: [:],
        .en: [
            "analysis.calendarEmpty": "No spending records in current month.",
            "analysis.calendarMonthPicker.a11yHint": "Scroll year and month to change the calendar. Tap Restore or swipe down to revert to the month before opening. Tap Done to keep your selection.",
            "analysis.calendarMonthPicker.a11yLabel": "Select month and year",
            "analysis.calendarMonthPicker.restore": "Restore",
            "analysis.calendar.futureDay.a11yHint": "Future dates cannot be opened.",
            "analysis.calendar.monthForward.disabled.a11yHint": "Already on the current month; future months are unavailable.",
            "analysis.calendarTitle": "Daily Emotion Calendar",
            "analysis.compare.effective": "Pamper + Ritual",
            "analysis.compare.effectiveRatio": "Effective ratio: %@",
            "analysis.compare.ineffective": "Impulse + Retail therapy + Keeping up",
            "analysis.compare.ineffectiveRatio": "Ineffective ratio: %@",
            "analysis.compare.drainRatio": "Drain ratio: %@",
            "analysis.compare.mindBalance.effectiveHeading": "✨ (Pamper + ritual)",
            "analysis.compare.mindBalance.ineffectiveHeading": "🔥 (Impulse + retail therapy + keeping up)",
            "analysis.compare.insight": "Share of spending that brings lasting joy",
            "analysis.compare.insight.high": "Your spending is close to your real needs. Great balance.",
            "analysis.compare.insight.low": "Emotional spending is relatively high recently. Slow down gently.",
            "analysis.compare.insight.mid": "You are balancing emotional release and lasting joy.",
            "analysis.compare.title": "Effective Joy vs Emotional Waste",
            "analysis.dayBills.empty": "No bills on this day",
            "analysis.dayBills.gallery.summary": "%1$d bills · %2$@ total",
            "analysis.dayBills.summary.count": "Count",
            "analysis.dayBills.summary.total": "Total",
            "analysis.dayBills.title": "Bills of Selected Day",
            "analysis.distribution": "Emotion Distribution",
            "analysis.distribution.emptyHint": "Try switching day/week/month/year filters for more trends.",
            "analysis.emotionTrend.title": "Emotion spending over time",
            "analysis.emotionTrend.window.today": "Today",
            "analysis.emotionTrend.window.7": "7d",
            "analysis.emotionTrend.window.14": "14d",
            "analysis.emotionTrend.window.30": "30d",
            "analysis.emotionTrend.window.60": "60d",
            "analysis.emotionTrend.hint.todaySegment": "By 4-hour segments today",
            "analysis.emotionTrend.hint.last7": "Last 7 days · by day",
            "analysis.emotionTrend.hint.last14": "Last 14 days · by day",
            "analysis.emotionTrend.hint.last30": "Last 30 days · by day",
            "analysis.emotionTrend.hint.last60": "Last 60 days · by day",
            "analysis.emotionTrend.binHours": "%@:00–%@:59",
            "analysis.emotionTrend.legend.other": "Other",
            "analysis.emotionTrend.emptyHint": "No expenses in this period yet. Add a record to see the trend.",
            "analysis.emotionTrend.insight.dominant": "“%1$@” accounts for about %2$@ of emotion-tagged spending this period—the dominant mood in your wallet.",
            "analysis.emotionTrend.insight.peak": "“%1$@” totals %2$@—a relative high in this period.",
            "analysis.emotionTrend.insight.even": "Spending is spread fairly evenly across segments, without a sharp single peak.",
            "analysis.heatmap.title": "When you spend (heatmap)",
            "analysis.heatmap.subtitle.day": "Today · weekday × time",
            "analysis.heatmap.subtitle.week": "This week · weekday × time",
            "analysis.heatmap.subtitle.month": "This month · weekday × time",
            "analysis.heatmap.subtitle.year": "This year · weekday × time",
            "analysis.heatmap.measure.amount": "Amount",
            "analysis.heatmap.measure.count": "Count",
            "analysis.heatmap.guide.title": "Spending heatmap guide",
            "analysis.heatmap.guide.section.color": "Color",
            "analysis.heatmap.guide.colorRule": "Each bubble’s color is the mood with the highest spend in that weekday × time slot (by amount).",
            "analysis.heatmap.guide.section.size": "Bubble size",
            "analysis.heatmap.guide.sizeRule": "Larger bubbles mean higher relative spend (or count) in this period; empty cells show only a tiny gray dot.",
            "analysis.heatmap.guide.section.measure": "Amount vs count",
            "analysis.heatmap.guide.measureRule": "Use Amount or Count in the top-right corner. Size updates with your choice; color rules stay the same.",
            "analysis.heatmap.guide.customEmotionNote": "Custom moods use the color you picked when logging.",
            "analysis.heatmap.guide.openA11yLabel": "Chart guide",
            "analysis.heatmap.guide.openA11yHint": "Opens a guide to colors and how to read this heatmap",
            "analysis.dualEmotion.title": "Records & amount by mood",
            "analysis.dualEmotion.subtitle": "Same range as above · top 5 + other",
            "analysis.dualEmotion.countChart": "Record count",
            "analysis.dualEmotion.amountChart": "Amount",
            "analysis.overview": "Current Period Overview",
            "analysis.overview.day": "Today Overview",
            "analysis.overview.week": "This Week Overview",
            "analysis.overview.month": "This Month Overview",
            "analysis.overview.year": "This Year Overview",
            "analysis.dashboard.distress.title": "Distress",
            "analysis.dashboard.fulfillment.title": "Fulfillment",
            "analysis.dashboard.entries": "entries",
            "analysis.dashboard.distress.share": "Share %1$@%%",
            "analysis.dashboard.distress.share.a11y": "Distress is %1$@%% of period spending",
            "analysis.dashboard.distress.scale.a11y": "Distress share %1$@ of 10",
            "analysis.dashboard.positiveRateDelta.up": "↑ +%1$@%% vs %2$@",
            "analysis.dashboard.positiveRateDelta.down": "↓ %1$@%% vs %2$@",
            "analysis.dashboard.positiveRateDelta.flat": "Flat vs %@",
            "analysis.dashboard.positiveRateDelta.unavailable": "— vs %@",
            "analysis.metric.expense.title": "Total Expense",
            "analysis.metric.count.title": "Total Records",
            "analysis.metric.count.value": "%@ records",
            "analysis.metric.expense.title.day": "Today's Expense",
            "analysis.metric.expense.title.week": "This Week's Expense",
            "analysis.metric.expense.title.month": "This Month's Expense",
            "analysis.metric.expense.title.year": "This Year's Expense",
            "analysis.metric.count.title.day": "Today's Records",
            "analysis.metric.count.title.week": "This Week's Records",
            "analysis.metric.count.title.month": "This Month's Records",
            "analysis.metric.count.title.year": "This Year's Records",
            "analysis.totalCount": "%@ spending records",
            "analysis.pattern.fallback": "Sample size is small. Add a few more records for clearer patterns.",
            "analysis.pattern.generated": "On %@, you tend to have %@ spending, with %@ records in this period.",
            "analysis.pattern.rule.category": "You spend most on %@ in this period (%@ records).",
            "analysis.pattern.rule.time": "Your spending is more concentrated in %@ (%@ records).",
            "analysis.pattern.rule.weekday": "You spend more frequently on %@ (%@ records).",
            "analysis.pattern.ineffectiveShareLabel": "Ineffective emotional share",
            "analysis.pattern.badge.category": "Most on %@",
            "analysis.pattern.badge.time": "Peaks in %@",
            "analysis.pattern.badge.weekday": "Often on %@",
            "analysis.pattern.badge.count": "%@ records",
            "analysis.pattern.prescription.pause": "Before checkout, pause for 30 seconds and ask if you truly need it.",
            "analysis.pattern.prescription.mid": "You are rebalancing—keeping records makes the shift easier to see.",
            "analysis.pattern.prescription.low": "Your rhythm looks steady. Keep this awareness going.",
            "analysis.patternTip": "We are discovering your spending habit from records.",
            "analysis.patternTitle": "Your Spending Pattern",
            "analysis.report.effectiveRatio": "Effective Joy Spending Ratio",
            "analysis.report.emotionPalette": "Top 3 moods by spend (share of total)",
            "analysis.report.emotionPalette.footnote": "Other moods total about %@ (top 3 by amount only)",
            "analysis.report.spendStructure": "Share of total spend: %@ %@ · %@ %@ · %@ %@",
            "analysis.report.hero.metric.effectiveRatio.hint": "excl. essentials",
            "analysis.report.export": "Export Report Text",
            "analysis.report.generate": "Generate emotion report",
            "analysis.report.pickPeriod.title": "Choose report period",
            "analysis.report.title.forPeriod": "%@ Emotion Spending Report",
            "analysis.report.navTitle.forPeriod": "%@ · Mood Report",
            "analysis.report.hero.caption.forPeriod": "%@ emotion spending",
            "analysis.report.noData.forPeriod": "No expenses in %@. Add a record to generate the report.",
            "analysis.report.customRangeRequired": "Select a custom range before generating the report.",
            "analysis.report.title.day": "Today's Emotion Spending Report",
            "analysis.report.title.week": "This Week's Emotion Spending Report",
            "analysis.report.title.year": "This Year's Emotion Spending Report",
            "analysis.report.title.custom": "Emotion Spending Report",
            "analysis.report.monthOnlyHint": "Monthly report only. Switch to Month.",
            "analysis.report.generatedAt": "Generated At",
            "analysis.report.noData": "No expenses in the selected period. Add a record to generate the report.",
            "analysis.report.posterFooter": "WhySpend | Record not just spending, but how you felt",
            "analysis.report.poster.generatedAt": "Generated %@",
            "analysis.report.poster.appStore": "App Store",
            "analysis.report.poster.googlePlay": "Google Play",
            "analysis.report.poster.downloadCTA": "Download now — listen to the ripples inside",
            "analysis.report.rulesTitle": "Pattern summary (this period)",
            "analysis.report.shareFailed": "Couldn't generate the share image. Please try again.",
            "analysis.report.shareImage": "Share Report Image",
            "analysis.report.subtitle": "Your personal emotion spending note to spend with awareness and joy.",
            "analysis.report.poster.subtitle": "Record not just spending, but how you felt when spending.",
            "analysis.report.title": "Monthly Emotion Spending Report",
            "analysis.report.topEmotion": "Top mood (this period)",
            "analysis.report.totalCount": "Records (this period)",
            "analysis.report.totalExpense": "Total expense (this period)",
            "analysis.report.warmTipTitle": "Gentle Reminder",
            "analysis.subtitle": "Understand what emotion your money follows",
            "analysis.time.afternoon": "afternoon",
            "analysis.time.evening": "evening",
            "analysis.time.morning": "morning",
            "analysis.time.night": "late night",
            "analysis.title": "Emotion Review",
            "analysis.topEmotion": "Top Emotion",
            "analysis.totalExpense": "Total Expense",
            "analysis.warm.generated.high": "Excluding essentials, ineffective emotional spending is about %@ (effective joy about %@). Essentials are about %@ of total spend. Try pausing for 30 seconds before checkout.",
            "analysis.warm.generated.low": "Excluding essentials, ineffective emotional spending is about %@ (effective joy about %@). Essentials are about %@ of total spend. Your spending rhythm looks steady.",
            "analysis.warm.generated.mid": "Excluding essentials, ineffective emotional spending is about %@ (effective joy about %@). Essentials are about %@ of total spend. You are improving with awareness.",
            "analysis.warmLine": "Spend without guilt, but with awareness.",
            "alert.template": "In the last 7 days, %@ spending appeared %@ times, totaling %@. Pause and ask if you truly need it.",
            "alert.title": "Gentle Reminder",
            "bills.edit": "Edit",
            "bills.emptyTip": "No bills yet. Tap + below to log one.",
            "bills.filter.day": "Day",
            "bills.filter.month": "Month",
            "bills.filter.week": "Week",
            "bills.filter.year": "Year",
            "bills.title": "Bill List",
            "bills.metric.expense.title.day": "Today's Expense",
            "bills.metric.expense.title.week": "This Week's Expense",
            "bills.metric.expense.title.month": "This Month's Expense",
            "bills.metric.expense.title.year": "This Year's Expense",
            "bills.metric.count.title.day": "Today's Records",
            "bills.metric.count.title.week": "This Week's Records",
            "bills.metric.count.title.month": "This Month's Records",
            "bills.metric.count.title.year": "This Year's Records",
            "bills.metric.count.value": "%@ records",
            "bills.dashboard.totalSpent.day": "Today's Spending",
            "bills.dashboard.totalSpent.week": "This Week's Spending",
            "bills.dashboard.totalSpent.month": "This Month's Spending",
            "bills.dashboard.totalSpent.year": "This Year's Spending",
            "bills.dashboard.frequency.day": "Today's Frequency",
            "bills.dashboard.frequency.week": "This Week's Frequency",
            "bills.dashboard.frequency.month": "This Month's Frequency",
            "bills.dashboard.frequency.year": "This Year's Frequency",
            "bills.dashboard.entries": "entries",
            "bills.dashboard.comparePeriod.day": "yesterday",
            "bills.dashboard.comparePeriod.week": "last week",
            "bills.dashboard.comparePeriod.month": "last month",
            "bills.dashboard.comparePeriod.year": "last year",
            "bills.dashboard.expenseDelta.up": "↑ +%1$@%% vs %2$@",
            "bills.dashboard.expenseDelta.down": "↓ %1$@%% vs %2$@",
            "bills.dashboard.expenseDelta.flat": "Flat vs %@",
            "bills.dashboard.expenseDelta.unavailable": "— vs %@",
            "bills.dashboard.freqDelta.up": "↑ +%1$@ vs %2$@",
            "bills.dashboard.freqDelta.down": "↓ %1$@ vs %2$@",
            "bills.dashboard.freqDelta.flat": "Flat vs %@",
            "bills.dashboard.freqDelta.unavailable": "— vs %@",
            "bills.dashboard.sparkline.a11y": "Spending trend for this period",
            "bills.insight.periodPrefix.day": "So far today, ",
            "bills.insight.periodPrefix.week": "So far this week, ",
            "bills.insight.periodPrefix.month": "So far this month, ",
            "bills.insight.periodPrefix.year": "So far this year, ",
            "bills.insight.custom.clause.range": "During %1$d, months %2$02d through %3$02d, ",
            "bills.insight.custom.clause.singleMonth": "During %1$d, month %2$02d, ",
            "bills.insight.custom.rangeLabel.range": "%1$d · %2$02d–%3$02d",
            "bills.insight.custom.rangeLabel.singleMonth": "%1$d · %2$02d",
            "bills.insight.categoryShare.dominant.custom": "%1$@“%2$@” is about %3$@%% of spending—the largest share in this range.",
            "bills.insight.categoryShare.selected.custom": "%1$@spending on “%2$@” is over %3$@%% of the total.",
            "bills.insight.categoryShare.selectedMany": "Your filter (%1$@, %2$@ categories) accounts for about %3$@%% of spending.",
            "bills.insight.categoryShare.selectedMany.custom": "%1$@Selected categories (%2$@, %3$@ total) account for about %4$@%% of spending in this range.",
            "bills.insight.compare.up.custom": "About %1$@%% higher than the prior range (%2$@).",
            "bills.insight.compare.down.custom": "Lower than the prior range (%1$@).",
            "bills.insight.empty.day": "No entries yet today—looks like a mindful day.",
            "bills.insight.categoryShare.selected": "%3$@spending on “%1$@” is over %2$@%% of the total.",
            "bills.insight.categoryShare.dominant": "%3$@“%1$@” is about %2$@%% of spending—the largest share.",
            "bills.insight.trend.flat": "%1$@spending looks steady—nice rhythm.",
            "bills.insight.trend.rising": "%1$@spending has picked up a bit—worth a gentle check-in.",
            "bills.insight.trend.falling": "%1$@spending is easing off—a calmer pace.",
            "bills.insight.compare.up": "About %1$@%% higher than the same point %2$@.",
            "bills.insight.compare.down": "Lower than the same point %@.",
            "bills.insight.fallback": "Keep logging—your patterns will get clearer.",
            "bills.dashboard.scale.a11y": "Progress vs prior period: %1$@ of 10",
            "bills.filter.category.label": "Category",
            "bills.filter.category.summaryMany": "%1$@, %2$@ categories",
            "bills.filter.emotion.label": "Mood",
            "bills.filtered.empty.title": "No bills match the current filters",
            "bills.filtered.empty.hint": "Try another category or mood, or clear filters to see all spending in this period.",
            "bills.clearFilters": "Clear filters",
            "bills.filter.sheetTitle": "Filters",
            "bills.filter.sheet.reset": "Reset",
            "bills.filter.entry.a11yHint": "Tap the filter icon to the right of the period chips to choose category and mood.",
            "bills.metricDetail.title.expense": "Spending insights",
            "bills.metricDetail.title.frequency": "Frequency insights",
            "bills.metricDetail.necessary.title": "Essential living costs",
            "bills.metricDetail.necessary.label": "Essentials",
            "bills.metricDetail.premium.label": "Emotional premium",
            "bills.metricDetail.necessary.summary": "Essentials %1$@; emotional premium %2$@.",
            "bills.metricDetail.stability.solid": "Your financial baseline looks steady.",
            "bills.metricDetail.stability.trim": "Non-essential share is high—consider trimming emotional spend.",
            "bills.metricDetail.top3.title": "Top 3 spends this period",
            "bills.metricDetail.top3.empty": "No expenses in the current filter.",
            "bills.metricDetail.top.rank": "TOP %lld",
            "bills.metricDetail.pro.lockHint": "Upgrade to Pro for ranks #2–#3 and per-entry drill-down.",
            "bills.metricDetail.avgTicket.title": "Average ticket",
            "bills.metricDetail.avgTicket.micro": "Micro frequent",
            "bills.metricDetail.avgTicket.steady": "Steady pace",
            "bills.metricDetail.avgTicket.large": "Large, infrequent",
            "bills.metricDetail.peakTime.title": "Peak spending window",
            "bills.metricDetail.peakTime.body": "You often spend around %@.",
            "bills.metricDetail.peakTime.unavailable": "Not enough data to detect a time pattern.",
            "bills.metricDetail.frequency.empty": "No transactions in the current filter.",
            "bills.metricDetail.dashboard.expense.a11yHint": "View spending insights",
            "bills.metricDetail.dashboard.frequency.a11yHint": "View frequency insights",
            "bills.row.attachment.both": "Includes note and photo or receipt",
            "bills.row.attachment.note": "Includes note",
            "bills.row.attachment.photo": "Includes photo or receipt",
            "category.clothing": "Clothing & Beauty",
            "category.daily": "Daily Goods",
            "category.entertainment": "Entertainment",
            "category.food": "Food",
            "category.housing": "Housing & Utilities",
            "category.learning": "Learning",
            "category.medical": "Medical",
            "category.digital": "Digital",
            "category.other": "Other",
            "category.pet": "Pet",
            "category.social": "Social",
            "category.travel": "Travel",
            "category.transport": "Transport",
            "category.short.clothing": "Clothing",
            "category.short.daily": "Daily",
            "category.short.digital": "Digital",
            "category.short.entertainment": "Fun",
            "category.short.food": "Food",
            "category.short.housing": "Housing",
            "category.short.learning": "Learning",
            "category.short.medical": "Medical",
            "category.short.other": "Other",
            "category.short.pet": "Pet",
            "category.short.social": "Social",
            "category.short.travel": "Travel",
            "category.short.transport": "Transport",
            "common.all": "All",
            "common.cancel": "Cancel",
            "common.ok": "OK",
            "common.done": "Done",
            "common.delete": "Delete",
            "common.expense": "Expense",
            "common.income": "Income",
            "common.noData": "No data",
            "common.save": "Save",
            "common.today": "Today",
            "emotion.impulse": "Impulse Buy",
            "emotion.necessity": "Necessity",
            "emotion.pamper": "Pamper Myself",
            "emotion.ritual": "Sense of Ritual",
            "emotion.social": "Keeping up appearances",
            "emotion.stress": "Retail therapy",
            "emotion.short.impulse": "Impulse",
            "emotion.short.necessity": "Necessity",
            "emotion.short.pamper": "Pamper",
            "emotion.short.ritual": "Ritual",
            "emotion.short.social": "Keeping up",
            "emotion.short.stress": "Retail therapy",
            "home.alert.noRisk": "Your recent weekly spending rhythm looks steady.",
            "home.alertTitle": "Recent Emotional Spending Alert",
            "home.emotionFilter.all": "All Emotions",
            "home.emptyTip": "No records yet. Tap + below to log one.",
            "home.emotionShare.title": "Emotion share of spending",
            "home.emotionShare.subtitle": "Based on all-time expenses",
            "home.emotionShare.emptyHint": "Add an expense record to see the breakdown.",
            "home.emotionShare.scopeWeek": "This week",
            "home.emotionShare.dominant": "Main: %1$@ · %2$@%%",
            "home.emotionShare.dominantEmpty": "No spending this week yet",
            "home.today.peaceTitle": "A calm day so far",
            "home.today.peaceTitle.compact": "Calm day",
            "home.today.peaceSubtitle": "No expenses logged today.",
            "home.today.impulseStressSummary": "Impulse / retail therapy today: %1$@ txns · %2$@",
            "home.sparkline.title": "7-day emotional spending",
            "home.sparkline.title.compact": "7-day mood spend",
            "home.sparkline.hintEmpty": "No emotional spending in the last 7 days",
            "home.emotionShare.compact.title": "Since first record",
            "home.emotionShare.compact.a11y": "Emotional spending breakdown since your first record. Tap to open analysis.",
            "home.emotionShare30d.title": "30-day mood",
            "home.emotionShare30d.dominant": "Mostly %@",
            "home.emotionShare30d.scattered": "Spread across moods",
            "home.emotionShare30d.scattered.compact": "Mixed moods",
            "home.emotionShare30d.empty": "No spending in 30 days",
            "home.emotionShare30d.a11y": "30-day mood, %@. Tap to open analysis.",
            "home.quickAdd": "Add",
            "home.recentRecords": "Today Records",
            "home.recentActivity": "Latest activity",
            "home.searchPlaceholder": "Search category, note, or emotion",
            "home.action.add": "Add",
            "home.action.calendar": "Emotion Calendar",
            "home.action.more": "More",
            "home.action.weekTrend": "Weekly Trend",
            "home.effectiveSpend": "Effective Joy",
            "home.emotionalSpend": "Emotional Spending",
            "home.hero.title": "Monthly Spending Overview",
            "home.metric.count": "%@ records",
            "home.metric.emotionalRatio7d": "7-Day Emotional Ratio",
            "home.metric.emotionalRatioDetail": "%@ emotional / %@ total",
            "home.metric.emotionalRatioNoData": "--",
            "home.records.month": "Monthly Records",
            "home.records.today": "Today Records",
            "home.records.week": "Weekly Records",
            "home.spend.month": "This Month",
            "home.spend.today": "Today",
            "home.spend.week": "This Week",
            "home.title": "WhySpend",
            "home.todaySummary": "Today Summary",
            "home.viewAll": "All",
            "home.weekDelta": "vs last month %@",
            "home.weekDelta.none": "vs last month --",
            "home.welcomeBack": "Welcome back",
            "home.welcomeName": "there",
            "mine.backup": "Backup & Restore",
            "mine.alert.cooldown.option.1": "1 day",
            "mine.alert.cooldown.option.3": "3 days",
            "mine.alert.cooldown.option.7": "7 days",
            "mine.alert.cooldownTitle": "Alert Cooldown Period",
            "mine.alert.highRiskOnly": "Stricter alert threshold",
            "mine.alert.highRiskOnly.hint.off": "When off, about 35% emotional spending in the last 7 days can trigger an alert (more sensitive).",
            "mine.alert.highRiskOnly.hint.on": "When on, spending must reach about 45% to alert (stricter).",
            "mine.alert.scope": "Alerts appear only in the in-app Notification Center, focused on impulse, retail therapy, and keeping-up spending.",
            "mine.alert.cooldownHint": "At most once per day; the same emotion needs a %@-day gap; different emotions may each alert within that window.",
            "mine.clearData": "Clear All Data",
            "mine.clearData.confirm": "Confirm Clear",
            "mine.clearData.message": "This action cannot be undone. Delete all records?",
            "mine.cloudSync": "iCloud Sync",
            "mine.cloudSyncDisabled": "Reserved (disabled for now)",
            "mine.cloudSync.userDisabled": "iCloud sync off",
            "mine.cloudSync.userDisabled.detail": "Bills stay on this device only and are not uploaded to iCloud. Turn sync back on and restart the app to apply.",
            "mine.cloudSync.enable.confirm.title": "Turn on iCloud sync?",
            "mine.cloudSync.enable.confirm.message": "Bills, settings, and notifications will sync across devices signed into iCloud. Fully quit and reopen the app after changing this.",
            "mine.cloudSync.disable.confirm.title": "Turn off iCloud sync?",
            "mine.cloudSync.disable.confirm.message": "New data stays on this device and will not upload to iCloud. Existing cloud data is not deleted automatically. Fully quit and reopen the app after changing this.",
            "mine.cloudSync.confirm.apply": "Confirm",
            "mine.cloudSync.restart.title": "Restart required",
            "mine.cloudSync.restart.message": "Fully quit WhySpend from the app switcher, then reopen it to apply iCloud sync settings.",
            "mine.cloudSync.signIn.title": "Sign in to iCloud",
            "mine.cloudSync.signIn.message": "Sign in to iCloud in Settings before turning on sync.",
            "mine.cloudSync.unavailable": "Not signed in to iCloud",
            "mine.cloudSync.syncing": "Syncing…",
            "mine.cloudSync.active": "CloudKit connected",
            "mine.cloudSync.active.detail": "Bills, settings, and notifications sync across devices signed into iCloud.",
            "mine.cloudSync.unavailable.hint": "Sign in to iCloud on this device to sync with your other devices.",
            "mine.cloudSync.lastSync.format": "Last sync: %1$@",
            "mine.cloudSync.lastSync.never": "Last sync: not yet",
            "mine.cloudSync.error.title": "Sync issue",
            "mine.cloudSync.dismiss.error": "OK",
            "mine.cloudSync.open.settings": "Open Settings",
            "mine.cloudSync.account.noAccount": "This Apple ID has no iCloud account.",
            "mine.cloudSync.account.restricted": "iCloud is restricted on this device.",
            "mine.cloudSync.account.temporarilyUnavailable": "iCloud is temporarily unavailable. Try again later.",
            "mine.cloudSync.account.unknown": "Could not verify iCloud status. Check your network.",
            "sync.initialImport.title": "Restoring from iCloud",
            "sync.initialImport.message": "First launch on this device. Pulling your bills and settings from iCloud.",
            "sync.initialImport.skip": "Continue — sync in background",
            "mine.comingSoon": "Coming Soon",
            "mine.days": "Recording Days",
            "mine.export": "Export Bills",
            "mine.export.csv": "Export Bills (CSV)",
            "mine.export.failed": "Export failed. Please check available storage and try again.",
            "mine.export.json": "Export Backup (JSON)",
            "mine.import.backup": "Restore Backup (JSON)",
            "mine.import.select": "Choose File",
            "mine.language": "Language",
            "mine.language.system": "Follow System",
            "mine.language.en": "English",
            "mine.language.zhHans": "Simplified Chinese",
            "mine.language.zhHant": "Traditional Chinese",
            "mine.productName": "WhySpend",
            "mine.reminder": "Emotion Spending Alert",
            "mine.restore.failed": "Restore failed. Please make sure the selected file is a valid backup.",
            "mine.restore.invalid": "This backup file is not recognized. Please select a JSON backup exported by this app.",
            "mine.restore.mode.merge": "Merge into current data",
            "mine.restore.mode.replace": "Replace current data",
            "mine.restore.mode.title": "Choose restore mode",
            "mine.restore.replaceConfirm.message": "Replace import will clear all current bills, custom tags, and Notification Center items, then restore everything from the backup. This cannot be undone. Continue?",
            "mine.restore.replaceConfirm.title": "Confirm replacing current data",
            "mine.restore.preview": "%1$@ bills · %2$@ custom tags · %3$@ notifications\nProfile: %4$@\nExported at: %5$@\nRecord range: %6$@",
            "mine.restore.preview.profile.yes": "Avatar & display name included",
            "mine.restore.preview.profile.no": "None",
            "mine.restore.preview.noData": "No record range available",
            "mine.restore.success": "Restore completed: %1$@ bills, %2$@ custom tags, %3$@ notifications",
            "mine.backup.scope": "JSON backup includes bills & photos, custom categories/emotions, avatar & name, Notification Center, theme/language & key settings.",
            "mine.rule.current": "Current Mode",
            "mine.rule.filter.high": "High",
            "mine.rule.filter.low": "Low",
            "mine.rule.filter.mid": "Medium",
            "mine.rule.hint.balanced": "Balances amount of insights and confidence for daily use.",
            "mine.rule.hint.relaxed": "Shows more patterns with broader coverage but weaker signals.",
            "mine.rule.hint.strict": "Shows high-confidence patterns only, with fewer but cleaner rules.",
            "mine.rule.minCount": "Minimum Match Count",
            "mine.rule.minRatio": "Minimum Match Ratio",
            "mine.rule.mode.balanced": "Balanced",
            "mine.rule.mode.relaxed": "Relaxed",
            "mine.rule.mode.strict": "Strict",
            "mine.rule.preview.count": "Estimated kept rules: %@ (max 2)",
            "mine.rule.preview.filter": "Filter strength: %@",
            "mine.rule.preview.hitTypes": "Matched types: %@",
            "mine.rule.preview.title": "Preview",
            "mine.rule.reset": "Reset Default",
            "mine.rule.title": "Review Rule Sensitivity",
            "mine.rule.type.category": "Category pattern",
            "mine.rule.type.none": "No match",
            "mine.rule.type.time": "Time-slot pattern",
            "mine.rule.type.weekday": "Weekday pattern",
            "mine.hero.cardTitle": "Your snapshot",
            "mine.profile.statsLine": "%@ days with records · %@ entries this month",
            "mine.title": "Mine",
            "record.addCustomCategory": "+ Add Custom Category",
            "record.addCustomEmotion": "+ Add Custom Emotion",
            "record.grid.add": "Add",
            "record.grid.addCategory.a11y": "Add a custom spending category",
            "record.grid.addEmotion.a11y": "Add a custom spending mood",
            "record.emotionBucketSection": "Home summary bucket",
            "record.emotionBucketHint": "Maps this mood to Effective joy, Emotional spending, or Necessary on the home dashboard.",
            "record.amountPlaceholder": "Enter amount",
            "record.amountZeroDisplay": "0.00",
            "record.amountTip": "Tap the amount to open the calculator. Enter digits or use + − × ÷, then confirm.",
            "record.amountCalculatorHint": "Opens the amount calculator.",
            "record.dateTimeTitle": "When",
            "record.dateTimeTip": "You can pick a past or current time. Future times are not allowed.",
            "record.pastTimeButton.a11y": "Log a past date",
            "record.pastTimeButton.a11yHint": "No past date selected",
            "record.pastTimePanel.title": "When it happened",
            "record.categoryTitle": "Category",
            "record.customInputPlaceholder": "Enter name",
            "record.customSave": "Add",
            "record.custom.delete": "Delete",
            "record.custom.deleteConfirmMessage": "Removes this from the picker when you add new bills. Past bills keep their saved category, mood, and amounts.",
            "record.custom.deleteConfirmTitle": "Delete “%@”",
            "record.custom.duplicateName": "That name is already used by another custom item.",
            "record.custom.edit": "Edit",
            "record.custom.editCategoryTitle": "Edit custom category",
            "record.custom.editEmotionTitle": "Edit custom mood",
            "record.custom.iconSection": "Icon",
            "record.detail.amount": "Amount",
            "record.detail.category": "Category",
            "record.detail.deleteConfirm.message": "This record will be permanently deleted. Continue?",
            "record.detail.deleteConfirm.title": "Delete record",
            "record.detail.emotion": "Emotion",
            "record.detail.noNote": "No note",
            "record.detail.noReceipt": "No receipt or photo",
            "record.detail.note": "Note",
            "record.detail.receipt": "Receipt / Photo",
            "record.detail.time": "Time",
            "record.detail.title": "Record Detail",
            "record.emotion.desc.impulse": "You bought on impulse in the moment and later felt it was unnecessary.",
            "record.emotion.desc.necessity": "This was a must-have for daily life, and hard to skip.",
            "record.emotion.desc.pamper": "You truly wanted it and felt satisfied after buying.",
            "record.emotion.desc.ritual": "A small ritual purchase for celebrations, milestones, or self-reward.",
            "record.emotion.desc.social": "You spent from social pressure, comparison, or to save face.",
            "record.emotion.desc.stress": "You spent to blow off steam or lift a bad mood.",
            "record.emotionDescriptionCustom": "This is your custom emotion tag. Describe your real motivation.",
            "record.emotionDescriptionTitle": "Tag note:",
            "record.emotionGuide": "Pick one",
            "record.emotionTitle": "Mood & motive",
            "record.noteCaption": "Up to 200 characters (optional)",
            "record.noteCaption.free": "Up to 50 characters (optional)",
            "record.noteCaption.pro": "Up to 200 characters (optional)",
            "record.noteCharacterCount": "%@ / %@",
            "record.photo.proGate": "More photos · Pro",
            "record.notePlaceholder": "A few words about how you felt…",
            "record.addPhotoReceipt": "Add photo / receipt",
            "record.addMorePhotos": "Add more (%lld/%lld)",
            "record.removePhoto": "Remove photo",
            "record.optionalTip": "Optional fields do not block quick recording.",
            "record.photoPlaceholder": "Upload receipt or item photo (optional)",
            "record.photoSelected": "Photo selected",
            "record.subtitle": "Spending reveals your emotion",
            "record.title": "Record a Purchase",
            "record.navTitle": "Log expense",
            "record.validationTip": "Amount, category and emotion are required.",
            "tab.analysis": "Review",
            "tab.bills": "Bills",
            "tab.home": "Home",
            "tab.mine": "Mine",
            "type.expense": "Expense",
            "type.income": "Income"
        ]
    ]
}
