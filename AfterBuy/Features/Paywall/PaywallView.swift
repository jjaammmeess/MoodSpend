import StoreKit
import SwiftUI
import UIKit

// MARK: - PaywallView

/// Full-screen Pro purchase surface — mood spectrum glass aesthetic, StoreKit 2 via `SubscriptionManager`.
struct PaywallView: View {
    let source: PaywallSource

    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    init(source: PaywallSource = .general) {
        self.source = source
    }

    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var selectedProductID: String?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var showPendingAlert = false
    @State private var showRestoreFailedAlert = false
    @State private var presentedLegal: AppLegalLinks.Document?
    @State private var didDismissForPro = false

    private let footerMuted = Color.white.opacity(0.54)
    private let complianceMuted = Color.white.opacity(0.50)

    private let benefitColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                PaywallMeshBackdrop(reduceMotion: reduceMotion)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        headerSection
                            .padding(.top, 4)

                        contextualValueSection
                            .padding(.top, 24)

                        contentSection
                            .padding(.top, 24)

                        footerSection
                            .padding(.top, 28)
                            .padding(.bottom, 28)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    closeButton
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task {
            await reloadProducts()
        }
        .onAppear {
            dismissIfProAlreadyOwned()
        }
        .onChange(of: subscriptionManager.isPro) { _, isPro in
            guard isPro else { return }
            dismissIfProAlreadyOwned()
        }
        .alert(
            localization.text(.paywallPendingMessage),
            isPresented: $showPendingAlert
        ) {
            Button(localization.text(.commonOk), role: .cancel) {}
        }
        .alert(
            localization.text(.paywallRestoreFailed),
            isPresented: $showRestoreFailedAlert
        ) {
            Button(localization.text(.commonOk), role: .cancel) {}
        }
        .sheet(item: $presentedLegal) { document in
            NavigationStack {
                LegalDocumentView(document: document)
                    .environmentObject(localization)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(localization.text(.commonDone)) {
                                presentedLegal = nil
                            }
                            .foregroundStyle(.primary)
                        }
                    }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            PaywallBrandMark(size: 76)
                .padding(.top, 8)

            Text(AppBranding.productName(for: localization.effectiveLanguage))
                .font(.largeTitle.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(localization.text(.aboutAppBrandTagline))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.58))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .tracking(0.3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Contextual value (Plan A + benefit grid)

    private var contextualValueSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(localization.text(source.headlineKey))
                    .font(.title3.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitleKey = source.subtitleKey {
                    Text(localization.text(subtitleKey))
                        .font(.footnote)
                        .foregroundStyle(Color.white.opacity(0.52))
                        .lineSpacing(6)
                        .tracking(0.25)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            LazyVGrid(columns: benefitColumns, spacing: 12) {
                ForEach(source.proBulletKeys, id: \.rawValue) { key in
                    benefitTile(key)
                }
            }

            Text(localization.text(.paywallFreeIncludes))
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.38))
                .lineSpacing(5)
                .tracking(0.2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func benefitTile(_ bulletKey: LKey) -> some View {
        let visual = PaywallBenefitVisual(key: bulletKey)

        return VStack(alignment: .leading, spacing: 10) {
            Image(systemName: visual.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(visual.iconGradient)
                .shadow(color: visual.glowColor.opacity(0.35), radius: 6)

            Text(localization.text(visual.titleKey))
                .font(.subheadline.weight(.bold))
                .tracking(0.3)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text(localization.text(bulletKey))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .tracking(0.15)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        }
    }

    // MARK: - Content (loading / error / products)

    @ViewBuilder
    private var contentSection: some View {
        if isLoading {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 80)
        } else if loadFailed || subscriptionManager.products.isEmpty {
            emptyCatalogView
        } else {
            productCardsSection
        }
    }

    private var emptyCatalogView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.white.opacity(0.35))

            Text(localization.text(.paywallLoadFailed))
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(5)

            Button {
                Task { await reloadProducts() }
            } label: {
                Text(localization.text(.paywallRetry))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    }
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var productCardsSection: some View {
        let annual = product(matching: ProProductID.annual)
        let lifetime = product(matching: ProProductID.lifetime)
        let visible = [annual, lifetime].compactMap { $0 }
        let singleProduct = visible.count == 1

        return VStack(spacing: 14) {
            if let annual {
                planCard(product: annual, plan: .annual, fillsWidth: singleProduct)
            }
            if let lifetime {
                planCard(product: lifetime, plan: .lifetime, fillsWidth: singleProduct)
            }
        }
    }

    // MARK: - Plan card

    private enum PlanKind {
        case annual
        case lifetime
    }

    private func planCard(product: Product, plan: PlanKind, fillsWidth: Bool) -> some View {
        let isSelected = selectedProductID == product.id
        let isLifetime = plan == .lifetime

        return Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                selectedProductID = product.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(planTitle(plan))
                            .font(.headline.weight(.semibold))
                            .tracking(0.35)
                            .foregroundStyle(.white)

                        Text(planSubtitle(plan))
                            .font(.footnote)
                            .foregroundStyle(Color.white.opacity(0.52))
                            .lineSpacing(5)
                            .tracking(0.2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    if isLifetime {
                        lifetimeBadge
                    }
                }

                Text(product.displayPrice)
                    .font(.title2.weight(.bold))
                    .tracking(0.4)
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .padding(18)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isLifetime {
                    lifetimePlanCardChrome
                } else {
                    annualPlanCardChrome(isSelected: isSelected)
                }
            }
            .scaleEffect(isSelected ? 1.015 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var lifetimePlanCardChrome: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        return ZStack {
            shape
                .fill(AppTheme.cardBackground.opacity(0.85))
            shape
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
            shape
                .fill(PaywallRainbowPalette.lifetimeInnerWash)
                .opacity(0.14)
        }
        .overlay {
            shape.stroke(PaywallRainbowPalette.cardRimLinearGradient, lineWidth: 1.6)
        }
        .overlay {
            shape
                .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                .blendMode(.overlay)
        }
        .shadow(color: PaywallRainbowPalette.lifetimeRimGlowCyan, radius: 10, y: 3)
        .shadow(color: PaywallRainbowPalette.lifetimeRimGlowPurple, radius: 6, y: 2)
        .clipShape(shape)
    }

    private func annualPlanCardChrome(isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        return shape
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .overlay {
                shape.stroke(
                    Color.white.opacity(isSelected ? 0.22 : 0.1),
                    lineWidth: isSelected ? 1 : 0.5
                )
            }
    }

    private var lifetimeBadge: some View {
        Text(localization.text(.paywallBestValue))
            .font(.system(size: 10, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule(style: .continuous)
                    .fill(PaywallRainbowPalette.laserBadgeGradient)
                    .shadow(color: PaywallRainbowPalette.spectrumPurple.opacity(0.45), radius: 6, y: 2)
            }
    }

    // MARK: - Footer (CTA + compliance + links)

    private var footerSection: some View {
        VStack(spacing: 14) {
            PaywallBreathingCTAButton(
                title: localization.text(.paywallCtaUnlock),
                isLoading: isPurchasing,
                isDisabled: primaryActionDisabled,
                reduceMotion: reduceMotion,
                action: { Task { await purchaseSelected() } }
            )

            VStack(spacing: 20) {
                Text(localization.text(.paywallComplianceRenewal))
                    .font(.system(size: 12))
                    .foregroundStyle(complianceMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .tracking(0.15)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)

                legalLinksRow
            }
        }
    }

    private var legalLinksRow: some View {
        HStack(spacing: 0) {
            footerLink(localization.text(.paywallRestore), emphasized: true) {
                Task { await restorePurchases() }
            }
            .disabled(isRestoring || isPurchasing)

            Text("·")
                .foregroundStyle(footerMuted)
                .padding(.horizontal, 8)

            footerLink(localization.text(.aboutAppTerms)) {
                presentedLegal = .termsOfUse
            }

            Text("·")
                .foregroundStyle(footerMuted)
                .padding(.horizontal, 8)

            footerLink(localization.text(.aboutAppPrivacy)) {
                presentedLegal = .privacyPolicy
            }
        }
        .font(.footnote)
        .tracking(0.2)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.42))
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localization.text(.paywallCloseA11y))
    }

    // MARK: - Helpers

    private var primaryActionDisabled: Bool {
        isLoading
            || loadFailed
            || subscriptionManager.products.isEmpty
            || selectedProductID == nil
            || isPurchasing
            || isRestoring
    }

    private func product(matching id: String) -> Product? {
        subscriptionManager.products.first { $0.id == id }
    }

    private var selectedProduct: Product? {
        guard let selectedProductID else { return nil }
        return product(matching: selectedProductID)
    }

    private func planTitle(_ plan: PlanKind) -> String {
        switch plan {
        case .annual:
            return localization.text(.paywallPlanAnnualTitle)
        case .lifetime:
            return localization.text(.paywallPlanLifetimeTitle)
        }
    }

    private func planSubtitle(_ plan: PlanKind) -> String {
        switch plan {
        case .annual:
            return localization.text(.paywallPlanAnnualSubtitle)
        case .lifetime:
            return localization.text(.paywallPlanLifetimeSubtitle)
        }
    }

    private func footerLink(
        _ title: String,
        emphasized: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .fontWeight(emphasized ? .medium : .regular)
                .foregroundStyle(footerMuted)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func reloadProducts() async {
        isLoading = true
        loadFailed = false
        await subscriptionManager.loadProducts()
        isLoading = false
        loadFailed = subscriptionManager.products.isEmpty
        applyDefaultSelection()
    }

    private func applyDefaultSelection() {
        if product(matching: ProProductID.lifetime) != nil {
            selectedProductID = ProProductID.lifetime
        } else if product(matching: ProProductID.annual) != nil {
            selectedProductID = ProProductID.annual
        } else {
            selectedProductID = subscriptionManager.products.first?.id
        }
    }

    private func purchaseSelected() async {
        guard let product = selectedProduct else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await subscriptionManager.purchase(product)
            switch result {
            case .success:
                dismissIfProAlreadyOwned()
            case .cancelled:
                break
            case .pending:
                showPendingAlert = true
            }
        } catch {
            // StoreKit errors other than user cancel — keep paywall open; user can retry.
        }
    }

    private func restorePurchases() async {
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await subscriptionManager.restorePurchases()
            if subscriptionManager.isPro {
                triggerSuccessHaptic()
                dismissIfProAlreadyOwned()
            }
        } catch {
            showRestoreFailedAlert = true
        }
    }

    private func dismissIfProAlreadyOwned() {
        guard subscriptionManager.isPro, !didDismissForPro else { return }
        didDismissForPro = true
        triggerSuccessHaptic()
        dismiss()
    }

    private func triggerSuccessHaptic() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Benefit tile visuals

private struct PaywallBenefitVisual {
    let titleKey: LKey
    let icon: String
    let iconGradient: LinearGradient
    let glowColor: Color

    init(key: LKey) {
        switch key {
        case .paywallBulletTimeline:
            titleKey = .paywallTileTimelineTitle
            icon = "calendar.badge.clock"
            iconGradient = LinearGradient(
                colors: [Color(hex: "69B7CE"), Color(hex: "8C76A1")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            glowColor = PaywallRainbowPalette.spectrumCyan
        case .paywallBulletNotesPhotos:
            titleKey = .paywallTileNotesPhotosTitle
            icon = "photo.on.rectangle.angled"
            iconGradient = LinearGradient(
                colors: [Color(hex: "E8B84A"), Color(hex: "C65840")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            glowColor = Color(hex: "E8B84A")
        case .paywallBulletReport:
            titleKey = .paywallTileReportTitle
            icon = "chart.line.uptrend.xyaxis"
            iconGradient = LinearGradient(
                colors: [Color(hex: "8C76A1"), Color(hex: "69B7CE")],
                startPoint: .leading,
                endPoint: .trailing
            )
            glowColor = PaywallRainbowPalette.spectrumPurple
        case .paywallBulletBillTop:
            titleKey = .paywallTileBillTopTitle
            icon = "crown.fill"
            iconGradient = LinearGradient(
                colors: [Color(hex: "E8B84A"), Color(hex: "5F9E7A")],
                startPoint: .top,
                endPoint: .bottom
            )
            glowColor = Color(hex: "E8B84A")
        default:
            titleKey = key
            icon = "sparkles"
            iconGradient = LinearGradient(
                colors: [.white, PaywallRainbowPalette.spectrumCyan],
                startPoint: .top,
                endPoint: .bottom
            )
            glowColor = .white
        }
    }
}

// MARK: - Mesh backdrop

private struct PaywallMeshBackdrop: View {
    let reduceMotion: Bool

    var body: some View {
        Group {
            if reduceMotion {
                staticMesh
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 20)) { timeline in
                    animatedMesh(phase: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
    }

    private var staticMesh: some View {
        meshLayer(phase: 0)
    }

    private func animatedMesh(phase: TimeInterval) -> some View {
        meshLayer(phase: phase)
    }

    private func meshLayer(phase: TimeInterval) -> some View {
        let drift = Float(sin(phase * 0.35) * 0.06)
        let points: [SIMD2<Float>] = [
            SIMD2(0, 0), SIMD2(0.5 + drift, 0), SIMD2(1, 0),
            SIMD2(0, 0.5), SIMD2(0.5, 0.5 - drift * 0.5), SIMD2(1, 0.5),
            SIMD2(0, 1), SIMD2(0.5 - drift, 1), SIMD2(1, 1),
        ]
        let colors: [Color] = [
            PaywallRainbowPalette.spectrumPurple.opacity(0.1),
            .clear,
            PaywallRainbowPalette.spectrumCyan.opacity(0.08),
            .clear,
            PaywallRainbowPalette.spectrumPurple.opacity(0.12),
            .clear,
            PaywallRainbowPalette.spectrumCyan.opacity(0.1),
            .clear,
            PaywallRainbowPalette.spectrumPurple.opacity(0.08),
        ]

        return MeshGradient(width: 3, height: 3, points: points, colors: colors)
            .blur(radius: 42)
    }
}

// MARK: - Breathing CTA

private struct PaywallBreathingCTAButton: View {
    let title: String
    let isLoading: Bool
    let isDisabled: Bool
    let reduceMotion: Bool
    let action: () -> Void

    var body: some View {
        Group {
            if reduceMotion {
                ctaBody(scale: 1)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 24)) { timeline in
                    let phase = timeline.date.timeIntervalSinceReferenceDate
                    let scale = 1 + 0.018 * (sin(phase * 2 * .pi / 1.6) + 1) / 2
                    ctaBody(scale: scale)
                }
            }
        }
    }

    private func ctaBody(scale: CGFloat) -> some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .tracking(0.5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .foregroundStyle(.white)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(PaywallRainbowPalette.ctaGradient)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    }
                    .shadow(color: PaywallRainbowPalette.spectrumPurple.opacity(0.35), radius: 14, y: 8)
            }
            .scaleEffect(scale)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
    }
}

// MARK: - Legal sheet item

extension AppLegalLinks.Document: Identifiable {
    var id: String {
        switch self {
        case .privacyPolicy: return "privacyPolicy"
        case .termsOfUse: return "termsOfUse"
        case .technicalSupport: return "technicalSupport"
        }
    }
}

#Preview {
    PaywallView(source: .monthHistory)
        .environmentObject(LocalizationManager())
}
