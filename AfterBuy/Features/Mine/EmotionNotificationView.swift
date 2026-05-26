import SwiftUI

struct EmotionNotificationView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var appSettings: AppSettings
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                MineSettingsCard {
                    MineSettingsToggleRow(
                        icon: "bell.badge",
                        title: localization.text(.mineReminder),
                        isOn: $appSettings.emotionAlertEnabled
                    )
                    MineSettingsDivider()
                    MineSettingsToggleRow(
                        icon: "exclamationmark.triangle",
                        title: localization.text(.mineAlertHighRiskOnly),
                        isOn: $appSettings.emotionAlertHighRiskOnly
                    )
                    MineSettingsDivider()
                    Menu {
                        ForEach(appSettings.emotionAlertCooldownOptions, id: \.self) { day in
                            Button(cooldownLabel(day)) {
                                appSettings.emotionAlertCooldownDays = day
                            }
                        }
                    } label: {
                        MineSettingsActionRow(
                            icon: "clock.arrow.circlepath",
                            title: localization.text(.mineAlertCooldownTitle),
                            value: cooldownLabel(appSettings.emotionAlertCooldownDays)
                        )
                    }
                    .buttonStyle(MineRowButtonStyle())
                }

                emotionNotificationTipCard
                    .padding(.top, 6)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle(localization.text(.mineEmotionNotificationHub))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.pageBackground, for: .navigationBar)
    }

    private var emotionNotificationTipCard: some View {
        MineSettingsExplanationTipCard(icon: "lightbulb.fill", glowTint: AppTheme.accentSecondary) {
            VStack(alignment: .leading, spacing: 8) {
                Text(localization.text(.mineAlertScope))
                Text(localization.text(
                    appSettings.emotionAlertHighRiskOnly
                        ? .mineAlertHighRiskOnlyHintOn
                        : .mineAlertHighRiskOnlyHintOff
                ))
                Text(
                    String(
                        format: localization.text(.mineAlertCooldownHint),
                        locale: localization.locale,
                        appSettings.emotionAlertCooldownDescription
                    )
                )
            }
        }
    }

    private func cooldownLabel(_ day: Int) -> String {
        switch day {
        case 1: return localization.text(.mineAlertCooldownOption1)
        case 3: return localization.text(.mineAlertCooldownOption3)
        case 7: return localization.text(.mineAlertCooldownOption7)
        default: return "\(day)"
        }
    }
}
