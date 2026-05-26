import SwiftUI

struct CurrencySettingsView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var currencyManager: CurrencyManager

    var body: some View {
        List {
            Section {
                followSystemRow
            }

            Section {
                ForEach(CurrencyCode.settingsListOrder) { code in
                    currencyRow(code)
                }
            }
        }
        .navigationTitle(localization.text(.mineCurrencySettingsTitle))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var followSystemRow: some View {
        Button {
            currencyManager.followSystem()
        } label: {
            HStack {
                Text(localization.text(.mineCurrencyFollowSystem))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if !currencyManager.isManuallyLocked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.actionBlue)
                }
            }
        }
    }

    private func currencyRow(_ code: CurrencyCode) -> some View {
        Button {
            currencyManager.lock(to: code)
        } label: {
            HStack {
                Text(code.displayName(locale: localization.locale))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if currencyManager.isManuallyLocked, currencyManager.code == code {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.actionBlue)
                }
            }
        }
    }
}
