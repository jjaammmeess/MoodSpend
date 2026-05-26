import SwiftUI

enum EmotionTag: String, Codable, CaseIterable, Identifiable {
    case pamper
    case necessity
    case impulse
    case stress
    case social
    case ritual

    var id: String { rawValue }

    var colorHex: String {
        switch self {
        case .pamper: "69B7CE"
        case .necessity: "3F6F76"
        case .impulse: "C65840"
        case .stress: "62496F"
        case .social: "F4CE4B"
        case .ritual: "5F90B2"
        }
    }

    var color: Color {
        Color(hex: colorHex)
    }

    var key: LKey {
        switch self {
        case .pamper: .emotionPamper
        case .necessity: .emotionNecessity
        case .impulse: .emotionImpulse
        case .stress: .emotionStress
        case .social: .emotionSocial
        case .ritual: .emotionRitual
        }
    }

    var shortKey: LKey {
        switch self {
        case .pamper: .emotionShortPamper
        case .necessity: .emotionShortNecessity
        case .impulse: .emotionShortImpulse
        case .stress: .emotionShortStress
        case .social: .emotionShortSocial
        case .ritual: .emotionShortRitual
        }
    }

    static func from(raw: String) -> EmotionTag? {
        EmotionTag(rawValue: raw)
    }

    /// SF Symbol used when no custom raster is provided.
    var sfSymbolName: String {
        switch self {
        case .pamper: "sparkles"
        case .necessity: "checkmark.seal"
        case .impulse: "bolt"
        case .stress: "wind"
        case .social: "person.2.wave.2"
        case .ritual: "gift"
        }
    }

    /// Bundle image name without extension (e.g. `images/chongdong.png` → `"chongdong"`).
    var presetRasterAssetName: String? {
        switch self {
        case .pamper: "quyue"
        case .necessity: "gangxu"
        case .impulse: "chongdong"
        case .stress: "jieya"
        case .social: "shejiao"
        case .ritual: "yishi"
        }
    }
}
