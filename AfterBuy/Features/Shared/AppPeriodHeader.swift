import SwiftUI

/// Shared period chrome: five capsules, history shuttle, custom range status — intrinsic height only.
struct AppPeriodHeader: View {
    @EnvironmentObject private var localization: LocalizationManager

    @ObservedObject var period: AppPeriodContext
    @ObservedObject var subscriptionManager: SubscriptionManager

    @Binding var showPaywall: Bool
    @Binding var paywallSource: PaywallSource
    @Binding var showCustomPicker: Bool

    var onPeriodChangeNeedsRollback: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            periodCapsuleRow

            if period.selectedPeriod != .custom {
                historyNavigatorAxis
                    .padding(.horizontal, 16)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        )
                    )
            } else if let status = period.customRangeStatusText(
                localize: { localization.text($0) },
                locale: localization.locale
            ) {
                customRangeStatusText(status)
                    .padding(.horizontal, 16)
                    .transition(.opacity)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .top)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: period.selectedPeriod)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: period.customRange)
    }

    private var periodCapsuleRow: some View {
        HStack(spacing: 6) {
            ForEach(PeriodMode.allCases) { mode in
                periodCapsuleButton(for: mode)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func periodCapsuleButton(for mode: PeriodMode) -> some View {
        Button {
            selectPeriod(mode)
        } label: {
            Text(periodTitle(for: mode))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .buttonStyle(.plain)
        .periodFilterCapsuleStyle(selected: period.selectedPeriod == mode)
    }

    private var historyNavigatorAxis: some View {
        HStack(spacing: 12) {
            shuttleButton(systemName: "chevron.left", enabled: period.canStepBackward(isPro: subscriptionManager.isPro)) {
                let gate = period.stepBackward(isPro: subscriptionManager.isPro)
                if gate == .requiresPaywall {
                    paywallSource = .monthHistory
                    showPaywall = true
                }
            }

            Text(
                period.navigationTitle(
                    localize: { localization.text($0) },
                    locale: localization.locale
                )
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.textPrimary)
            .frame(maxWidth: .infinity)

            shuttleButton(
                systemName: "chevron.right",
                enabled: period.canStepForward(isPro: subscriptionManager.isPro)
            ) {
                let gate = period.stepForward(isPro: subscriptionManager.isPro)
                if gate == .requiresPaywall {
                    paywallSource = .yearView
                    showPaywall = true
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.metricDashboardFill.opacity(0.92))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border.opacity(0.28), lineWidth: 0.5)
        }
    }

    private func customRangeStatusText(_ text: String) -> some View {
        Button {
            showCustomPicker = true
        } label: {
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.metricDashboardFill.opacity(0.92))
                }
        }
        .buttonStyle(.plain)
    }

    private func selectPeriod(_ mode: PeriodMode) {
        let reopenCustomPicker = mode == .custom && period.selectedPeriod == .custom
        let gate = period.selectPeriod(mode, isPro: subscriptionManager.isPro)
        switch gate {
        case .requiresPaywall:
            onPeriodChangeNeedsRollback()
            paywallSource = mode == .year ? .yearView : .monthHistory
            showPaywall = true
        case .applied:
            if mode == .custom, period.customRange == nil || reopenCustomPicker {
                showCustomPicker = true
            }
        }
    }

    private func shuttleButton(
        systemName: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(enabled ? AppTheme.textPrimary : AppTheme.textSecondary.opacity(0.35))
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(AppTheme.cardBackground.opacity(enabled ? 1 : 0.5))
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func periodTitle(for mode: PeriodMode) -> String {
        switch mode {
        case .day: return localization.text(.billsPeriodDay)
        case .week: return localization.text(.billsPeriodWeek)
        case .month: return localization.text(.billsPeriodMonth)
        case .year: return localization.text(.billsPeriodYear)
        case .custom: return localization.text(.billsPeriodCustom)
        }
    }
}
