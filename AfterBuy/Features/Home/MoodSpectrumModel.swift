import SwiftUI
import UIKit

struct MoodSpectrumSegment: Identifiable, Equatable {
    let id: String
    let color: Color
    let isPlaceholder: Bool
}

/// One expense mapped to a position on the spectrum (left = older).
struct MoodSpectrumEntry: Identifiable, Equatable {
    let id: String
    let color: Color
    let emotionTitle: String
    let amount: Double
    let createdAt: Date
    /// 1-based index from the left edge of the spectrum.
    let spectrumIndex: Int
}

struct MoodSpectrumLegendItem: Identifiable, Equatable {
    let id: String
    let color: Color
    let shortLabel: String
    let accessibilityName: String
}

/// Custom moods that appear in the current spectrum window (recent expenses).
struct MoodSpectrumCustomLegendItem: Identifiable, Equatable {
    let id: String
    let color: Color
    let displayName: String
    let entryCount: Int
    let totalAmount: Double
}

struct MoodSpectrumPayload: Equatable {
    let segments: [MoodSpectrumSegment]
    let entries: [MoodSpectrumEntry]
    let legendItems: [MoodSpectrumLegendItem]
    let customLegendItems: [MoodSpectrumCustomLegendItem]
    let gradientStops: [Gradient.Stop]
    let dialogue: MoodSpectrumDialogue
    let subtitle: String
    let longPressHint: String
    let spectrumZoneAccessibilityLabel: String
    let spectrumZoneAccessibilityHint: String
    let dialogueAccessibilityLabel: String
    let segmentSignature: String

    var linearGradient: LinearGradient {
        LinearGradient(stops: gradientStops, startPoint: .leading, endPoint: .trailing)
    }

    var hasDetailEntries: Bool {
        !entries.isEmpty
    }
}

struct MoodSpectrumDialogue: Equatable {
    let iconSystemName: String
    let iconTint: Color
    let attributedText: AttributedString
    let accessibilityText: String
}

struct MoodSpectrumDominantInfo: Equatable {
    let emotionName: String
    let emotionRaw: String
    let tag: EmotionTag?
    let bucket: EmotionBucket
}

enum MoodSpectrumBuilder {
    static let segmentCount = 15
    private static let dominantMinSharePercent: Double = 18
    private static let dualSecondaryMinSharePercent: Double = 12

    static func build(
        recentExpensesChronological: [TransactionRecord],
        customEmotions: [CustomOption],
        localization: LocalizationManager
    ) -> MoodSpectrumPayload {
        let segments = makeSegments(from: recentExpensesChronological)
        let entries = makeEntries(from: recentExpensesChronological, localization: localization)
        let stops = MoodSpectrumGradient.stops(from: segments.map(\.color))
        let summary = summarize(
            expenses: recentExpensesChronological,
            customEmotions: customEmotions,
            localization: localization
        )
        let rotationSeed = recentExpensesChronological
            .map { $0.publicId.uuidString }
            .joined(separator: "|")
        let dialogue = MoodSpectrumCopyBuilder.dialogue(
            summary: summary,
            rotationSeed: rotationSeed,
            localization: localization
        )
        let legendItems = MoodSpectrumLegend.items(localization: localization)
        let customLegendItems = MoodSpectrumLegend.customItems(in: recentExpensesChronological)
        let subtitle = localization.text(.homeMoodSpectrumSubtitle)
        let longPressHint = localization.text(.homeMoodSpectrumLongPressHint)
        let spectrumZoneAccessibilityLabel = localization.text(.homeMoodSpectrumA11ySpectrumLabel)
        let spectrumZoneAccessibilityHint = localization.text(.homeMoodSpectrumA11yHint)
        let signature = segments.map(\.id).joined(separator: "|")
            + "|" + customLegendItems.map(\.id).joined(separator: ",")
        return MoodSpectrumPayload(
            segments: segments,
            entries: entries,
            legendItems: legendItems,
            customLegendItems: customLegendItems,
            gradientStops: stops,
            dialogue: dialogue,
            subtitle: subtitle,
            longPressHint: longPressHint,
            spectrumZoneAccessibilityLabel: spectrumZoneAccessibilityLabel,
            spectrumZoneAccessibilityHint: spectrumZoneAccessibilityHint,
            dialogueAccessibilityLabel: dialogue.accessibilityText,
            segmentSignature: signature
        )
    }

    private static func makeEntries(
        from expenses: [TransactionRecord],
        localization: LocalizationManager
    ) -> [MoodSpectrumEntry] {
        expenses.enumerated().map { offset, record in
            MoodSpectrumEntry(
                id: record.publicId.uuidString,
                color: record.emotionColor,
                emotionTitle: emotionDisplayName(for: record, localization: localization),
                amount: record.amount,
                createdAt: record.createdAt,
                spectrumIndex: offset + 1
            )
        }
    }

    private static func emotionDisplayName(
        for record: TransactionRecord,
        localization: LocalizationManager
    ) -> String {
        if let tag = EmotionTag.from(raw: record.emotionRaw) {
            return localization.text(tag.shortKey)
        }
        return record.safeEmotionName
    }

    /// Newest-first expenses (max 15) → chronological segments for left-to-right spectrum.
    static func recentExpenseRecords(from records: [TransactionRecord]) -> [TransactionRecord] {
        let newest = records.filter { $0.type == .expense }.prefix(segmentCount)
        return Array(newest.reversed())
    }

    private static func makeSegments(from expenses: [TransactionRecord]) -> [MoodSpectrumSegment] {
        var segments: [MoodSpectrumSegment] = expenses.map { record in
            MoodSpectrumSegment(
                id: record.publicId.uuidString,
                color: record.emotionColor,
                isPlaceholder: false
            )
        }
        let padCount = segmentCount - segments.count
        if padCount > 0 {
            for offset in 0..<padCount {
                segments.append(
                    MoodSpectrumSegment(
                        id: "placeholder-\(offset)",
                        color: AppTheme.divider,
                        isPlaceholder: true
                    )
                )
            }
        }
        return segments
    }

    private static func summarize(
        expenses: [TransactionRecord],
        customEmotions: [CustomOption],
        localization: LocalizationManager
    ) -> MoodSpectrumSummary {
        guard !expenses.isEmpty else { return .empty }
        if expenses.count < 3 { return .sparse(count: expenses.count) }

        let grouped = Dictionary(grouping: expenses, by: \.emotionRaw)
        let ranked = grouped.map { raw, recs -> (raw: String, amount: Double, count: Int) in
            (raw, recs.reduce(0) { $0 + $1.amount }, recs.count)
        }
        .sorted { lhs, rhs in
            if lhs.amount != rhs.amount { return lhs.amount > rhs.amount }
            return lhs.count > rhs.count
        }

        guard let top = ranked.first, top.amount > 0 else { return .empty }
        let total = expenses.reduce(0) { $0 + $1.amount }
        let sharePercent = top.amount / total * 100
        if sharePercent < dominantMinSharePercent {
            return .scattered
        }

        let primary = dominantInfo(
            raw: top.raw,
            expenses: expenses,
            customEmotions: customEmotions,
            localization: localization
        )
        if ranked.count >= 2 {
            let second = ranked[1]
            let secondSharePercent = second.amount / total * 100
            if secondSharePercent >= dualSecondaryMinSharePercent {
                let secondary = dominantInfo(
                    raw: second.raw,
                    expenses: expenses,
                    customEmotions: customEmotions,
                    localization: localization
                )
                return .dualDominant(primary: primary, secondary: secondary)
            }
        }
        return .dominant(primary)
    }

    private static func dominantInfo(
        raw: String,
        expenses: [TransactionRecord],
        customEmotions: [CustomOption],
        localization: LocalizationManager
    ) -> MoodSpectrumDominantInfo {
        let tag = EmotionTag.from(raw: raw)
        let name: String
        if let tag {
            name = localization.text(tag.shortKey)
        } else {
            name = expenses.first(where: { $0.emotionRaw == raw })?.safeEmotionName ?? raw
        }
        let bucket = expenses.first(where: { $0.emotionRaw == raw })
            .map { EmotionGrouping.bucket(for: $0, customEmotions: customEmotions) }
        return MoodSpectrumDominantInfo(
            emotionName: name,
            emotionRaw: raw,
            tag: tag,
            bucket: bucket ?? .emotional
        )
    }
}

enum MoodSpectrumSummary: Equatable {
    case empty
    case sparse(count: Int)
    case scattered
    case dominant(MoodSpectrumDominantInfo)
    case dualDominant(primary: MoodSpectrumDominantInfo, secondary: MoodSpectrumDominantInfo)
}

enum MoodSpectrumLegend {
    static func items(localization: LocalizationManager) -> [MoodSpectrumLegendItem] {
        EmotionTag.allCases.map { tag in
            MoodSpectrumLegendItem(
                id: tag.rawValue,
                color: tag.color,
                shortLabel: axisShortLabel(for: tag, localization: localization),
                accessibilityName: localization.text(tag.shortKey)
            )
        }
    }

    static func customItems(in expenses: [TransactionRecord]) -> [MoodSpectrumCustomLegendItem] {
        let customExpenses = expenses.filter {
            $0.emotionRaw.hasPrefix(EmotionGrouping.customEmotionIdPrefix)
        }
        guard !customExpenses.isEmpty else { return [] }

        let grouped = Dictionary(grouping: customExpenses, by: \.emotionRaw)
        return grouped.compactMap { raw, records -> MoodSpectrumCustomLegendItem? in
            guard let first = records.first else { return nil }
            let amount = records.reduce(0) { $0 + $1.amount }
            return MoodSpectrumCustomLegendItem(
                id: raw,
                color: first.emotionColor,
                displayName: first.safeEmotionName,
                entryCount: records.count,
                totalAmount: amount
            )
        }
        .sorted { lhs, rhs in
            if lhs.totalAmount != rhs.totalAmount { return lhs.totalAmount > rhs.totalAmount }
            return lhs.entryCount > rhs.entryCount
        }
    }

    /// Matches tri-card bar chart axis labels on the home screen.
    private static func axisShortLabel(for tag: EmotionTag, localization: LocalizationManager) -> String {
        if localization.effectiveLanguage == .zhHans || localization.effectiveLanguage == .zhHant {
            switch tag {
            case .pamper: return "悦"
            case .necessity: return "需"
            case .impulse: return "冲"
            case .stress: return "压"
            case .social: return "面"
            case .ritual: return "仪"
            }
        }
        let full = localization.text(tag.key)
        if let first = full.first {
            return String(first)
        }
        return String(tag.rawValue.prefix(1)).uppercased()
    }
}

enum MoodSpectrumGradient {
    static func stops(from colors: [Color]) -> [Gradient.Stop] {
        guard let first = colors.first else {
            return [
                Gradient.Stop(color: AppTheme.divider, location: 0),
                Gradient.Stop(color: AppTheme.divider, location: 1),
            ]
        }
        if colors.count == 1 {
            return [
                Gradient.Stop(color: first, location: 0),
                Gradient.Stop(color: first, location: 1),
            ]
        }

        var stops: [Gradient.Stop] = []
        let lastIndex = colors.count - 1
        for index in colors.indices {
            let location = Double(index) / Double(lastIndex)
            stops.append(Gradient.Stop(color: colors[index], location: location))
            if index < lastIndex {
                let midLocation = (Double(index) + 0.5) / Double(lastIndex)
                stops.append(
                    Gradient.Stop(
                        color: blend(colors[index], colors[index + 1]),
                        location: midLocation
                    )
                )
            }
        }
        return stops.sorted { $0.location < $1.location }
    }

    private static func blend(_ lhs: Color, _ rhs: Color) -> Color {
        let uiL = UIColor(lhs)
        let uiR = UIColor(rhs)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        uiL.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiR.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(
            red: (r1 + r2) / 2,
            green: (g1 + g2) / 2,
            blue: (b1 + b2) / 2,
            opacity: (a1 + a2) / 2
        )
    }
}

#if DEBUG
extension MoodSpectrumPayload {
    static var preview: MoodSpectrumPayload {
        let colors = (0..<MoodSpectrumBuilder.segmentCount).map { index in
            EmotionTag.allCases[index % EmotionTag.allCases.count].color
        }
        let segments = colors.enumerated().map { index, color in
            MoodSpectrumSegment(id: "preview-\(index)", color: color, isPlaceholder: false)
        }
        let stops = MoodSpectrumGradient.stops(from: colors)
        let dialogue = MoodSpectrumDialogue(
            iconSystemName: EmotionTag.stress.sfSymbolName,
            iconTint: EmotionTag.stress.color,
            attributedText: AttributedString("当前内心状态：解压发泄居多。消费退潮后，记得抱抱那个有些疲惫的自己。"),
            accessibilityText: "当前内心状态：解压发泄居多。消费退潮后，记得抱抱那个有些疲惫的自己。"
        )
        return MoodSpectrumPayload(
            segments: segments,
            entries: [],
            legendItems: MoodSpectrumLegend.items(localization: LocalizationManager()),
            customLegendItems: [],
            gradientStops: stops,
            dialogue: dialogue,
            subtitle: "颜色即记账时的心情 · 最近 15 笔 · 左旧右新",
            longPressHint: "长按光谱查看每笔明细",
            spectrumZoneAccessibilityLabel: "情绪光谱，点按查看说明",
            spectrumZoneAccessibilityHint: "长按光谱可查看每笔明细。",
            dialogueAccessibilityLabel: dialogue.accessibilityText,
            segmentSignature: "preview"
        )
    }
}
#endif
