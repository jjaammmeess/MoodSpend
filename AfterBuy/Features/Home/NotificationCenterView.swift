import SwiftData
import SwiftUI

struct NotificationCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var notificationStore: NotificationCenterStore
    @State private var selectedTab: NotificationFilterTab = .all
    @State private var selectedDetailItem: AppNotificationItem?
    @State private var showDeleteAllConfirm = false
    let onHandleAction: (AppNotificationItem) -> Void

    init(onHandleAction: @escaping (AppNotificationItem) -> Void = { _ in }) {
        self.onHandleAction = onHandleAction
    }

    private var items: [AppNotificationItem] {
        notificationStore.filteredItems(tab: selectedTab)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("", selection: $selectedTab) {
                    Text(localization.text(.notificationTabAll)).tag(NotificationFilterTab.all)
                    Text(localization.text(.notificationTabWarning)).tag(NotificationFilterTab.warning)
                    Text(localization.text(.notificationTabTask)).tag(NotificationFilterTab.task)
                    Text(localization.text(.notificationTabSystem)).tag(NotificationFilterTab.system)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                if items.isEmpty {
                    EmptyStateBlock(
                        title: localization.text(.notificationEmpty),
                        systemImage: "bell.slash"
                    )
                    .padding(.top, 80)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(items) { item in
                                notificationCard(item)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 18)
                    }
                }
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationTitle(localization.text(.notificationCenterTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localization.text(.commonCancel)) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(localization.text(.notificationMarkAllRead)) {
                            notificationStore.markAllRead(tab: selectedTab)
                        }
                        .disabled(items.isEmpty)

                        Button(localization.text(.notificationDeleteAll), role: .destructive) {
                            showDeleteAllConfirm = true
                        }
                        .disabled(items.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .navigationDestination(item: $selectedDetailItem) { item in
                notificationDetailView(item)
            }
        }
        .onAppear {
            notificationStore.deduplicateRetrospectiveTasks()
        }
        .confirmationDialog(
            localization.text(.notificationDeleteAllConfirmTitle),
            isPresented: $showDeleteAllConfirm,
            titleVisibility: .visible
        ) {
            Button(localization.text(.notificationDeleteAll), role: .destructive) {
                notificationStore.deleteAll(tab: selectedTab)
            }
            Button(localization.text(.commonCancel), role: .cancel) {}
        } message: {
            Text(localization.text(.notificationDeleteAllConfirmMessage))
        }
    }

    private func notificationCard(_ item: AppNotificationItem) -> some View {
        Button {
            notificationStore.markRead(item.id)
            selectedDetailItem = item
        } label: {
            NotificationCardRow(
                item: item,
                relativeTimeText: relativeTime(item.createdAt)
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                notificationStore.delete(item.id)
            } label: {
                Label(localization.text(.commonDelete), systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                notificationStore.togglePin(item.id)
            } label: {
                Label(
                    item.isPinned ? localization.text(.notificationUnpin) : localization.text(.notificationPin),
                    systemImage: item.isPinned ? "pin.slash.fill" : "pin.fill"
                )
            }
            .tint(AppTheme.actionBlue)
        }
    }

    private func notificationDetailView(_ item: AppNotificationItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Circle()
                    .fill(typeColor(item.type).opacity(0.18))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: typeIcon(item.type))
                            .foregroundStyle(typeColor(item.type))
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(relativeTime(item.createdAt))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            if item.action == .openRecordRetrospective,
               let record = RetrospectiveReviewService.linkedRecord(for: item, modelContext: modelContext) {
                retrospectiveRecordDetailCard(record: record)
            } else {
                Text(item.message)
                    .font(.body)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            if item.action != .none {
                Button(actionTitle(for: item.action)) {
                    selectedDetailItem = nil
                    onHandleAction(item)
                    dismiss()
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(AppTheme.actionBlue)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle(localization.text(.notificationDetailTitle))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func typeIcon(_ type: AppNotificationType) -> String {
        switch type {
        case .warning: return "exclamationmark.triangle.fill"
        case .task: return "checklist"
        case .system: return "megaphone.fill"
        }
    }

    private func typeColor(_ type: AppNotificationType) -> Color {
        switch type {
        case .warning: return AppTheme.accentRisk
        case .task: return AppTheme.accentSecondary
        case .system: return AppTheme.actionBlue
        }
    }

    private func actionTitle(for action: AppNotificationAction) -> String {
        switch action {
        case .openAnalysis:
            return localization.text(.notificationActionReview)
        case .openAddRecord:
            return localization.text(.notificationActionAddRecord)
        case .openRecordRetrospective:
            return localization.text(.notificationActionRetrospective)
        case .none:
            return localization.text(.commonCancel)
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let now = Date()
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 60 {
            return localization.text(.notificationTimeJustNow)
        }

        let minutes = seconds / 60
        if minutes < 60 {
            if minutes == 1 {
                return localization.text(.notificationTimeMinuteAgoSingle)
            }
            return localizedTemplate(.notificationTimeMinutesAgo, "\(minutes)")
        }

        let hours = minutes / 60
        if hours < 24 {
            if hours == 1 {
                return localization.text(.notificationTimeHourAgoSingle)
            }
            return localizedTemplate(.notificationTimeHoursAgo, "\(hours)")
        }

        let calendar = Calendar.current
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return localization.text(.notificationTimeYesterday)
        }

        let days = max(1, hours / 24)
        if days <= 7 {
            if days == 1 {
                return localization.text(.notificationTimeDayAgoSingle)
            }
            return localizedTemplate(.notificationTimeDaysAgo, "\(days)")
        }

        let formatter = DateFormatter()
        formatter.locale = localization.locale
        switch localization.effectiveLanguage {
        case .zhHans, .zhHant:
            formatter.dateFormat = "yyyy年M月d日"
        case .en, .system:
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: date)
    }

    private func localizedTemplate(_ key: LKey, _ args: CVarArg...) -> String {
        String(format: localization.text(key), locale: localization.locale, arguments: args)
    }


    private func displayEmotionLabel(for record: TransactionRecord) -> String {
        if let preset = EmotionTag.from(raw: record.emotionRaw) {
            return localization.text(preset.key)
        }
        return record.safeEmotionName
    }

    @ViewBuilder
    private func retrospectiveRecordDetailCard(record: TransactionRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(record.resolvedCategoryForRetrospectiveDisplay(localizedText: localization.text))
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            if !record.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(record.note.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(displayEmotionLabel(for: record))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)

            Text(AppFormatter.moneyString(from: record.amount, locale: localization.locale))
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(AppFormatter.dayString(from: record.createdAt, locale: localization.locale))
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

#Preview {
    NotificationCenterView()
        .environmentObject(LocalizationManager())
        .environmentObject(NotificationCenterStore())
}
