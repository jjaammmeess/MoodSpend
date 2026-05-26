import Foundation
import SwiftData

@Model
final class AppPreferences {
    var singletonId: UUID = PersistenceConfiguration.preferencesSingletonId
    var themeModeRaw: String = AppThemeMode.defaultRawValue
    var languageRaw: String = AppLanguage.defaultPreference.rawValue
    var emotionAlertEnabled: Bool = true
    var emotionAlertHighRiskOnly: Bool = true
    var emotionAlertCooldownDays: Int = 3
    var patternMinCount: Int = 2
    var patternMinRatio: Double = 0.25
    var iCloudSyncEnabled: Bool = CloudSyncStorage.defaultUserEnabled
    var emotionIconStyleRaw: String = EmotionIconStyle.defaultStyle.rawValue
    var updatedAt: Date = Date()

    init(
        singletonId: UUID = PersistenceConfiguration.preferencesSingletonId,
        themeModeRaw: String = AppThemeMode.defaultRawValue,
        languageRaw: String = AppLanguage.defaultPreference.rawValue,
        emotionAlertEnabled: Bool = true,
        emotionAlertHighRiskOnly: Bool = true,
        emotionAlertCooldownDays: Int = 3,
        patternMinCount: Int = 2,
        patternMinRatio: Double = 0.25,
        iCloudSyncEnabled: Bool = CloudSyncStorage.defaultUserEnabled,
        emotionIconStyleRaw: String = EmotionIconStyle.defaultStyle.rawValue,
        updatedAt: Date = Date()
    ) {
        self.singletonId = singletonId
        self.themeModeRaw = themeModeRaw
        self.languageRaw = languageRaw
        self.emotionAlertEnabled = emotionAlertEnabled
        self.emotionAlertHighRiskOnly = emotionAlertHighRiskOnly
        self.emotionAlertCooldownDays = emotionAlertCooldownDays
        self.patternMinCount = patternMinCount
        self.patternMinRatio = patternMinRatio
        self.iCloudSyncEnabled = iCloudSyncEnabled
        self.emotionIconStyleRaw = emotionIconStyleRaw
        self.updatedAt = updatedAt
    }

    var emotionIconStyle: EmotionIconStyle {
        get { EmotionIconStyle.resolved(from: emotionIconStyleRaw) }
        set { emotionIconStyleRaw = newValue.rawValue }
    }

    var themeMode: AppThemeMode {
        get { AppThemeMode.resolved(from: themeModeRaw) }
        set { themeModeRaw = newValue.rawValue }
    }

    var language: AppLanguage {
        get { AppLanguage(rawValue: languageRaw) ?? AppLanguage.defaultPreference }
        set { languageRaw = newValue.rawValue }
    }
}
