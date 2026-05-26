import Foundation

/// User preference for preset mood icons: custom raster art vs SF Symbols.
enum EmotionIconStyle: String, CaseIterable, Codable, Identifiable {
    case raster
    case system

    var id: String { rawValue }

    static let storageKey = "settings.emotionIconStyle"
    static let defaultStyle: EmotionIconStyle = .system

    static func resolved(from raw: String?) -> EmotionIconStyle {
        guard let raw, let style = EmotionIconStyle(rawValue: raw) else { return .defaultStyle }
        return style
    }

    static var stored: EmotionIconStyle {
        let raw = UserDefaults.standard.string(forKey: storageKey)
        return resolved(from: raw)
    }

    static func persist(_ style: EmotionIconStyle) {
        UserDefaults.standard.set(style.rawValue, forKey: storageKey)
    }
}

extension EmotionTag {
    /// Raster asset for preset moods when `style == .raster`; otherwise `nil` so UI uses `sfSymbolName`.
    func rasterAssetName(for style: EmotionIconStyle) -> String? {
        guard style == .raster else { return nil }
        return presetRasterAssetName
    }
}

enum EmotionIconPresentation {
    /// SF Symbol for a bill’s mood: preset tag symbol, or stored/custom fallback (never generic heart for presets).
    static func symbolName(for record: TransactionRecord) -> String {
        if let preset = EmotionTag.from(raw: record.emotionRaw) {
            return preset.sfSymbolName
        }
        return CustomIconCatalog.normalizedEmotionSymbol(record.emotionIconSymbolRaw)
    }

    static func rasterAssetName(for record: TransactionRecord, style: EmotionIconStyle) -> String? {
        guard let preset = EmotionTag.from(raw: record.emotionRaw) else { return nil }
        return preset.rasterAssetName(for: style)
    }
}
