import UIKit

/// Device home-indicator inset from the key window (reliable inside nested sheets).
enum WindowSafeArea {
    static func bottomInset() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        guard let scene else { return 0 }
        return scene.windows.first(where: \.isKeyWindow)?.safeAreaInsets.bottom
            ?? scene.windows.first?.safeAreaInsets.bottom
            ?? 0
    }
}
