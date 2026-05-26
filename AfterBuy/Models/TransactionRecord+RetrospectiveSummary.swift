import Foundation

extension TransactionRecord {
    /// Preset categories resolve from `categoryKey` via `LKey` so they follow the **current** app language;
    /// custom categories and free-text names keep the stored snapshot.
    func resolvedCategoryForRetrospectiveDisplay(localizedText: (LKey) -> String) -> String {
        if let key = LKey(rawValue: categoryKey), key.rawValue.hasPrefix("category.") {
            return localizedText(key)
        }
        let trimmed = safeCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? categoryKey : trimmed
    }

    /// Short description of where the money went: category/merchant plus optional truncated note.
    func retrospectiveDestinationSummary(noteMaxLength: Int = 48, localizedText: (LKey) -> String) -> String {
        let base = resolvedCategoryForRetrospectiveDisplay(localizedText: localizedText)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNote.isEmpty else { return base }
        if trimmedNote.count <= noteMaxLength {
            return "\(base)：\(trimmedNote)"
        }
        return "\(base)：\(String(trimmedNote.prefix(noteMaxLength)))…"
    }
}
