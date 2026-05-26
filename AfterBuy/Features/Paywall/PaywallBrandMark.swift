import SwiftUI

// MARK: - Rainbow palette (Paywall + Mine Pro banner)

enum PaywallRainbowPalette {
    static let glowColor = Color(red: 0.55, green: 0.72, blue: 1.0)
    static let spectrumPurple = Color(hex: "8C76A1")
    static let spectrumCyan = Color(hex: "69B7CE")
    static let spectrumTeal = Color(hex: "5F9E7A")

    static var ctaGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "2A1848"),
                Color(hex: "12101C"),
                Color(hex: "1A2838"),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var laserBadgeGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "C65840"),
                Color(hex: "E8B84A"),
                Color(hex: "69B7CE"),
                Color(hex: "8C76A1"),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private static let rimSpectrumColors: [Color] = [
        Color(hex: "D96A52"),
        Color(hex: "F0C85A"),
        Color(hex: "6BB58A"),
        Color(hex: "7ECAE0"),
        Color(hex: "A08BB8"),
    ]

    /// MoodSpectrum-aligned rim for lifetime plan card — linear, no angular spin artifacts.
    static var cardRimLinearGradient: LinearGradient {
        LinearGradient(
            stops: MoodSpectrumGradient.stops(from: rimSpectrumColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Very faint inner wash — clipped to card, never blurred outward.
    static var lifetimeInnerWash: LinearGradient {
        LinearGradient(
            stops: MoodSpectrumGradient.stops(from: rimSpectrumColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let lifetimeRimGlowCyan = Color(hex: "69B7CE").opacity(0.42)
    static let lifetimeRimGlowPurple = Color(hex: "8C76A1").opacity(0.32)

    static var angularGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                Color(red: 1.0, green: 0.38, blue: 0.42),
                Color(red: 1.0, green: 0.72, blue: 0.32),
                Color(red: 0.42, green: 0.92, blue: 0.55),
                Color(red: 0.32, green: 0.72, blue: 1.0),
                Color(red: 0.62, green: 0.42, blue: 0.98),
                Color(red: 1.0, green: 0.38, blue: 0.42)
            ]),
            center: .center
        )
    }
}

// MARK: - Brand mark (rainbow ring + vertical stroke)

struct PaywallBrandMark: View {
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    PaywallRainbowPalette.angularGradient,
                    lineWidth: max(2, size * 0.032)
                )
                .frame(width: size, height: size)

            Rectangle()
                .fill(Color.white)
                .frame(width: max(2, size * 0.042), height: size * 0.38)
        }
        .accessibilityHidden(true)
    }
}
