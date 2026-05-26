import SwiftUI

enum MoodSpectrumCopyBuilder {
    private static let bodyFont = Font.system(size: 13)
    private static let boldFont = Font.system(size: 13, weight: .semibold)

    private static let stressComfortKeys: [LKey] = [
        .homeMoodSpectrumComfortStressV1,
        .homeMoodSpectrumComfortStressV2,
        .homeMoodSpectrumComfortStressV3,
    ]
    private static let impulseComfortKeys: [LKey] = [
        .homeMoodSpectrumComfortImpulseV1,
        .homeMoodSpectrumComfortImpulseV2,
        .homeMoodSpectrumComfortImpulseV3,
    ]
    private static let socialComfortKeys: [LKey] = [
        .homeMoodSpectrumComfortSocialV1,
        .homeMoodSpectrumComfortSocialV2,
        .homeMoodSpectrumComfortSocialV3,
    ]
    private static let pamperComfortKeys: [LKey] = [
        .homeMoodSpectrumComfortPamperV1,
        .homeMoodSpectrumComfortPamperV2,
        .homeMoodSpectrumComfortPamperV3,
    ]
    private static let ritualComfortKeys: [LKey] = [
        .homeMoodSpectrumComfortRitualV1,
        .homeMoodSpectrumComfortRitualV2,
        .homeMoodSpectrumComfortRitualV3,
    ]
    private static let necessityComfortKeys: [LKey] = [
        .homeMoodSpectrumComfortNecessityV1,
        .homeMoodSpectrumComfortNecessityV2,
        .homeMoodSpectrumComfortNecessityV3,
    ]
    private static let effectiveBucketComfortKeys: [LKey] = [
        .homeMoodSpectrumComfortEffectiveV1,
        .homeMoodSpectrumComfortEffectiveV2,
        .homeMoodSpectrumComfortEffectiveV3,
    ]
    private static let emotionalBucketComfortKeys: [LKey] = [
        .homeMoodSpectrumComfortEmotionalV1,
        .homeMoodSpectrumComfortEmotionalV2,
        .homeMoodSpectrumComfortEmotionalV3,
    ]
    private static let necessaryBucketComfortKeys: [LKey] = [
        .homeMoodSpectrumComfortNecessaryBucketV1,
        .homeMoodSpectrumComfortNecessaryBucketV2,
        .homeMoodSpectrumComfortNecessaryBucketV3,
    ]
    private static let customEffectiveComfortKeys: [LKey] = [
        .homeMoodSpectrumComfortCustomEffectiveV1,
        .homeMoodSpectrumComfortCustomEffectiveV2,
        .homeMoodSpectrumComfortCustomEffectiveV3,
    ]
    private static let customEmotionalComfortKeys: [LKey] = [
        .homeMoodSpectrumComfortCustomEmotionalV1,
        .homeMoodSpectrumComfortCustomEmotionalV2,
        .homeMoodSpectrumComfortCustomEmotionalV3,
    ]
    private static let customNecessaryComfortKeys: [LKey] = [
        .homeMoodSpectrumComfortCustomNecessaryV1,
        .homeMoodSpectrumComfortCustomNecessaryV2,
        .homeMoodSpectrumComfortCustomNecessaryV3,
    ]
    private static let scatteredHeadlineKeys: [LKey] = [
        .homeMoodSpectrumScatteredV1,
        .homeMoodSpectrumScatteredV2,
        .homeMoodSpectrumScatteredV3,
        .homeMoodSpectrumScatteredV4,
    ]
    private static let scatteredComfortKeys: [LKey] = [
        .homeMoodSpectrumComfortScatteredV1,
        .homeMoodSpectrumComfortScatteredV2,
        .homeMoodSpectrumComfortScatteredV3,
        .homeMoodSpectrumComfortScatteredV4,
    ]
    private static let sparseHeadlineKeys: [LKey] = [
        .homeMoodSpectrumSparseV1,
        .homeMoodSpectrumSparseV2,
        .homeMoodSpectrumSparseV3,
    ]
    private static let sparseComfortKeys: [LKey] = [
        .homeMoodSpectrumComfortSparseV1,
        .homeMoodSpectrumComfortSparseV2,
        .homeMoodSpectrumComfortSparseV3,
    ]
    private static let emptyHeadlineKeys: [LKey] = [
        .homeMoodSpectrumEmptyV1,
        .homeMoodSpectrumEmptyV2,
    ]
    private static let emptyComfortKeys: [LKey] = [
        .homeMoodSpectrumComfortEmptyV1,
        .homeMoodSpectrumComfortEmptyV2,
        .homeMoodSpectrumComfortEmptyV3,
    ]

    static func dialogue(
        summary: MoodSpectrumSummary,
        rotationSeed: String,
        localization: LocalizationManager
    ) -> MoodSpectrumDialogue {
        let label = localization.text(.homeMoodSpectrumLabel)
        let (headline, boldFragments, comfort, iconName, iconTint) = content(
            for: summary,
            rotationSeed: rotationSeed,
            localization: localization
        )
        let attributed = attributedLine(
            label: label,
            headline: headline,
            boldFragments: boldFragments,
            comfort: comfort
        )
        let spoken = [label, headline, comfort].joined()
        return MoodSpectrumDialogue(
            iconSystemName: iconName,
            iconTint: iconTint,
            attributedText: attributed,
            accessibilityText: spoken
        )
    }

    private static func content(
        for summary: MoodSpectrumSummary,
        rotationSeed: String,
        localization: LocalizationManager
    ) -> (headline: String, boldFragments: [String], comfort: String, icon: String, tint: Color) {
        switch summary {
        case .empty:
            return rotatedPair(
                headlineKeys: emptyHeadlineKeys,
                comfortKeys: emptyComfortKeys,
                boldFragments: [],
                icon: "sparkles",
                tint: AppTheme.textSecondary,
                rotationSeed: rotationSeed,
                localization: localization
            )
        case .sparse:
            return rotatedPair(
                headlineKeys: sparseHeadlineKeys,
                comfortKeys: sparseComfortKeys,
                boldFragments: [],
                icon: "leaf",
                tint: AppTheme.accentSecondary,
                rotationSeed: rotationSeed,
                localization: localization
            )
        case .scattered:
            return rotatedPair(
                headlineKeys: scatteredHeadlineKeys,
                comfortKeys: scatteredComfortKeys,
                boldFragments: [],
                icon: "circle.grid.2x2",
                tint: AppTheme.accentInsight,
                rotationSeed: rotationSeed,
                localization: localization
            )
        case .dominant(let info):
            return dominantContent(info: info, rotationSeed: rotationSeed, localization: localization)
        case .dualDominant(let primary, let secondary):
            return dualDominantContent(
                primary: primary,
                secondary: secondary,
                rotationSeed: rotationSeed,
                localization: localization
            )
        }
    }

    private static func dominantContent(
        info: MoodSpectrumDominantInfo,
        rotationSeed: String,
        localization: LocalizationManager
    ) -> (String, [String], String, String, Color) {
        let headline = String(
            format: localization.text(.homeMoodSpectrumDominant),
            locale: localization.locale,
            arguments: [info.emotionName]
        )
        let comfort = comfortLine(
            for: info,
            rotationSeed: rotationSeed,
            localization: localization
        )
        let icon = info.tag?.sfSymbolName ?? bucketIcon(info.bucket)
        let tint = info.tag?.color ?? bucketTint(info.bucket)
        return (headline, [info.emotionName], comfort, icon, tint)
    }

    private static func dualDominantContent(
        primary: MoodSpectrumDominantInfo,
        secondary: MoodSpectrumDominantInfo,
        rotationSeed: String,
        localization: LocalizationManager
    ) -> (String, [String], String, String, Color) {
        let headline = String(
            format: localization.text(.homeMoodSpectrumDualDominant),
            locale: localization.locale,
            arguments: [primary.emotionName, secondary.emotionName] as [CVarArg]
        )
        let comfort = comfortLine(
            for: primary,
            rotationSeed: rotationSeed,
            localization: localization
        )
        let icon = primary.tag?.sfSymbolName ?? bucketIcon(primary.bucket)
        let tint = primary.tag?.color ?? bucketTint(primary.bucket)
        return (headline, [primary.emotionName, secondary.emotionName], comfort, icon, tint)
    }

    private static func rotatedPair(
        headlineKeys: [LKey],
        comfortKeys: [LKey],
        boldFragments: [String],
        icon: String,
        tint: Color,
        rotationSeed: String,
        localization: LocalizationManager
    ) -> (String, [String], String, String, Color) {
        let headline = localization.text(
            headlineKeys[stableVariantIndex(seed: rotationSeed + "|h", count: headlineKeys.count)]
        )
        let comfort = localization.text(
            comfortKeys[stableVariantIndex(seed: rotationSeed + "|c", count: comfortKeys.count)]
        )
        return (headline, boldFragments, comfort, icon, tint)
    }

    private static func comfortLine(
        for info: MoodSpectrumDominantInfo,
        rotationSeed: String,
        localization: LocalizationManager
    ) -> String {
        let keys = comfortKeys(for: info)
        let index = stableVariantIndex(seed: rotationSeed + "|" + info.emotionRaw, count: keys.count)
        let key = keys[index]
        if info.tag == nil, !info.emotionName.isEmpty {
            return String(
                format: localization.text(key),
                locale: localization.locale,
                arguments: [info.emotionName] as [CVarArg]
            )
        }
        return localization.text(key)
    }

    private static func comfortKeys(for info: MoodSpectrumDominantInfo) -> [LKey] {
        if let tag = info.tag {
            switch tag {
            case .stress: return stressComfortKeys
            case .impulse: return impulseComfortKeys
            case .social: return socialComfortKeys
            case .pamper: return pamperComfortKeys
            case .ritual: return ritualComfortKeys
            case .necessity: return necessityComfortKeys
            }
        }
        if info.emotionRaw.hasPrefix(EmotionGrouping.customEmotionIdPrefix) {
            switch info.bucket {
            case .effective: return customEffectiveComfortKeys
            case .emotional: return customEmotionalComfortKeys
            case .necessary: return customNecessaryComfortKeys
            }
        }
        switch info.bucket {
        case .effective: return effectiveBucketComfortKeys
        case .emotional: return emotionalBucketComfortKeys
        case .necessary: return necessaryBucketComfortKeys
        }
    }

    private static func stableVariantIndex(seed: String, count: Int) -> Int {
        guard count > 1 else { return 0 }
        var hasher = Hasher()
        hasher.combine(seed)
        return abs(hasher.finalize()) % count
    }

    private static func bucketIcon(_ bucket: EmotionBucket) -> String {
        switch bucket {
        case .effective: "sparkles"
        case .emotional: "wind"
        case .necessary: "checkmark.seal"
        }
    }

    private static func bucketTint(_ bucket: EmotionBucket) -> Color {
        switch bucket {
        case .effective: AppTheme.accentSecondary
        case .emotional: AppTheme.accentInsight
        case .necessary: AppTheme.actionBlue
        }
    }

    private static func attributedLine(
        label: String,
        headline: String,
        boldFragments: [String],
        comfort: String
    ) -> AttributedString {
        var result = AttributedString(label)
        result.font = bodyFont
        result.foregroundColor = AppTheme.textSecondary.opacity(0.88)

        appendHeadline(&result, headline: headline, boldFragments: boldFragments)

        var comfortPart = AttributedString(comfort)
        comfortPart.font = bodyFont
        comfortPart.foregroundColor = AppTheme.textSecondary.opacity(0.72)
        result.append(comfortPart)

        return result
    }

    private static func appendHeadline(
        _ result: inout AttributedString,
        headline: String,
        boldFragments: [String]
    ) {
        let fragments = boldFragments.filter { !$0.isEmpty }
        guard !fragments.isEmpty else {
            var plain = AttributedString(headline)
            plain.font = bodyFont
            plain.foregroundColor = AppTheme.textPrimary.opacity(0.82)
            result.append(plain)
            return
        }

        var searchStart = headline.startIndex
        var matchedAny = false
        for fragment in fragments {
            guard let range = headline[searchStart...].range(of: fragment) else { continue }
            matchedAny = true
            let before = headline[searchStart..<range.lowerBound]
            if !before.isEmpty {
                var segment = AttributedString(String(before))
                segment.font = bodyFont
                segment.foregroundColor = AppTheme.textPrimary.opacity(0.82)
                result.append(segment)
            }
            var bold = AttributedString(fragment)
            bold.font = boldFont
            bold.foregroundColor = AppTheme.textPrimary.opacity(0.92)
            result.append(bold)
            searchStart = range.upperBound
        }
        if searchStart < headline.endIndex {
            var tail = AttributedString(String(headline[searchStart...]))
            tail.font = bodyFont
            tail.foregroundColor = AppTheme.textPrimary.opacity(0.82)
            result.append(tail)
        } else if !matchedAny {
            var plain = AttributedString(headline)
            plain.font = bodyFont
            plain.foregroundColor = AppTheme.textPrimary.opacity(0.82)
            result.append(plain)
        }
    }
}
