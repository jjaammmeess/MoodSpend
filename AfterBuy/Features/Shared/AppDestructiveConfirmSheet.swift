import SwiftUI

/// Branded bottom sheet for irreversible / destructive confirmations.
struct AppDestructiveConfirmSheet<PreviewContent: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let title: String
    let message: String
    var systemImage: String = "trash.fill"
    let confirmTitle: String
    let cancelTitle: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @ViewBuilder let previewContent: () -> PreviewContent

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.22 : 0.14))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 18)

            VStack(spacing: 20) {
                headerSection
                previewContent()
                actionButtons
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background { sheetChromeBackground }
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentRisk.opacity(colorScheme == .dark ? 0.22 : 0.12))
                    .frame(width: 54, height: 54)
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.accentRisk)
            }
            .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                onCancel()
                dismiss()
            } label: {
                Text(cancelTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.border.opacity(0.55), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            Button {
                onConfirm()
                dismiss()
            } label: {
                Text(confirmTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppTheme.accentRisk)
                    )
                    .shadow(
                        color: AppTheme.accentRisk.opacity(colorScheme == .dark ? 0.35 : 0.28),
                        radius: 10,
                        y: 4
                    )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var sheetChromeBackground: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 24,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 24,
            style: .continuous
        )
        ZStack {
            shape.fill(AppTheme.pageBackground)
            shape.fill(.ultraThinMaterial.opacity(colorScheme == .dark ? 0.35 : 0.55))
            shape
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.16 : 0.55),
                            Color.white.opacity(0.04),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

extension AppDestructiveConfirmSheet where PreviewContent == EmptyView {
    init(
        title: String,
        message: String,
        systemImage: String = "trash.fill",
        confirmTitle: String,
        cancelTitle: String,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self.previewContent = { EmptyView() }
    }
}

extension View {
    func appDestructiveConfirmSheetStyle(height: CGFloat = 340) -> some View {
        presentationDetents([.height(height)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(24)
            .presentationBackground(.clear)
    }
}

struct AppDestructiveConfirmMetricCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.accentRisk)
                .frame(width: 40, height: 40)
                .background(AppTheme.accentRisk.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.metricDashboardCornerRadius, style: .continuous)
                .fill(AppTheme.metricDashboardFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.metricDashboardCornerRadius, style: .continuous)
                .stroke(AppTheme.border.opacity(0.45), lineWidth: 0.5)
        }
    }
}
