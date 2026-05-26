import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DataManagementView: View {
    private struct AlertMessage: Identifiable {
        let id = UUID()
        let text: String
    }

    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var appSettings: AppSettings
    @EnvironmentObject private var notificationStore: NotificationCenterStore
    @EnvironmentObject private var appSyncState: AppSyncState
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TransactionRecord> { $0.deletedAt == nil }) private var records: [TransactionRecord]
    @Query(
        filter: #Predicate<CustomOption> { $0.deletedAt == nil },
        sort: \CustomOption.createdAt,
        order: .reverse
    ) private var customOptions: [CustomOption]

    @State private var exportDocument = TextFileDocument(text: "")
    @State private var exportType: UTType = .json
    @State private var exportFilename = ""
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var showClearConfirm = false
    @State private var showRestoreModeDialog = false
    @State private var showRestoreReplaceConfirm = false
    @State private var alertMessage: AlertMessage?
    @State private var pendingRestoreData: Data?
    @State private var pendingRestoreSummary: BackupValidationSummary?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                CloudSyncSettingsSection()

                VStack(alignment: .leading, spacing: 10) {
                    MineSettingsGroupHeader(title: localization.text(.mineBackup))
                    MineSettingsCard {
                        Button {
                            exportBackupJSON()
                        } label: {
                            MineSettingsActionRow(
                                icon: "externaldrive",
                                title: localization.text(.mineBackup),
                                value: localization.text(.mineExportJSON)
                            )
                        }
                        .buttonStyle(MineRowButtonStyle())

                        MineSettingsDivider()

                        Button {
                            exportCSV()
                        } label: {
                            MineSettingsActionRow(
                                icon: "doc.text",
                                title: localization.text(.mineExport),
                                value: localization.text(.mineExportCSV)
                            )
                        }
                        .buttonStyle(MineRowButtonStyle())

                        MineSettingsDivider()

                        Button {
                            showImporter = true
                        } label: {
                            MineSettingsActionRow(
                                icon: "arrow.clockwise.circle",
                                title: localization.text(.mineImportBackup),
                                value: localization.text(.mineImportSelect)
                            )
                        }
                        .buttonStyle(MineRowButtonStyle())
                    }

                    MineSettingsTipCard(
                        text: localization.text(.mineBackupScope),
                        palette: .spending
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    MineSettingsGroupHeader(title: localization.text(.mineDataDangerZone))
                    MineSettingsCard {
                        Button(role: .destructive) {
                            showClearConfirm = true
                        } label: {
                            MineSettingsActionRow(
                                icon: "trash",
                                title: localization.text(.mineClearData),
                                titleColor: AppTheme.accentRisk,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(MineRowButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle(localization.text(.mineDataManagementHub))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.pageBackground, for: .navigationBar)
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: exportType,
            defaultFilename: exportFilename
        ) { _ in }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                prepareRestore(from: url)
            case .failure:
                alertMessage = AlertMessage(text: localization.text(.mineRestoreFailed))
            }
        }
        .confirmationDialog(
            localization.text(.mineRestoreModeTitle),
            isPresented: $showRestoreModeDialog,
            titleVisibility: .visible
        ) {
            Button(localization.text(.mineRestoreModeMerge)) {
                applyRestore(mode: .merge)
            }
            Button(localization.text(.mineRestoreModeReplace), role: .destructive) {
                showRestoreReplaceConfirm = true
            }
            Button(localization.text(.commonCancel), role: .cancel) {
                clearPendingRestore()
            }
        } message: {
            Text(restorePreviewText)
        }
        .confirmationDialog(
            localization.text(.mineRestoreReplaceConfirmTitle),
            isPresented: $showRestoreReplaceConfirm,
            titleVisibility: .visible
        ) {
            Button(localization.text(.mineRestoreModeReplace), role: .destructive) {
                applyRestore(mode: .replace)
            }
            Button(localization.text(.commonCancel), role: .cancel) {
                clearPendingRestore()
            }
        } message: {
            Text(localization.text(.mineRestoreReplaceConfirmMessage))
        }
        .alert(item: $alertMessage) { item in
            Alert(
                title: Text(localization.text(.mineTitle)),
                message: Text(item.text),
                dismissButton: .default(Text(localization.text(.commonDone)))
            )
        }
        .sheet(isPresented: $showClearConfirm, onDismiss: { showClearConfirm = false }) {
            clearDataConfirmSheet
        }
        .onAppear {
            if exportFilename.isEmpty {
                exportFilename = localization.text(.mineExportFilenameBackupBase)
            }
        }
    }

    private var clearDataConfirmSheet: some View {
        AppDestructiveConfirmSheet(
            title: localization.text(.mineClearDataConfirm),
            message: localization.text(.mineClearDataMessage),
            systemImage: "exclamationmark.triangle.fill",
            confirmTitle: localization.text(.commonDelete),
            cancelTitle: localization.text(.commonCancel),
            onConfirm: {
                DataManagementService.clearAllRecords(
                    modelContext: modelContext,
                    records: records,
                    notificationStore: notificationStore
                )
                showClearConfirm = false
            },
            onCancel: {
                showClearConfirm = false
            }
        ) {
            AppDestructiveConfirmMetricCard(
                icon: "tray.full",
                title: localization.text(.mineClearData),
                value: clearDataScopeSummary
            )
        }
        .appDestructiveConfirmSheetStyle(height: 368)
    }

    private var clearDataScopeSummary: String {
        let total = records.reduce(0) { $0 + $1.amount }
        return String(
            format: localization.text(.analysisDayBillsGallerySummary),
            locale: localization.locale,
            arguments: [records.count, AppFormatter.moneyString(from: total, locale: localization.locale)] as [CVarArg]
        )
    }

    private func exportBackupJSON() {
        do {
            let json = try DataManagementService.buildBackupJSON(
                from: records,
                customOptions: customOptions,
                appSettings: appSettings,
                language: localization.language,
                notifications: notificationStore.items
            )
            exportDocument = TextFileDocument(text: json)
            exportType = .json
            exportFilename = "\(localization.text(.mineExportFilenameBackupBase))-\(AppFormatter.exportDateStamp())"
            showExporter = true
        } catch {
            alertMessage = AlertMessage(text: localization.text(.mineExportFailed))
        }
    }

    private func exportCSV() {
        let csv = DataManagementService.buildCSV(from: records)
        exportDocument = TextFileDocument(text: csv)
        exportType = .commaSeparatedText
        exportFilename = "\(localization.text(.mineExportFilenameBillsBase))-\(AppFormatter.exportDateStamp())"
        showExporter = true
    }

    private var restorePreviewText: String {
        guard let summary = pendingRestoreSummary else {
            return localization.text(.mineRestorePreviewNoData)
        }
        let exportedAt = AppFormatter.dayString(from: summary.exportedAt, locale: localization.locale)
        let range: String = {
            guard let start = summary.earliestRecordAt, let end = summary.latestRecordAt else {
                return localization.text(.mineRestorePreviewNoData)
            }
            return "\(AppFormatter.dayString(from: start, locale: localization.locale)) - \(AppFormatter.dayString(from: end, locale: localization.locale))"
        }()
        let profileFlag = summary.includesProfile
            ? localization.text(.mineRestorePreviewProfileYes)
            : localization.text(.mineRestorePreviewProfileNo)
        return String(
            format: localization.text(.mineRestorePreview),
            locale: localization.locale,
            arguments: [
                "\(summary.recordCount)",
                "\(summary.customOptionCount)",
                "\(summary.notificationCount)",
                profileFlag,
                exportedAt,
                range
            ] as [CVarArg]
        )
    }

    private func applyRestore(mode: RestoreMode) {
        guard let data = pendingRestoreData else { return }
        do {
            let result = try DataManagementService.restoreBackup(
                from: data,
                mode: mode,
                modelContext: modelContext,
                existingRecords: records,
                existingCustomOptions: customOptions,
                appSettings: appSettings,
                notificationStore: notificationStore
            )
            if let restoredLanguage = result.restoredLanguage {
                localization.language = restoredLanguage
            }
            let message = String(
                format: localization.text(.mineRestoreSuccess),
                locale: localization.locale,
                arguments: [
                    "\(result.recordsInserted)",
                    "\(result.customOptionsInserted)",
                    "\(result.notificationsInserted)"
                ] as [CVarArg]
            )
            alertMessage = AlertMessage(text: message)
        } catch {
            alertMessage = AlertMessage(text: localization.text(.mineRestoreFailed))
        }
        clearPendingRestore()
    }

    private func clearPendingRestore() {
        pendingRestoreData = nil
        pendingRestoreSummary = nil
        showRestoreReplaceConfirm = false
    }

    private func prepareRestore(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            alertMessage = AlertMessage(text: localization.text(.mineRestoreFailed))
            return
        }

        pendingRestoreData = data
        do {
            pendingRestoreSummary = try DataManagementService.validateBackup(from: data)
            showRestoreModeDialog = true
        } catch {
            clearPendingRestore()
            alertMessage = AlertMessage(text: localization.text(.mineRestoreInvalid))
        }
    }
}
