//
//  ContentView.swift
//  AfterBuy
//
//  Created by James Liu on 2026/5/9.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var appSettings: AppSettings
    @EnvironmentObject private var currencyManager: CurrencyManager
    @EnvironmentObject private var notificationCenterStore: NotificationCenterStore
    @EnvironmentObject private var appSyncState: AppSyncState

    @AppStorage(OnboardingStorage.completedKey) private var hasCompletedOnboarding = false
    @State private var showOnboarding = false
    @State private var didBootstrap = false
    @State private var initialImportTimeoutTask: Task<Void, Never>?

    private static let initialImportTimeoutSeconds: UInt64 = 15

    var body: some View {
        Group {
            if appSyncState.isWaitingForInitialImport {
                InitialCloudImportView(
                    onSkip: {
                        releaseInitialImportGate()
                    }
                )
                .environmentObject(localizationManager)
                .environmentObject(appSyncState)
            } else {
                RootTabView()
            }
        }
        .task {
            await bootstrapIfNeeded()
        }
        .onChange(of: appSyncState.isWaitingForInitialImport) { _, waiting in
            if waiting {
                scheduleInitialImportTimeout()
            } else {
                initialImportTimeoutTask?.cancel()
                initialImportTimeoutTask = nil
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            appSyncState.refreshICloudAvailability()
            currencyManager.refreshIfFollowingSystem()
            localizationManager.refreshIfFollowingSystem()
        }
        .onChange(of: appSyncState.isWaitingForInitialImport) { _, waiting in
            presentOnboardingIfNeeded(importGateCleared: !waiting)
        }
        .onAppear {
            presentOnboardingIfNeeded(importGateCleared: !appSyncState.isWaitingForInitialImport)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isReviewMode: false)
                .environmentObject(localizationManager)
        }
        .onChange(of: hasCompletedOnboarding) { _, completed in
            if completed {
                showOnboarding = false
            }
        }
    }

    private func presentOnboardingIfNeeded(importGateCleared: Bool) {
        guard importGateCleared, !hasCompletedOnboarding, !showOnboarding else { return }
        showOnboarding = true
    }

    @MainActor
    private func bootstrapIfNeeded() async {
        guard !didBootstrap else { return }
        didBootstrap = true

        await LocalDataMigrationService.runIfNeeded(
            using: PersistenceController.shared.modelContainer
        )
        UserProfileConsolidation.consolidateIfNeeded(in: modelContext)
        AppPreferencesConsolidation.consolidateIfNeeded(in: modelContext)
        appSettings.configure(modelContext: modelContext)
        notificationCenterStore.configure(modelContext: modelContext)
        localizationManager.configure(modelContext: modelContext)
        appSyncState.refreshICloudAvailability()

        CloudKitBootstrap.evaluateInitialImportGate(
            modelContext: modelContext,
            appSyncState: appSyncState
        )

        CloudSyncNotificationObserver.shared.start(appSyncState: appSyncState) {
            SyncedStoreRefreshCoordinator.refreshAfterRemoteChange(
                modelContext: modelContext,
                appSettings: appSettings,
                notificationStore: notificationCenterStore,
                localization: localizationManager
            )
        }

        ICloudIdentityObserver.shared.start(appSyncState: appSyncState) {
            CloudKitBootstrap.evaluateInitialImportGate(
                modelContext: modelContext,
                appSyncState: appSyncState
            )
            SyncedStoreRefreshCoordinator.refreshAfterRemoteChange(
                modelContext: modelContext,
                appSettings: appSettings,
                notificationStore: notificationCenterStore,
                localization: localizationManager
            )
        }

        if appSyncState.isWaitingForInitialImport {
            scheduleInitialImportTimeout()
        }

        reconcileAppReviewTransactionCount()
    }

    @MainActor
    private func reconcileAppReviewTransactionCount() {
        let expenseRaw = RecordType.expense.rawValue
        let descriptor = FetchDescriptor<TransactionRecord>(
            predicate: #Predicate { record in
                record.deletedAt == nil && record.typeRaw == expenseRaw
            }
        )
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        AppReviewManager.shared.reconcileTransactionCount(with: count)
    }

    private func releaseInitialImportGate() {
        initialImportTimeoutTask?.cancel()
        initialImportTimeoutTask = nil
        CloudKitBootstrap.releaseInitialImportGate(appSyncState: appSyncState)
    }

    private func scheduleInitialImportTimeout() {
        initialImportTimeoutTask?.cancel()
        initialImportTimeoutTask = Task {
            try? await Task.sleep(for: .seconds(Self.initialImportTimeoutSeconds))
            await MainActor.run {
                guard appSyncState.isWaitingForInitialImport else { return }
                releaseInitialImportGate()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LocalizationManager())
        .environmentObject(AppSettings())
        .environmentObject(NotificationCenterStore())
        .environmentObject(AppSyncState())
        .modelContainer(PersistenceController.inMemoryForPreviews().modelContainer)
}
