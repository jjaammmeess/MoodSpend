import CryptoKit
import UIKit

/// Decodes JPEG/PNG off the hot path and reuses thumbnails for avatars & list images.
actor ImageCacheManager {
    static let shared = ImageCacheManager()

    private let cache = NSCache<NSString, UIImage>()
    private let maxPixelDimension: CGFloat = 512

    private init() {
        cache.countLimit = 80
        cache.totalCostLimit = 48 * 1024 * 1024
    }

    func image(for data: Data, maxPixelDimension: CGFloat? = nil) async -> UIImage? {
        guard !data.isEmpty else { return nil }
        let pixelLimit = maxPixelDimension ?? self.maxPixelDimension
        let key = cacheKey(for: data, maxPixel: pixelLimit)
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }

        let decoded: UIImage? = await Task.detached(priority: .userInitiated) {
            Self.decodeThumbnail(data: data, maxPixel: pixelLimit)
        }.value

        if let decoded {
            let cost = decoded.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
            cache.setObject(decoded, forKey: key as NSString, cost: cost)
        }
        return decoded
    }

    func invalidateAll() {
        cache.removeAllObjects()
    }

    private func cacheKey(for data: Data, maxPixel: CGFloat) -> String {
        let digest = SHA256.hash(data: data)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "\(hex)-\(Int(maxPixel))"
    }

    private nonisolated static func decodeThumbnail(data: Data, maxPixel: CGFloat) -> UIImage? {
        guard let source = UIImage(data: data) else { return nil }
        let maxSide = max(source.size.width, source.size.height)
        guard maxSide > maxPixel, maxSide > 0 else { return source }

        let scale = maxPixel / maxSide
        let target = CGSize(width: source.size.width * scale, height: source.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            source.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
