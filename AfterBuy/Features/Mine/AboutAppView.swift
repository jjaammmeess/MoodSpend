import SwiftUI

private struct AboutAppSharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct AboutAppView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.openURL) private var openURL

    @State private var sharePayload: AboutAppSharePayload?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                brandCardSection
                    .padding(.top, 20)
                    .padding(.bottom, 24)

                VStack(spacing: 16) {
                    versionCard
                    contactCard
                    legalCard
                    promotionCard
                    guideCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle(localization.text(.aboutAppNavTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.pageBackground, for: .navigationBar)
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: payload.items)
        }
    }

    // MARK: - Brand

    private var brandCardSection: some View {
        VStack(spacing: 12) {
            Image("AboutAppIcon")
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppTheme.border.opacity(0.35), lineWidth: 0.5)
                }
                .accessibilityHidden(true)

            Text(AppBranding.productName(for: localization.effectiveLanguage))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text(localization.text(.aboutAppBrandTagline))
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Text(localization.text(.aboutAppBrandSubtitle))
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .mineSettingsCardChrome(watercolor: .spending, watercolorGlowScale: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(brandAccessibilityLabel)
    }

    private var brandAccessibilityLabel: String {
        let name = AppBranding.productName(for: localization.effectiveLanguage)
        return "\(name)。\(localization.text(.aboutAppBrandTagline)) \(localization.text(.aboutAppBrandSubtitle))"
    }

    // MARK: - Version

    private var versionCard: some View {
        MineSettingsCard {
            MineSettingsActionRow(
                icon: "number.circle.fill",
                title: localization.text(.aboutAppVersion),
                value: AppVersionInfo.displayString,
                showsChevron: false
            )
        }
    }

    // MARK: - Contact

    private var contactCard: some View {
        MineSettingsCard {
            Button {
                openSupportEmail()
            } label: {
                MineSettingsActionRow(
                    icon: "envelope.fill",
                    title: localization.text(.aboutAppContactEmail),
                    value: AppVersionInfo.supportEmail
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Legal

    private var legalCard: some View {
        MineSettingsCard {
            legalDocumentRow(
                icon: "hand.raised.fill",
                titleKey: .aboutAppPrivacy,
                document: .privacyPolicy
            )

            MineSettingsDivider()

            legalDocumentRow(
                icon: "doc.text.fill",
                titleKey: .aboutAppTerms,
                document: .termsOfUse
            )
        }
    }

    // MARK: - Product guide

    private var guideCard: some View {
        MineSettingsCard {
            NavigationLink {
                OnboardingView(isReviewMode: true)
                    .environmentObject(localization)
            } label: {
                MineSettingsActionRow(
                    icon: "book.fill",
                    title: localization.text(.aboutAppReviewOnboarding)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Share & rate

    private var promotionCard: some View {
        MineSettingsCard {
            Button {
                presentShareApp()
            } label: {
                MineSettingsActionRow(
                    icon: "square.and.arrow.up.fill",
                    title: localization.text(.aboutAppShare)
                )
            }
            .buttonStyle(.plain)

            MineSettingsDivider()

            Button {
                openURL(AppStoreInfo.writeReviewURL)
            } label: {
                MineSettingsActionRow(
                    icon: "star.fill",
                    title: localization.text(.aboutAppRate)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func legalDocumentRow(
        icon: String,
        titleKey: LKey,
        document: AppLegalLinks.Document
    ) -> some View {
        NavigationLink {
            LegalDocumentView(document: document)
                .environmentObject(localization)
        } label: {
            MineSettingsActionRow(
                icon: icon,
                title: localization.text(titleKey)
            )
        }
        .buttonStyle(.plain)
    }

    private func presentShareApp() {
        let url = AppStoreInfo.appStoreURL
        let productName = AppBranding.productName(for: localization.effectiveLanguage)
        let message = String(
            format: localization.text(.aboutAppShareMessage),
            productName,
            url.absoluteString
        )
        sharePayload = AboutAppSharePayload(items: [message, url])
    }

    private func openSupportEmail() {
        guard let url = AppVersionInfo.mailtoURL else { return }
        openURL(url)
    }
}

#Preview {
    NavigationStack {
        AboutAppView()
            .environmentObject(LocalizationManager())
    }
}
