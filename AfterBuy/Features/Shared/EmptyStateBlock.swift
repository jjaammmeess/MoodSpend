import SwiftUI

struct EmptyStateBlock: View {
    let title: String
    let hint: String?
    let systemImage: String

    init(title: String, hint: String? = nil, systemImage: String = "tray") {
        self.title = title
        self.hint = hint
        self.systemImage = systemImage
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.75))
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            if let hint, !hint.isEmpty {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
    }
}
