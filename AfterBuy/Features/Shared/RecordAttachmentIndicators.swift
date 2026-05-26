import SwiftUI

/// Small note / photo icons for transaction rows (bills list, home recent cards).
struct RecordAttachmentIndicators: View {
    @EnvironmentObject private var localization: LocalizationManager
    let record: TransactionRecord

    private static let iconPointSize: CGFloat = 12

    static func hasContent(_ record: TransactionRecord) -> Bool {
        hasNote(record) || hasPhoto(record)
    }

    private static func hasNote(_ record: TransactionRecord) -> Bool {
        !record.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func hasPhoto(_ record: TransactionRecord) -> Bool {
        record.hasImageAttachments
    }

    var body: some View {
        HStack(spacing: 6) {
            if Self.hasNote(record) {
                Image(systemName: "note.text")
                    .font(.system(size: Self.iconPointSize, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.78))
                    .symbolRenderingMode(.monochrome)
            }
            if Self.hasPhoto(record) {
                Image(systemName: "photo")
                    .font(.system(size: Self.iconPointSize, weight: .medium))
                    .foregroundStyle(AppTheme.actionBlue)
                    .symbolRenderingMode(.monochrome)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let note = Self.hasNote(record)
        let photo = Self.hasPhoto(record)
        switch (note, photo) {
        case (true, true):
            return localization.text(.billsRowAttachmentBothA11y)
        case (true, false):
            return localization.text(.billsRowAttachmentNoteA11y)
        case (false, true):
            return localization.text(.billsRowAttachmentPhotoA11y)
        case (false, false):
            return ""
        }
    }
}
