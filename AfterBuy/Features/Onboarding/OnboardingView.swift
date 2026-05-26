import SwiftUI

struct OnboardingView: View {
    /// When `true`, opened from Settings → About; must not mutate onboarding completion state.
    var isReviewMode: Bool = false

    @AppStorage(OnboardingStorage.completedKey) private var hasCompletedOnboarding = false
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    @State private var currentPage = 0

    private let pages = OnboardingPage.all

    var body: some View {
        ZStack {
            onboardingBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if isReviewMode {
                    reviewModeTopBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                } else {
                    Spacer(minLength: 16)
                }

                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        onboardingPage(page, isActive: currentPage == index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(.easeInOut(duration: 0.35), value: currentPage)

                bottomChrome
                    .padding(.horizontal, 24)
                    .padding(.bottom, isReviewMode ? 24 : 40)
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
    }

    // MARK: - Background

    private var onboardingBackground: some View {
        LinearGradient(
            colors: [
                Color(hex: "0B1A2E"),
                Color(hex: "061018"),
                Color(hex: "020408")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Review mode chrome

    private var reviewModeTopBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                    Text(localization.text(.onboardingBack))
                        .font(.system(size: 17, weight: .medium))
                }
                .foregroundStyle(Color.white.opacity(0.88))
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text(localization.text(.onboardingDone))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Page

    private func onboardingPage(_ page: OnboardingPage, isActive: Bool) -> some View {
        VStack(spacing: 28) {
            Spacer(minLength: 12)

            OnboardingBreathingIcon(kind: page.iconKind, isActive: isActive)

            VStack(spacing: 16) {
                Text(localization.text(page.titleKey))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 20)

                Text(localization.text(page.bodyKey))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 28)
            }

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom

    @ViewBuilder
    private var bottomChrome: some View {
        if isLastPage {
            primaryCTAButton
        } else {
            Color.clear
                .frame(height: 52)
        }
    }

    private var isLastPage: Bool {
        currentPage == pages.count - 1
    }

    private var primaryCTAButton: some View {
        Button {
            finishOnboarding()
        } label: {
            Text(localization.text(.onboardingCTA))
                .font(.headline)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background {
                    ZStack {
                        Capsule()
                            .fill(AppTheme.actionBlue)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.22),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
                .shadow(color: AppTheme.actionBlue.opacity(0.45), radius: 16, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func finishOnboarding() {
        if !isReviewMode {
            hasCompletedOnboarding = true
        }
        dismiss()
    }
}

// MARK: - Breathing icon (active page only)

private enum OnboardingIconKind {
    case symbol(systemName: String, gradient: LinearGradient)
    case quickRecordSquircle
}

private struct OnboardingBreathingIcon: View {
    let kind: OnboardingIconKind
    let isActive: Bool

    @State private var breathScale: CGFloat = 1

    private static let breathAnimation = Animation.easeInOut(duration: 1.6).repeatForever(autoreverses: true)
    private static let minScale: CGFloat = 1
    private static let maxScale: CGFloat = 1.06

    var body: some View {
        iconContent
            .scaleEffect(isActive ? breathScale : 0.94)
            .opacity(isActive ? 1 : 0.72)
            .animation(.easeInOut(duration: 0.35), value: isActive)
            .onAppear {
                syncBreathing(with: isActive)
            }
            .onChange(of: isActive) { _, active in
                syncBreathing(with: active)
            }
    }

    @ViewBuilder
    private var iconContent: some View {
        switch kind {
        case .symbol(let systemName, let gradient):
            Image(systemName: systemName)
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(gradient)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
        case .quickRecordSquircle:
            QuickRecordSquircleIcon(
                squircleSize: QuickRecordSquircleMetrics.onboardingSquircleSize,
                showsAmbientGlow: true
            )
        }
    }

    private func syncBreathing(with active: Bool) {
        if active {
            startBreathing()
        } else {
            stopBreathing()
        }
    }

    private func startBreathing() {
        breathScale = Self.minScale
        withAnimation(Self.breathAnimation) {
            breathScale = Self.maxScale
        }
    }

    private func stopBreathing() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            breathScale = Self.minScale
        }
    }
}

// MARK: - Page model

private struct OnboardingPage: Identifiable {
    let id: String
    let iconKind: OnboardingIconKind
    let titleKey: LKey
    let bodyKey: LKey

    static let all: [OnboardingPage] = [
        OnboardingPage(
            id: "awaken",
            iconKind: .symbol(
                systemName: "wind",
                gradient: LinearGradient(
                    colors: [Color(hex: "8FD4E8"), Color(hex: "B8A8E8")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            ),
            titleKey: .onboardingPage1Title,
            bodyKey: .onboardingPage1Body
        ),
        OnboardingPage(
            id: "log",
            iconKind: .quickRecordSquircle,
            titleKey: .onboardingPage2Title,
            bodyKey: .onboardingPage2Body
        ),
        OnboardingPage(
            id: "insight",
            iconKind: .symbol(
                systemName: "aqi.medium",
                gradient: LinearGradient(
                    colors: [Color(hex: "8C76A1"), Color(hex: "4B6FA8"), Color(hex: "69B7CE")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            ),
            titleKey: .onboardingPage3Title,
            bodyKey: .onboardingPage3Body
        ),
        OnboardingPage(
            id: "guard",
            iconKind: .symbol(
                systemName: "hourglass.badge.plus",
                gradient: LinearGradient(
                    colors: [Color(hex: "F2A65A"), Color(hex: "E8875C")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            ),
            titleKey: .onboardingPage4Title,
            bodyKey: .onboardingPage4Body
        ),
        OnboardingPage(
            id: "peace",
            iconKind: .symbol(
                systemName: "icloud.fill",
                gradient: LinearGradient(
                    colors: [Color(hex: "7FC4D8"), Color(hex: "5A9FD4")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            ),
            titleKey: .onboardingPage5Title,
            bodyKey: .onboardingPage5Body
        ),
    ]
}

#Preview("First launch") {
    OnboardingView(isReviewMode: false)
        .environmentObject(LocalizationManager())
}

#Preview("Review mode") {
    NavigationStack {
        OnboardingView(isReviewMode: true)
            .environmentObject(LocalizationManager())
    }
}
