import SwiftUI

struct HowToUseView: View {
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                    .padding(.top, 28)
                    .padding(.bottom, 32)

                LazyVStack(spacing: 16) {
                    ForEach(featureItems) { item in
                        HowToUseFeatureCard(
                            icon: item.icon,
                            iconStyle: item.iconStyle,
                            title: localization.text(item.titleKey),
                            description: localization.text(item.bodyKey)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle(localization.text(.howToUseNavTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.pageBackground, for: .navigationBar)
    }

    private var headerSection: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "wind")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            AppTheme.accentSecondary,
                            AppTheme.accentInsight.opacity(0.88),
                            AppTheme.accentSecondary.opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            Text(localization.text(.howToUseHeaderTitle))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text(localization.text(.howToUseHeaderSubtitle))
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private var featureItems: [HowToUseFeatureItem] {
        [
            HowToUseFeatureItem(
                id: "ledger",
                icon: "creditcard.circle.fill",
                iconStyle: .solid(Color(hex: "3F6F76")),
                titleKey: .howToUseCardLedgerTitle,
                bodyKey: .howToUseCardLedgerBody
            ),
            HowToUseFeatureItem(
                id: "heatRing",
                icon: "aqi.medium",
                iconStyle: .gradient(
                    [Color(hex: "62496F"), AppTheme.accentSecondary, Color(hex: "4B6FA8")]
                ),
                titleKey: .howToUseCardHeatRingTitle,
                bodyKey: .howToUseCardHeatRingBody
            ),
            HowToUseFeatureItem(
                id: "alerts",
                icon: "bell.badge.circle.fill",
                iconStyle: .solid(AppTheme.accentWarning),
                titleKey: .howToUseCardAlertsTitle,
                bodyKey: .howToUseCardAlertsBody
            ),
            HowToUseFeatureItem(
                id: "icloud",
                icon: "icloud.circle.fill",
                iconStyle: .solid(AppTheme.actionBlue),
                titleKey: .howToUseCardCloudTitle,
                bodyKey: .howToUseCardCloudBody
            ),
        ]
    }
}

// MARK: - Feature card

private struct HowToUseFeatureItem: Identifiable {
    let id: String
    let icon: String
    let iconStyle: HowToUseIconStyle
    let titleKey: LKey
    let bodyKey: LKey
}

private enum HowToUseIconStyle {
    case solid(Color)
    case gradient([Color])
}

private struct HowToUseFeatureCard: View {
    let icon: String
    let iconStyle: HowToUseIconStyle
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            featureIcon
                .frame(width: 36, alignment: .center)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.border.opacity(0.35), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var featureIcon: some View {
        switch iconStyle {
        case .solid(let color):
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)
        case .gradient(let colors):
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolRenderingMode(.palette)
        }
    }
}

#Preview {
    NavigationStack {
        HowToUseView()
            .environmentObject(LocalizationManager())
    }
}
