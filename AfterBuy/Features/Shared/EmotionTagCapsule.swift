import SwiftUI

/// Tinted capsule label for mood tags on expense rows (matches emotion detail sheet).
struct EmotionTagCapsule: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let colorHex: String

    private var swatchColor: Color {
        let hex = colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.isEmpty { return EmotionTag.necessity.color }
        return Color(hex: hex)
    }

    private var effectiveHex: String {
        let hex = colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        return hex.isEmpty ? EmotionTag.necessity.colorHex : hex
    }

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(swatchColor.opacity(AppTheme.emotionTagCapsuleTintOpacity(for: colorScheme, hex: effectiveHex)))
            .foregroundStyle(AppTheme.labelOnTintedSwatch(hex: effectiveHex, colorScheme: colorScheme))
            .clipShape(Capsule())
            .lineLimit(1)
    }
}

extension EmotionTagCapsule {
    init(title: String, record: TransactionRecord) {
        self.title = title
        self.colorHex = record.displayEmotionColorHex
    }
}
