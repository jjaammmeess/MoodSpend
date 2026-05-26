//
//  AfterBuyApp.swift
//  AfterBuy
//
//  Created by James Liu on 2026/5/9.
//

import SwiftData
import SwiftUI
import UIKit

@main
struct AfterBuyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var localizationManager = LocalizationManager()
    @StateObject private var appSettings = AppSettings()
    @StateObject private var currencyManager = CurrencyManager()
    @StateObject private var notificationCenterStore = NotificationCenterStore()
    @StateObject private var appSyncState = AppSyncState()
    @StateObject private var appPeriod = AppPeriodContext.shared

    private let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(localizationManager)
                .environmentObject(appSettings)
                .environmentObject(currencyManager)
                .environmentObject(notificationCenterStore)
                .environmentObject(appSyncState)
                .environmentObject(appPeriod)
                .environment(\.locale, localizationManager.locale)
                .preferredColorScheme(appSettings.themeMode.preferredColorScheme)
        }
        .modelContainer(persistenceController.modelContainer)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if CloudSyncStorage.isUserSyncEnabled {
            application.registerForRemoteNotifications()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        completionHandler(.newData)
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .phone ? .portrait : .all
    }
}
