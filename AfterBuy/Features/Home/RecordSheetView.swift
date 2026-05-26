import PhotosUI
import SwiftData
import SwiftUI
import UIKit

private enum RecordHeroStyle {
    /// Adaptive: readable on hero glass in light and dark mode (fixed #3F6F76 was low-contrast in dark).
    static var ink: Color { AppTheme.textPrimary }
    static var capsuleFill: Color { AppTheme.actionBlue.opacity(0.14) }
    static let amountFont = Font.system(size: 42, weight: .bold, design: .rounded)
}

private struct RecordPhotoAttachment: Identifiable, Equatable {
    let id: UUID
    var data: Data

    init(id: UUID = UUID(), data: Data) {
        self.id = id
        self.data = data
    }
}

private enum CustomEditSession: Identifiable {
    case category(String)
    case emotion(String)

    var id: String {
        switch self {
        case .category(let name): return "edit-cat-\(name)"
        case .emotion(let name): return "edit-emo-\(name)"
        }
    }
}

private enum DeleteCustomSession: Identifiable {
    case category(String)
    case emotion(String)

    var id: String {
        switch self {
        case .category(let name): return "del-cat-\(name)"
        case .emotion(let name): return "del-emo-\(name)"
        }
    }

    var displayName: String {
        switch self {
        case .category(let name), .emotion(let name): return name
        }
    }
}

struct RecordSheetView: View {
    private enum InputField: Hashable {
        case note
    }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var appSettings: AppSettings
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Query(
        filter: #Predicate<CustomOption> { $0.deletedAt == nil },
        sort: \CustomOption.createdAt,
        order: .reverse
    ) private var customOptions: [CustomOption]

    let editingRecord: TransactionRecord?

    @State private var amountText = ""
    @State private var selectedCategoryID: String?
    @State private var selectedEmotionID: String?
    @State private var note = ""
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var photoAttachments: [RecordPhotoAttachment] = []
    @State private var showValidation = false
    @State private var showCustomCategorySheet = false
    @State private var showCustomEmotionDialog = false
    @State private var customCategoryName = ""
    @State private var newCustomCategoryIcon = CustomIconCatalog.defaultCategorySymbol
    @State private var customEmotionName = ""
    @State private var newCustomEmotionBucket: EmotionBucket = .emotional
    @State private var newCustomEmotionIcon = CustomIconCatalog.defaultEmotionSymbol
    @State private var occurredAt = Date()
    @State private var showDatePickerPopover = false
    @State private var showTimePickerPopover = false
    @State private var showAmountCalculator = false
    /// Mirrors the calculator’s main display while the sheet is open.
    @State private var calculatorLiveAmountField = ""
    /// Inner width of the category `LazyVGrid` (from preference) to scale 4 columns on narrow devices.
    @State private var categoryGridInnerWidth: CGFloat = 0
    @State private var emotionGridInnerWidth: CGFloat = 0
    @State private var customEditSession: CustomEditSession?
    @State private var deleteCustomSession: DeleteCustomSession?
    @State private var showDuplicateNameAlert = false
    @State private var showPaywall = false
    @State private var noteLengthCeiling = RecordAttachmentLimits.freeNoteMaxLength
    @State private var photoCountCeiling = RecordAttachmentLimits.freePhotoMaxCount
    @FocusState private var focusedField: InputField?

    init(editingRecord: TransactionRecord? = nil) {
        self.editingRecord = editingRecord
    }

    private var categoryOptions: [CategoryOption] {
        let customCategories = customOptions
            .filter { $0.kind == .category }
            .map {
                CategoryOption(
                    id: "custom.category.\($0.name)",
                    key: nil,
                    customName: $0.name,
                    customIconSymbol: CustomIconCatalog.normalizedCategorySymbol($0.iconSymbolRaw)
                )
            }
        var options = CategoryPreset.options + customCategories
        if let editingRecord,
           !options.contains(where: { $0.id == editingRecord.categoryKey }),
           LKey(rawValue: editingRecord.categoryKey) == nil {
            options.append(
                CategoryOption(
                    id: editingRecord.categoryKey,
                    key: nil,
                    customName: editingRecord.safeCategoryName,
                    customIconSymbol: editingRecord.categoryIconSymbolRaw.map { CustomIconCatalog.normalizedCategorySymbol($0) }
                )
            )
        }
        return options
    }

    private var emotionOptions: [EmotionOption] {
        let iconStyle = appSettings.emotionIconStyle
        let preset = EmotionTag.allCases.map {
            EmotionOption(
                id: $0.rawValue,
                key: $0.key,
                customName: nil,
                colorHex: $0.colorHex,
                iconSymbol: $0.sfSymbolName,
                rasterAssetName: $0.rasterAssetName(for: iconStyle)
            )
        }
        let customEmotion = customOptions
            .filter { $0.kind == .emotion }
            .map {
                EmotionOption(
                    id: "custom.emotion.\($0.name)",
                    key: nil,
                    customName: $0.name,
                    colorHex: $0.colorHex ?? EmotionTag.ritual.colorHex,
                    iconSymbol: CustomIconCatalog.normalizedEmotionSymbol($0.iconSymbolRaw),
                    rasterAssetName: nil
                )
            }
        var options = preset + customEmotion
        if let editingRecord,
           !options.contains(where: { $0.id == editingRecord.emotionRaw }),
           EmotionTag.from(raw: editingRecord.emotionRaw) == nil {
            options.append(
                EmotionOption(
                    id: editingRecord.emotionRaw,
                    key: nil,
                    customName: editingRecord.safeEmotionName,
                    colorHex: editingRecord.emotionColorHex.isEmpty ? EmotionTag.necessity.colorHex : editingRecord.emotionColorHex,
                    iconSymbol: CustomIconCatalog.normalizedEmotionSymbol(editingRecord.emotionIconSymbolRaw),
                    rasterAssetName: nil
                )
            )
        }
        return options
    }

    private var parsedAmount: Double? {
        Double(amountText)
    }

    private var activeEmotionColor: Color {
        guard
            let selectedEmotionID,
            let emotion = emotionOptions.first(where: { $0.id == selectedEmotionID })
        else {
            return AppTheme.actionBlue
        }
        return Color(hex: emotion.colorHex)
    }

    private var activeCategoryColor: Color {
        guard let selectedCategoryID else { return AppTheme.actionBlue }
        return CategoryVisualStyle.selectionAccentColor(for: selectedCategoryID)
    }

    private var canSave: Bool {
        guard let amount = parsedAmount else { return false }
        return amount > 0 && selectedCategoryID != nil && selectedEmotionID != nil
    }

    private var premiumCalculatorSpring: Animation {
        .spring(response: 0.38, dampingFraction: 0.78, blendDuration: 0)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                recordFormContent
                    .scaleEffect(showAmountCalculator ? 0.965 : 1.0)
                    .blur(radius: showAmountCalculator ? 1 : 0)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: showAmountCalculator ? 24 : 0,
                            style: .continuous
                        )
                    )
                    .animation(premiumCalculatorSpring, value: showAmountCalculator)

                amountCalculatorDimLayer

                amountCalculatorPanel(screenHeight: geometry.size.height)
                    .offset(
                        y: showAmountCalculator
                            ? 0
                            : geometry.size.height + geometry.safeAreaInsets.bottom + 100
                    )
                    .ignoresSafeArea(.container, edges: .bottom)
                    .animation(premiumCalculatorSpring, value: showAmountCalculator)
                    .zIndex(2)
            }
        }
    }

    private var recordFormContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                recordTopHeroSection
                categorySection
                emotionSectionGroup
                noteSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle(localization.text(.recordNavTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localization.text(.commonSave)) {
                        save()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(canSave ? AppTheme.actionBlue : AppTheme.textSecondary.opacity(0.62))
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                }
                if focusedField == .note {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button {
                            focusedField = nil
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                        }
                    }
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .onAppear {
            loadEditingDataIfNeeded()
            if editingRecord == nil {
                refreshAttachmentLimits()
            }
        }
        .onChange(of: subscriptionManager.isPro) { _, _ in
            refreshAttachmentLimits()
        }
        .onChange(of: amountText) {
            amountText = sanitizeAmountInput(amountText)
        }
        .onChange(of: note) {
            note = String(note.prefix(noteLengthCeiling))
        }
        .onChange(of: occurredAt) { _, newValue in
            let now = Date()
            if newValue > now {
                occurredAt = now
            }
        }
        .task(id: photoPickerItems) {
            await importPickedPhotos(photoPickerItems)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(source: .recordAttachments)
                .environmentObject(localization)
        }
        .alert(localization.text(.recordValidationTip), isPresented: $showValidation) {
            Button(localization.text(.commonCancel), role: .cancel) {}
        }
        .sheet(isPresented: $showCustomCategorySheet, onDismiss: {
            customCategoryName = ""
            newCustomCategoryIcon = CustomIconCatalog.defaultCategorySymbol
        }) {
            AddCustomCategorySheet(
                name: $customCategoryName,
                selectedIcon: $newCustomCategoryIcon,
                onSave: {
                    addCustomCategory()
                    showCustomCategorySheet = false
                },
                onCancel: {
                    showCustomCategorySheet = false
                }
            )
            .environmentObject(localization)
        }
        .sheet(isPresented: $showCustomEmotionDialog, onDismiss: {
            customEmotionName = ""
            newCustomEmotionBucket = .emotional
            newCustomEmotionIcon = CustomIconCatalog.defaultEmotionSymbol
        }) {
            AddCustomEmotionSheet(
                name: $customEmotionName,
                bucket: $newCustomEmotionBucket,
                selectedIcon: $newCustomEmotionIcon,
                onSave: {
                    addCustomEmotion()
                    showCustomEmotionDialog = false
                },
                onCancel: {
                    showCustomEmotionDialog = false
                }
            )
            .environmentObject(localization)
        }
        .sheet(item: $customEditSession) { session in
            switch session {
            case .category(let oldName):
                EditCustomCategorySheet(
                    oldName: oldName,
                    initialIcon: customOptions.first(where: { $0.kind == .category && $0.name == oldName })
                        .map { CustomIconCatalog.normalizedCategorySymbol($0.iconSymbolRaw) } ?? CustomIconCatalog.defaultCategorySymbol,
                    onSave: { newName, icon in saveRenamedCustomCategory(from: oldName, to: newName, icon: icon) },
                    onCancel: { customEditSession = nil }
                )
                .environmentObject(localization)
            case .emotion(let oldName):
                EditCustomEmotionSheet(
                    oldName: oldName,
                    initialBucket: bucketForCustomEmotion(named: oldName),
                    initialIcon: customOptions.first(where: { $0.kind == .emotion && $0.name == oldName })
                        .map { CustomIconCatalog.normalizedEmotionSymbol($0.iconSymbolRaw) } ?? CustomIconCatalog.defaultEmotionSymbol,
                    onSave: { newName, bucket, icon in saveRenamedCustomEmotion(from: oldName, to: newName, bucket: bucket, icon: icon) },
                    onCancel: { customEditSession = nil }
                )
                .environmentObject(localization)
            }
        }
        .alert(
            String(format: localization.text(.recordCustomDeleteConfirmTitle), deleteCustomSession?.displayName ?? ""),
            isPresented: Binding(
                get: { deleteCustomSession != nil },
                set: { if !$0 { deleteCustomSession = nil } }
            )
        ) {
            Button(localization.text(.commonDelete), role: .destructive) {
                if let session = deleteCustomSession {
                    performDeleteCustom(session)
                }
                deleteCustomSession = nil
            }
            Button(localization.text(.commonCancel), role: .cancel) {
                deleteCustomSession = nil
            }
        } message: {
            Text(localization.text(.recordCustomDeleteConfirmMessage))
        }
        .alert(localization.text(.recordCustomDuplicateName), isPresented: $showDuplicateNameAlert) {
            Button(localization.text(.commonOk), role: .cancel) {}
        }
    }

    private var recordTopHeroSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(localization.text(.recordSubtitle))
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 18) {
                recordHeroAmountRow
                recordHeroDateTimeCapsule
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { recordHeroCardBackground }
        }
    }

    @ViewBuilder
    private var recordHeroCardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        if colorScheme == .dark {
            shape
                .fill(AppTheme.metricDashboardFill)
                .overlay(shape.strokeBorder(AppTheme.border.opacity(0.4), lineWidth: 1))
        } else {
            shape
                .fill(Color.white.opacity(0.28))
                .background(shape.fill(.ultraThinMaterial))
        }
    }

    private var amountPrimaryDisplay: String {
        if showAmountCalculator {
            if calculatorLiveAmountField.isEmpty {
                return localization.text(.recordAmountZeroDisplay)
            }
            return calculatorLiveAmountField
        }
        return amountText.isEmpty ? localization.text(.recordAmountZeroDisplay) : amountText
    }

    // MARK: - Amount calculator overlay

    private var amountCalculatorDimLayer: some View {
        Color.black
            .opacity(showAmountCalculator ? 0.12 : 0)
            .ignoresSafeArea()
            .allowsHitTesting(showAmountCalculator)
            .onTapGesture {
                dismissAmountCalculator()
            }
            .animation(.easeInOut(duration: 0.25), value: showAmountCalculator)
            .zIndex(1)
    }

    /// ~42–45% of screen height (380–400pt on typical phones).
    private func amountCalculatorPanelMaxHeight(screenHeight: CGFloat) -> CGFloat {
        min(400, max(380, screenHeight * 0.435))
    }

    private func amountCalculatorPanel(screenHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Capsule()
                    .fill(Color(.systemGray4).opacity(0.8))
                    .frame(width: 40, height: 4)
                    .padding(.top, 8)

                AmountCalculatorSheet(
                    accentColor: activeEmotionColor,
                    initialAmountText: amountText,
                    onConfirm: { amountText = $0 },
                    onDismiss: dismissAmountCalculator,
                    onLiveAmountDisplayChange: { calculatorLiveAmountField = $0 }
                )
                .environmentObject(localization)
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: amountCalculatorPanelMaxHeight(screenHeight: screenHeight), alignment: .bottom)
            .padding(.bottom, max(12, WindowSafeArea.bottomInset()))
            .background(.ultraThinMaterial)
            .cornerRadius(32, corners: [.topLeft, .topRight])
            .shadow(
                color: Color.black.opacity(showAmountCalculator ? 0.06 : 0),
                radius: 20,
                x: 0,
                y: -5
            )
        }
    }

    private func presentAmountCalculator() {
        showDatePickerPopover = false
        showTimePickerPopover = false
        focusedField = nil
        withAnimation(premiumCalculatorSpring) {
            showAmountCalculator = true
        }
    }

    private func dismissAmountCalculator() {
        withAnimation(premiumCalculatorSpring) {
            showAmountCalculator = false
        }
        calculatorLiveAmountField = ""
    }

    private var recordHeroAmountRow: some View {
        Button {
            presentAmountCalculator()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(AppFormatter.activeCurrencySymbol)
                    .font(.system(size: 24, weight: .regular, design: .rounded))
                    .foregroundStyle(RecordHeroStyle.ink)
                    .padding(.top, 6)

                Text(amountPrimaryDisplay)
                    .font(RecordHeroStyle.amountFont)
                    .monospacedDigit()
                    .foregroundStyle(RecordHeroStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(localization.text(.recordDetailAmount))，\(amountPrimaryDisplay)")
        .accessibilityHint(
            "\(localization.text(.recordAmountCalculatorHint)) \(localization.text(.recordAmountTip))"
        )
    }

    private var recordHeroDateTimeCapsule: some View {
        HStack(spacing: 8) {
            dateCapsuleButton
            timeCapsuleButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dateCapsuleButton: some View {
        Button {
            showTimePickerPopover = false
            showDatePickerPopover = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .medium))
                Text(recordHeroDateString(from: occurredAt))
                    .monospacedDigit()
            }
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(RecordHeroStyle.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(RecordHeroStyle.capsuleFill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        activeEmotionColor.opacity(showDatePickerPopover ? 0.55 : 0.0),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showDatePickerPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 6) {
                DatePicker(
                    "",
                    selection: $occurredAt,
                    in: ...Date(),
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .environment(\.locale, localization.locale)
                .tint(activeEmotionColor)
                .foregroundStyle(.secondary.opacity(0.6))
                .scaleEffect(0.9, anchor: .top)
                .frame(width: 292, height: 286, alignment: .top)
                .clipped()
            }
            .frame(width: 308, alignment: .center)
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 8)
            .presentationBackground(.ultraThinMaterial)
            .presentationCompactAdaptation(.popover)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(localization.text(.recordDateTimeTitle)))
        .accessibilityValue(Text(recordHeroDateString(from: occurredAt)))
        .accessibilityHint(Text(localization.text(.recordDateTimeTip)))
    }

    private var timeCapsuleButton: some View {
        Button {
            showDatePickerPopover = false
            showTimePickerPopover = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 12, weight: .medium))
                Text(AppFormatter.timeString(from: occurredAt, locale: localization.locale))
                    .monospacedDigit()
            }
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(RecordHeroStyle.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(RecordHeroStyle.capsuleFill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        activeEmotionColor.opacity(showTimePickerPopover ? 0.55 : 0.0),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showTimePickerPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 4) {
                DatePicker(
                    "",
                    selection: $occurredAt,
                    in: ...Date(),
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, localization.locale)
                .tint(activeEmotionColor)
                .frame(width: 268, height: 158)
                .clipped()
            }
            .frame(width: 284, alignment: .center)
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 8)
            .presentationBackground(.ultraThinMaterial)
            .presentationCompactAdaptation(.popover)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(localization.text(.recordDateTimeTitle)))
        .accessibilityValue(Text(AppFormatter.timeString(from: occurredAt, locale: localization.locale)))
        .accessibilityHint(Text(localization.text(.recordDateTimeTip)))
    }

    private func recordHeroDateString(from date: Date) -> String {
        let id = localization.locale.identifier.lowercased()
        if id.hasPrefix("zh") {
            let cal = Calendar(identifier: .gregorian)
            let c = cal.dateComponents(in: TimeZone.current, from: date)
            guard let year = c.year, let month = c.month, let day = c.day else { return "" }
            return "\(year)年\(month)月\(day)日"
        }
        return AppFormatter.dayString(from: date, locale: localization.locale)
    }

    private var categoryGridMetrics: CategoryGridLayoutMetrics {
        let w = categoryGridInnerWidth > 8 ? categoryGridInnerWidth : 360
        return CategoryGridLayoutMetrics.forGridWidth(w)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(localization.text(.recordCategoryTitle), systemImage: "square.grid.2x2")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: categoryGridMetrics.columnSpacing), count: 4),
                spacing: categoryGridMetrics.rowSpacing
            ) {
                ForEach(categoryOptions) { category in
                    categoryGridCell(category)
                }
                categoryGridAddSlotCell
            }
            .padding(.vertical, 4)
            .animation(.easeInOut(duration: 0.18), value: selectedCategoryID)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: CategoryGridInnerWidthKey.self, value: proxy.size.width)
                }
            }
            .onPreferenceChange(CategoryGridInnerWidthKey.self) { categoryGridInnerWidth = $0 }
        }
        .recordSheetSectionCard(
            watercolor: .spending,
            selectionTint: selectedCategoryID != nil ? activeCategoryColor.opacity(0.14) : nil
        )
        .animation(.easeInOut(duration: 0.2), value: selectedCategoryID)
    }

    /// Same orb sizing as category grid (4 columns, scales on narrow width).
    private var emotionOrbGridMetrics: CategoryGridLayoutMetrics {
        let w = emotionGridInnerWidth > 8 ? emotionGridInnerWidth : 360
        return CategoryGridLayoutMetrics.forGridWidth(w)
    }

    private var emotionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(localization.text(.recordEmotionTitle), systemImage: "face.smiling")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .accessibilityHint(Text(localization.text(.recordEmotionGuide)))

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: emotionOrbGridMetrics.columnSpacing), count: 4),
                spacing: emotionOrbGridMetrics.rowSpacing
            ) {
                ForEach(emotionOptions) { emotion in
                    emotionGridCell(emotion)
                }
                emotionGridAddSlotCell
            }
            .padding(.vertical, 4)
            .animation(.easeInOut(duration: 0.18), value: selectedEmotionID)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: EmotionGridInnerWidthKey.self, value: proxy.size.width)
                }
            }
            .onPreferenceChange(EmotionGridInnerWidthKey.self) { emotionGridInnerWidth = $0 }
        }
        .recordSheetSectionCard(
            watercolor: .emotion,
            selectionTint: selectedEmotionID != nil ? activeEmotionColor.opacity(0.14) : nil
        )
    }

    /// Mood picker + detached description card (~10pt apart).
    private var emotionSectionGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            emotionSection
            if let selectedEmotionDescription {
                emotionDescriptionCard(description: selectedEmotionDescription)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedEmotionID)
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localization.text(subscriptionManager.isPro ? .recordNoteCaptionPro : .recordNoteCaptionFree))
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            noteWhisperBubble

            if !photoAttachments.isEmpty {
                notePhotoThumbnailStrip
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: photoAttachments.count)
        .padding(.bottom, 4)
    }

    private var noteWhisperBubble: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                if note.isEmpty {
                    Text(localization.text(.recordNotePlaceholder))
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $note)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .textInputAutocapitalization(.never)
                    .frame(minHeight: 92, alignment: .top)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .focused($focusedField, equals: .note)
            }

            HStack(alignment: .center) {
                Text(noteCharacterCountLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer(minLength: 0)
                noteAddPhotoCapsule
            }
        }
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }

    private var noteCharacterCountLabel: String {
        String(
            format: localization.text(.recordNoteCharacterCount),
            locale: localization.locale,
            arguments: ["\(note.count)", "\(noteLengthCeiling)"] as [CVarArg]
        )
    }

    private var remainingPhotoSlots: Int {
        max(0, photoCountCeiling - photoAttachments.count)
    }

    @ViewBuilder
    private var noteAddPhotoCapsule: some View {
        Group {
            if remainingPhotoSlots > 0 {
                PhotosPicker(
                    selection: $photoPickerItems,
                    maxSelectionCount: remainingPhotoSlots,
                    matching: .images
                ) {
                    noteAddPhotoCapsuleLabel
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(noteAddPhotoCapsuleTitle))
            } else if !subscriptionManager.isPro, photoAttachments.count >= RecordAttachmentLimits.freePhotoMaxCount {
                Button {
                    showPaywall = true
                } label: {
                    noteAddPhotoCapsuleLabel
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(localization.text(.recordPhotoProGate)))
            }
        }
        .padding(.trailing, 12)
    }

    private var noteAddPhotoCapsuleLabel: some View {
        HStack(spacing: 5) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 11, weight: .medium))
            Text(noteAddPhotoCapsuleTitle)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(RecordHeroStyle.ink)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private var noteAddPhotoCapsuleTitle: String {
        if !subscriptionManager.isPro, remainingPhotoSlots == 0, !photoAttachments.isEmpty {
            return localization.text(.recordPhotoProGate)
        }
        if photoAttachments.isEmpty {
            return localization.text(.recordAddPhotoReceipt)
        }
        return String(
            format: localization.text(.recordAddMorePhotos),
            locale: localization.locale,
            arguments: [photoAttachments.count, photoCountCeiling] as [CVarArg]
        )
    }

    private var notePhotoThumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(photoAttachments) { attachment in
                    if let image = UIImage(data: attachment.data) {
                        notePhotoThumbnail(image, attachmentID: attachment.id)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func notePhotoThumbnail(_ image: UIImage, attachmentID: UUID) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button {
                removeAttachedPhoto(id: attachmentID)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.white, Color.black.opacity(0.55))
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
            .accessibilityLabel(Text(localization.text(.recordRemovePhoto)))
        }
    }

    private func removeAttachedPhoto(id: UUID) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            photoAttachments.removeAll { $0.id == id }
            photoPickerItems = []
        }
    }

    @MainActor
    private func importPickedPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        var imported: [RecordPhotoAttachment] = []
        for item in items {
            guard photoAttachments.count + imported.count < photoCountCeiling else { break }
            if let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty {
                imported.append(RecordPhotoAttachment(data: data))
            }
        }
        guard !imported.isEmpty else {
            photoPickerItems = []
            return
        }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            photoAttachments.append(contentsOf: imported)
            photoPickerItems = []
        }
    }

    private func save() {
        guard
            let amount = Double(amountText),
            amount > 0,
            let categoryID = selectedCategoryID,
            let emotionID = selectedEmotionID
        else {
            showValidation = true
            return
        }

        guard
            let category = categoryOptions.first(where: { $0.id == categoryID }),
            let emotion = emotionOptions.first(where: { $0.id == emotionID })
        else {
            showValidation = true
            return
        }

        let now = Date()
        let occurred = min(occurredAt, now)

        if let editingRecord {
            editingRecord.amount = amount
            editingRecord.type = .expense
            editingRecord.categoryKey = category.key?.rawValue ?? category.id
            editingRecord.categoryName = categoryName(category)
            editingRecord.emotionRaw = emotion.rawValue
            editingRecord.emotionName = emotionName(emotion)
            editingRecord.emotionColorHex = emotion.colorHex
            editingRecord.emotionBucketRaw = emotion.id.hasPrefix(EmotionGrouping.customEmotionIdPrefix)
                ? (emotionBucketSnapshotRaw(for: emotion) ?? editingRecord.emotionBucketRaw)
                : nil
            editingRecord.categoryIconSymbolRaw = category.id.hasPrefix(CustomOptionMutation.categoryPrefix)
                ? (category.customIconSymbol.map { CustomIconCatalog.normalizedCategorySymbol($0) } ?? CustomIconCatalog.defaultCategorySymbol)
                : nil
            editingRecord.emotionIconSymbolRaw = emotion.id.hasPrefix(EmotionGrouping.customEmotionIdPrefix)
                ? CustomIconCatalog.normalizedEmotionSymbol(emotion.iconSymbol)
                : nil
            editingRecord.note = String(note.prefix(noteLengthCeiling))
            editingRecord.applyImageAttachments(
                Array(photoAttachments.map(\.data).prefix(photoCountCeiling))
            )
            editingRecord.createdAt = occurred
            editingRecord.touchUpdatedAt()
        } else {
            let record = TransactionRecord(
                amount: amount,
                type: .expense,
                categoryKey: category.key?.rawValue ?? category.id,
                categoryName: categoryName(category),
                emotionRaw: emotion.rawValue,
                emotionName: emotionName(emotion),
                emotionColorHex: emotion.colorHex,
                emotionBucketRaw: emotionBucketSnapshotRaw(for: emotion),
                categoryIconSymbolRaw: category.id.hasPrefix(CustomOptionMutation.categoryPrefix)
                    ? (category.customIconSymbol.map { CustomIconCatalog.normalizedCategorySymbol($0) } ?? CustomIconCatalog.defaultCategorySymbol)
                    : nil,
                emotionIconSymbolRaw: emotion.id.hasPrefix(EmotionGrouping.customEmotionIdPrefix)
                    ? CustomIconCatalog.normalizedEmotionSymbol(emotion.iconSymbol)
                    : nil,
                note: String(note.prefix(noteLengthCeiling)),
                imageAttachmentDatas: Array(photoAttachments.map(\.data).prefix(photoCountCeiling)),
                createdAt: occurred
            )
            modelContext.insert(record)
            record.touchUpdatedAt()
        }
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("RecordSheetView save failed: \(error)")
            #endif
            return
        }
        if editingRecord == nil {
            AppReviewManager.shared.recordNewTransactionSaved()
        }
        dismiss()
    }

    private func refreshAttachmentLimits() {
        let existingNoteLength = editingRecord?.note.count ?? note.count
        let existingPhotoCount = editingRecord.map {
            $0.resolvedImageAttachments.count
        } ?? photoAttachments.count
        noteLengthCeiling = RecordAttachmentLimits.noteLengthCeiling(
            isPro: subscriptionManager.isPro,
            existingNoteLength: existingNoteLength
        )
        photoCountCeiling = RecordAttachmentLimits.photoCountCeiling(
            isPro: subscriptionManager.isPro,
            existingPhotoCount: existingPhotoCount
        )
        note = String(note.prefix(noteLengthCeiling))
        if photoAttachments.count > photoCountCeiling {
            photoAttachments = Array(photoAttachments.prefix(photoCountCeiling))
        }
    }

    private func loadEditingDataIfNeeded() {
        guard let editingRecord else { return }
        amountText = String(format: "%.2f", editingRecord.amount)
        selectedCategoryID = editingRecord.categoryKey
        selectedEmotionID = editingRecord.emotionRaw
        note = editingRecord.note
        photoAttachments = editingRecord.resolvedImageAttachments.map { RecordPhotoAttachment(data: $0) }
        let now = Date()
        occurredAt = min(editingRecord.createdAt, now)
        refreshAttachmentLimits()
    }

    private func sanitizeAmountInput(_ raw: String) -> String {
        if raw.isEmpty { return "" }

        let normalized = raw
            .replacingOccurrences(of: "，", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "。", with: ".")

        var output = ""
        var hasDot = false
        var decimalCount = 0

        for ch in normalized {
            if ch.isNumber {
                if hasDot {
                    guard decimalCount < 2 else { continue }
                    decimalCount += 1
                }
                output.append(ch)
                continue
            }
            if ch == "." {
                guard !hasDot else { continue }
                hasDot = true
                output.append(output.isEmpty ? "0." : ".")
            }
        }

        return output
    }

    private var selectedEmotionDescription: String? {
        guard let selectedEmotionID else { return nil }
        guard let preset = EmotionTag.from(raw: selectedEmotionID) else {
            return localization.text(.recordEmotionDescriptionCustom)
        }
        return localization.text(descriptionKey(for: preset))
    }

    private func descriptionKey(for emotion: EmotionTag) -> LKey {
        switch emotion {
        case .pamper: return .recordEmotionDescPamper
        case .necessity: return .recordEmotionDescNecessity
        case .impulse: return .recordEmotionDescImpulse
        case .stress: return .recordEmotionDescStress
        case .social: return .recordEmotionDescSocial
        case .ritual: return .recordEmotionDescRitual
        }
    }

    private func emotionDescriptionCard(description: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(activeEmotionColor.opacity(0.85))
                .padding(.top, 2)
                .accessibilityHidden(true)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(localization.text(.recordEmotionDescriptionTitle)) \(description)")
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                DashboardWatercolorBackground(
                    cornerRadius: 16,
                    palette: .emotion,
                    layout: .metricDefault
                )
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [activeEmotionColor.opacity(0.14), Color.clear],
                            center: UnitPoint(x: 0.08, y: 0.96),
                            startRadius: 0,
                            endRadius: 168
                        )
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    @ViewBuilder
    private func categoryGridCell(_ category: CategoryOption) -> some View {
        let cell = CategoryGridCell(
            title: chipCategoryName(category),
            categoryKey: category.key?.rawValue ?? category.id,
            iconSymbolOverride: category.customIconSymbol,
            isSelected: selectedCategoryID == category.id,
            metrics: categoryGridMetrics
        ) {
            selectedCategoryID = category.id
        }
        if let stored = managedCustomCategoryName(for: category) {
            cell
                .contextMenu {
                    Button {
                        customEditSession = .category(stored)
                    } label: {
                        Label(localization.text(.recordCustomEdit), systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        deleteCustomSession = .category(stored)
                    } label: {
                        Label(localization.text(.recordCustomDelete), systemImage: "trash")
                    }
                }
        } else {
            cell
        }
    }

    @ViewBuilder
    private func emotionGridCell(_ emotion: EmotionOption) -> some View {
        let cell = EmotionGridCell(
            title: chipEmotionName(emotion),
            iconName: emotion.iconSymbol,
            rasterAssetName: emotion.rasterAssetName,
            colorHex: emotion.colorHex,
            isSelected: selectedEmotionID == emotion.id,
            metrics: emotionOrbGridMetrics
        ) {
            selectedEmotionID = emotion.id
        }
        if let stored = managedCustomEmotionName(for: emotion) {
            cell
                .contextMenu {
                    Button {
                        customEditSession = .emotion(stored)
                    } label: {
                        Label(localization.text(.recordCustomEdit), systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        deleteCustomSession = .emotion(stored)
                    } label: {
                        Label(localization.text(.recordCustomDelete), systemImage: "trash")
                    }
                }
        } else {
            cell
        }
    }

    private var categoryGridAddSlotCell: some View {
        GridAddSlotCell(
            title: localization.text(.recordGridAdd),
            accessibilityLabel: localization.text(.recordGridAddCategoryA11y),
            metrics: categoryGridMetrics
        ) {
            showCustomCategorySheet = true
        }
    }

    private var emotionGridAddSlotCell: some View {
        GridAddSlotCell(
            title: localization.text(.recordGridAdd),
            accessibilityLabel: localization.text(.recordGridAddEmotionA11y),
            metrics: emotionOrbGridMetrics
        ) {
            showCustomEmotionDialog = true
        }
    }

    private func managedCustomCategoryName(for option: CategoryOption) -> String? {
        guard option.isCustom else { return nil }
        let name = option.customName
            ?? CustomOptionMutation.customCategorySuffix(fromKey: option.id)
            ?? ""
        guard !name.isEmpty,
              customOptions.contains(where: { $0.kind == .category && $0.name == name })
        else { return nil }
        return name
    }

    private func managedCustomEmotionName(for option: EmotionOption) -> String? {
        guard option.key == nil else { return nil }
        let name = option.customName
            ?? CustomOptionMutation.customEmotionSuffix(fromRaw: option.id)
            ?? ""
        guard !name.isEmpty,
              customOptions.contains(where: { $0.kind == .emotion && $0.name == name })
        else { return nil }
        return name
    }

    private func bucketForCustomEmotion(named name: String) -> EmotionBucket {
        guard let raw = customOptions.first(where: { $0.kind == .emotion && $0.name == name })?.emotionBucketRaw else {
            return .emotional
        }
        return EmotionBucket(rawValue: raw) ?? .emotional
    }

    /// For preset moods returns `nil` (bucket derived from `emotionRaw`). For custom moods, persists home-summary bucket after `CustomOption` is removed.
    private func emotionBucketSnapshotRaw(for emotion: EmotionOption) -> String? {
        guard emotion.id.hasPrefix(EmotionGrouping.customEmotionIdPrefix) else { return nil }
        let suffix = String(emotion.id.dropFirst(EmotionGrouping.customEmotionIdPrefix.count))
        guard let opt = customOptions.first(where: { $0.kind == .emotion && $0.name == suffix }) else {
            return nil
        }
        if let raw = opt.emotionBucketRaw, EmotionBucket(rawValue: raw) != nil {
            return raw
        }
        return EmotionBucket.emotional.rawValue
    }

    private func saveRenamedCustomCategory(from oldName: String, to newName: String, icon: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normIcon = CustomIconCatalog.normalizedCategorySymbol(icon)
        guard let option = customOptions.first(where: { $0.kind == .category && $0.name == oldName }) else {
            customEditSession = nil
            return
        }
        option.iconSymbolRaw = normIcon
        if oldName != trimmed {
            do {
                try CustomOptionMutation.renameCustomCategory(
                    oldName: oldName,
                    newName: trimmed,
                    customOptions: customOptions,
                    in: modelContext
                )
            } catch CustomOptionMutationError.duplicateName {
                showDuplicateNameAlert = true
                return
            } catch {
                showDuplicateNameAlert = true
                return
            }
            let oldID = CustomOptionMutation.categoryKey(forName: oldName)
            let newID = CustomOptionMutation.categoryKey(forName: trimmed)
            if selectedCategoryID == oldID {
                selectedCategoryID = newID
            }
            if let editingRecord, editingRecord.categoryKey == oldID {
                editingRecord.categoryKey = newID
                editingRecord.categoryName = trimmed
            }
        }
        let key = CustomOptionMutation.categoryKey(forName: trimmed)
        let descriptor = FetchDescriptor<TransactionRecord>(
            predicate: #Predicate<TransactionRecord> { $0.categoryKey == key }
        )
        if let rows = try? modelContext.fetch(descriptor) {
            for r in rows {
                r.categoryIconSymbolRaw = normIcon
            }
        }
        try? modelContext.save()
        customEditSession = nil
    }

    private func saveRenamedCustomEmotion(from oldName: String, to newName: String, bucket: EmotionBucket, icon: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normIcon = CustomIconCatalog.normalizedEmotionSymbol(icon)
        guard let option = customOptions.first(where: { $0.kind == .emotion && $0.name == oldName }) else {
            customEditSession = nil
            return
        }
        option.iconSymbolRaw = normIcon
        do {
            try CustomOptionMutation.renameCustomEmotion(
                oldName: oldName,
                newName: trimmed,
                bucket: bucket,
                customOptions: customOptions,
                in: modelContext
            )
            let oldID = CustomOptionMutation.emotionRaw(forName: oldName)
            let newID = CustomOptionMutation.emotionRaw(forName: trimmed)
            if selectedEmotionID == oldID {
                selectedEmotionID = newID
            }
            customEditSession = nil
        } catch CustomOptionMutationError.duplicateName {
            showDuplicateNameAlert = true
        } catch {
            showDuplicateNameAlert = true
        }
    }

    private func performDeleteCustom(_ session: DeleteCustomSession) {
        do {
            switch session {
            case .category(let name):
                try CustomOptionMutation.deleteCustomCategory(name: name, customOptions: customOptions, in: modelContext)
                let id = CustomOptionMutation.categoryKey(forName: name)
                if selectedCategoryID == id { selectedCategoryID = nil }
            case .emotion(let name):
                try CustomOptionMutation.deleteCustomEmotion(name: name, customOptions: customOptions, in: modelContext)
                let id = CustomOptionMutation.emotionRaw(forName: name)
                if selectedEmotionID == id { selectedEmotionID = nil }
            }
        } catch {
            // no-op
        }
    }

    private func addCustomCategory() {
        let trimmed = customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let icon = CustomIconCatalog.normalizedCategorySymbol(newCustomCategoryIcon)
        if !customOptions.contains(where: { $0.kind == .category && $0.name == trimmed }) {
            modelContext.insert(CustomOption(kind: .category, name: trimmed, iconSymbolRaw: icon))
        }
        selectedCategoryID = "custom.category.\(trimmed)"
        customCategoryName = ""
    }

    private func addCustomEmotion() {
        let trimmed = customEmotionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let defaultHex = EmotionTag.ritual.colorHex
        let icon = CustomIconCatalog.normalizedEmotionSymbol(newCustomEmotionIcon)
        if !customOptions.contains(where: { $0.kind == .emotion && $0.name == trimmed }) {
            modelContext.insert(
                CustomOption(
                    kind: .emotion,
                    name: trimmed,
                    colorHex: defaultHex,
                    emotionBucketRaw: newCustomEmotionBucket.rawValue,
                    iconSymbolRaw: icon
                )
            )
        }
        selectedEmotionID = "custom.emotion.\(trimmed)"
        customEmotionName = ""
    }

    private func categoryName(_ option: CategoryOption) -> String {
        if let key = option.key {
            return localization.text(key)
        }
        return option.customName ?? option.id
    }

    private func chipCategoryName(_ option: CategoryOption) -> String {
        guard let key = option.key else {
            return categoryName(option)
        }
        if let shortKey = shortCategoryKey(for: key) {
            return localization.text(shortKey)
        }
        return categoryName(option)
    }

    private func emotionName(_ option: EmotionOption) -> String {
        if let key = option.key {
            return localization.text(key)
        }
        return option.customName ?? option.id
    }

    private func chipEmotionName(_ option: EmotionOption) -> String {
        if let preset = EmotionTag.from(raw: option.id),
           let shortKey = shortEmotionKey(for: preset) {
            return localization.text(shortKey)
        }
        return emotionName(option)
    }

    private func shortCategoryKey(for key: LKey) -> LKey? {
        switch key {
        case .categoryFood: return .categoryShortFood
        case .categoryDaily: return .categoryShortDaily
        case .categoryTransport: return .categoryShortTransport
        case .categoryDigital: return .categoryShortDigital
        case .categoryPet: return .categoryShortPet
        case .categoryTravel: return .categoryShortTravel
        case .categoryClothing: return .categoryShortClothing
        case .categoryEntertainment: return .categoryShortEntertainment
        case .categorySocial: return .categoryShortSocial
        case .categoryMedical: return .categoryShortMedical
        case .categoryLearning: return .categoryShortLearning
        case .categoryHousing: return .categoryShortHousing
        case .categoryOther: return .categoryShortOther
        default: return nil
        }
    }

    private func shortEmotionKey(for emotion: EmotionTag) -> LKey? {
        switch emotion {
        case .pamper: return .emotionShortPamper
        case .necessity: return .emotionShortNecessity
        case .impulse: return .emotionShortImpulse
        case .stress: return .emotionShortStress
        case .social: return .emotionShortSocial
        case .ritual: return .emotionShortRitual
        }
    }
}

private struct AddCustomCategorySheet: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Binding var name: String
    @Binding var selectedIcon: String
    let onSave: () -> Void
    let onCancel: () -> Void

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(localization.text(.recordCustomInputPlaceholder), text: $name)
                }
                Section {
                    CustomIconPicker(symbols: CustomIconCatalog.categorySymbols, selection: $selectedIcon, columns: 6)
                } header: {
                    Text(localization.text(.recordCustomIconSection))
                }
            }
            .navigationTitle(localization.text(.recordAddCustomCategory))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.text(.commonCancel)) {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.text(.recordCustomSave)) {
                        guard !trimmed.isEmpty else { return }
                        onSave()
                    }
                    .disabled(trimmed.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct AddCustomEmotionSheet: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Binding var name: String
    @Binding var bucket: EmotionBucket
    @Binding var selectedIcon: String
    let onSave: () -> Void
    let onCancel: () -> Void

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            CustomEmotionSheetScrollForm {
                CustomEmotionSheetCard {
                    TextField(localization.text(.recordCustomInputPlaceholder), text: $name)
                }

                CustomEmotionSheetLabeledBlock(title: .recordCustomIconSection) {
                    CustomEmotionSheetCard {
                        CustomIconPicker(symbols: CustomIconCatalog.emotionSymbols, selection: $selectedIcon, columns: 6)
                    }
                }

                CustomEmotionSheetLabeledBlock(
                    title: .recordEmotionBucketSection,
                    footer: .recordEmotionBucketHint
                ) {
                    CustomEmotionSheetCard {
                        EmotionBucketTagPicker(selection: $bucket)
                    }
                }
            }
            .navigationTitle(localization.text(.recordAddCustomEmotion))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.text(.commonCancel)) {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.text(.recordCustomSave)) {
                        guard !trimmed.isEmpty else { return }
                        onSave()
                    }
                    .disabled(trimmed.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct EditCustomCategorySheet: View {
    @EnvironmentObject private var localization: LocalizationManager
    let oldName: String
    let initialIcon: String
    let onSave: (String, String) -> Void
    let onCancel: () -> Void
    @State private var draft = ""
    @State private var selectedIcon = ""

    private var trimmed: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(localization.text(.recordCustomInputPlaceholder), text: $draft)
                }
                Section {
                    CustomIconPicker(symbols: CustomIconCatalog.categorySymbols, selection: $selectedIcon, columns: 6)
                } header: {
                    Text(localization.text(.recordCustomIconSection))
                }
            }
            .navigationTitle(localization.text(.recordCustomEditCategoryTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.text(.commonCancel)) {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.text(.commonSave)) {
                        guard !trimmed.isEmpty else { return }
                        onSave(trimmed, selectedIcon)
                    }
                    .disabled(trimmed.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            draft = oldName
            selectedIcon = initialIcon
        }
    }
}

private struct EditCustomEmotionSheet: View {
    @EnvironmentObject private var localization: LocalizationManager
    let oldName: String
    let initialBucket: EmotionBucket
    let initialIcon: String
    let onSave: (String, EmotionBucket, String) -> Void
    let onCancel: () -> Void
    @State private var draft = ""
    @State private var bucket: EmotionBucket = .emotional
    @State private var selectedIcon = ""

    private var trimmed: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            CustomEmotionSheetScrollForm {
                CustomEmotionSheetCard {
                    TextField(localization.text(.recordCustomInputPlaceholder), text: $draft)
                }

                CustomEmotionSheetLabeledBlock(title: .recordCustomIconSection) {
                    CustomEmotionSheetCard {
                        CustomIconPicker(symbols: CustomIconCatalog.emotionSymbols, selection: $selectedIcon, columns: 6)
                    }
                }

                CustomEmotionSheetLabeledBlock(
                    title: .recordEmotionBucketSection,
                    footer: .recordEmotionBucketHint
                ) {
                    CustomEmotionSheetCard {
                        EmotionBucketTagPicker(selection: $bucket)
                    }
                }
            }
            .navigationTitle(localization.text(.recordCustomEditEmotionTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.text(.commonCancel)) {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.text(.commonSave)) {
                        guard !trimmed.isEmpty else { return }
                        onSave(trimmed, bucket, selectedIcon)
                    }
                    .disabled(trimmed.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            draft = oldName
            bucket = initialBucket
            selectedIcon = initialIcon
        }
    }
}

// MARK: - Custom emotion sheet (ScrollView avoids Form list-row clipping bucket tags)

private struct CustomEmotionSheetScrollForm<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                content()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

private struct CustomEmotionSheetCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct CustomEmotionSheetLabeledBlock<Content: View>: View {
    @EnvironmentObject private var localization: LocalizationManager
    let title: LKey
    var footer: LKey?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localization.text(title))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            content()

            if let footer {
                Text(localization.text(footer))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }
}

private enum EmotionGridInnerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private enum CategoryGridInnerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private extension View {
    /// Sheet-only card: solid fill, or watercolor wash (primary glow bottom-trailing for record sections).
    func recordSheetSectionCard(
        watercolor palette: DashboardWatercolorPalette? = nil,
        accentColor: Color? = nil,
        selectionTint: Color? = nil
    ) -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                GeometryReader { geo in
                    let glowScale = max(max(geo.size.width, geo.size.height) / 160, 1)
                    ZStack {
                        if let palette {
                            DashboardWatercolorBackground(
                                cornerRadius: 16,
                                palette: palette,
                                layout: .recordSheetSection,
                                glowExtentScale: glowScale
                            )
                            if let selectionTint {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        RadialGradient(
                                            colors: [selectionTint, Color.clear],
                                            center: UnitPoint(x: 0.9, y: 0.94),
                                            startRadius: 0,
                                            endRadius: 200 * glowScale
                                        )
                                    )
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppTheme.cardBackground)
                            if let accentColor {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        RadialGradient(
                                            colors: [accentColor, Color.clear],
                                            center: UnitPoint(x: 0.1, y: 0.05),
                                            startRadius: 0,
                                            endRadius: 220
                                        )
                                    )
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(AppTheme.border.opacity(0.48), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 8)
            }
    }
}

private struct EmotionOption: Identifiable, Hashable {
    let id: String
    let key: LKey?
    let customName: String?
    let colorHex: String
    let iconSymbol: String
    let rasterAssetName: String?

    var rawValue: String { id }
}

#Preview {
    NavigationStack {
        RecordSheetView()
            .environmentObject(LocalizationManager())
            .environmentObject(AppSettings())
    }
    .modelContainer(for: [TransactionRecord.self, CustomOption.self], inMemory: true)
}
