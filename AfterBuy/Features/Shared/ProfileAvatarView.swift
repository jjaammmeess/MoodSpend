import SwiftUI
import UIKit

enum AvatarPreset: String, CaseIterable, Identifiable {
    case ocean
    case sunset
    case lavender
    case forest
    case rose
    case sky

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .ocean: return "drop.fill"
        case .sunset: return "sun.max.fill"
        case .lavender: return "moon.stars.fill"
        case .forest: return "leaf.fill"
        case .rose: return "heart.fill"
        case .sky: return "cloud.fill"
        }
    }

    var colors: [Color] {
        switch self {
        case .ocean: return [Color(hex: "6AA8DB"), Color(hex: "3F6F76")]
        case .sunset: return [Color(hex: "F1B56E"), Color(hex: "C65840")]
        case .lavender: return [Color(hex: "9C8ACF"), Color(hex: "62496F")]
        case .forest: return [Color(hex: "7BC39F"), Color(hex: "3F7A68")]
        case .rose: return [Color(hex: "F09AB6"), Color(hex: "BE5D86")]
        case .sky: return [Color(hex: "9FC8F5"), Color(hex: "5E82C2")]
        }
    }
}

struct ProfileAvatarView: View {
    let imageData: Data?
    let presetID: String?
    var size: CGFloat = 44
    /// When false, preset/default avatars render softer for edit-picker grids.
    var isEmphasized: Bool = true
    /// Outer hairline; off when parent supplies hero border or breathing ring.
    var showsStroke: Bool = true

    @State private var decodedImage: UIImage?

    private var preset: AvatarPreset? {
        guard let presetID else { return nil }
        return AvatarPreset(rawValue: presetID)
    }

    private var presetIconOpacity: Double {
        isEmphasized ? 0.92 : 0.52
    }

    private var presetFillOpacity: Double {
        isEmphasized ? 1 : 0.58
    }

    var body: some View {
        Group {
            if let decodedImage {
                Image(uiImage: decodedImage)
                    .resizable()
                    .scaledToFill()
            } else if let preset {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: preset.colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(presetFillOpacity)
                    .overlay(
                        Image(systemName: preset.symbolName)
                            .font(.system(size: size * 0.42, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(presetIconOpacity))
                    )
            } else {
                Circle()
                    .fill(AppTheme.accentSecondary.opacity(isEmphasized ? 0.18 : 0.10))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.4, weight: .semibold))
                            .foregroundStyle(AppTheme.accentInsight.opacity(isEmphasized ? 1 : 0.52))
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            if showsStroke {
                Circle()
                    .stroke(AppTheme.border.opacity(isEmphasized ? 0.8 : 0.35), lineWidth: 1)
            }
        }
        .task(id: imageDataSignature) {
            await loadImageIfNeeded()
        }
    }

    private var imageDataSignature: String {
        guard let imageData, !imageData.isEmpty else { return "none" }
        return "\(imageData.count)-\(imageData.prefix(32).hashValue)"
    }

    private func loadImageIfNeeded() async {
        guard let imageData, !imageData.isEmpty else {
            decodedImage = nil
            return
        }
        let maxPixel = max(size * 3, 96)
        let image = await ImageCacheManager.shared.image(for: imageData, maxPixelDimension: maxPixel)
        guard !Task.isCancelled else { return }
        decodedImage = image
    }
}
