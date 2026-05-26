import SwiftUI

struct LegalDocumentView: View {
    let document: AppLegalLinks.Document

    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.openURL) private var openURL

    private var markdown: String {
        LegalDocumentLoader.markdown(for: document, language: localization.effectiveLanguage) ?? ""
    }

    var body: some View {
        Group {
            if markdown.isEmpty {
                ContentUnavailableView(
                    localization.text(.legalDocumentUnavailableTitle),
                    systemImage: "doc.text",
                    description: Text(localization.text(.legalDocumentUnavailableMessage))
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        heroSection
                        LegalMarkdownContentView(text: markdown, onOpenURL: openURL)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.pageBackground, for: .navigationBar)
    }

    private var navigationTitle: String {
        switch document {
        case .privacyPolicy:
            return localization.text(.aboutAppPrivacy)
        case .termsOfUse:
            return localization.text(.aboutAppTerms)
        case .technicalSupport:
            return localization.text(.legalDocumentSupportTitle)
        }
    }

    private var heroSection: some View {
        VStack(spacing: 8) {
            Text(AppBranding.productName(for: localization.effectiveLanguage))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(heroSubtitle)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.mineCardCornerRadius, style: .continuous)
                .fill(AppTheme.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.mineCardCornerRadius, style: .continuous)
                        .stroke(AppTheme.border.opacity(0.35), lineWidth: 0.5)
                }
        }
        .padding(.top, 8)
    }

    private var heroSubtitle: String {
        switch document {
        case .privacyPolicy:
            return localization.text(.legalDocumentPrivacySubtitle)
        case .termsOfUse:
            return localization.text(.legalDocumentTermsSubtitle)
        case .technicalSupport:
            return localization.text(.legalDocumentSupportSubtitle)
        }
    }
}

// MARK: - Markdown rendering

private struct LegalMarkdownContentView: View {
    let text: String
    let onOpenURL: OpenURLAction

    var body: some View {
        let blocks = LegalMarkdownParser.blocks(from: text)
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(_ block: LegalMarkdownBlock) -> some View {
        switch block {
        case .divider:
            Rectangle()
                .fill(AppTheme.divider)
                .frame(height: 0.5)
                .padding(.vertical, 4)

        case .heading(let level, let content):
            Text(content)
                .font(level == 1 ? .title2.bold() : .title3.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.top, level == 1 ? 4 : 0)

        case .quote(let content):
            Text(attributedInline(content))
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.actionBlue.opacity(0.08))
                }

        case .paragraph(let content):
            Text(attributedInline(content))
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary)
                .lineSpacing(5)
                .environment(\.openURL, onOpenURL)

        case .list(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundStyle(AppTheme.actionBlue)
                        Text(attributedInline(item))
                            .font(.body)
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineSpacing(4)
                            .environment(\.openURL, onOpenURL)
                    }
                }
            }

        case .table(let rows):
            LegalMarkdownTableView(rows: rows)
        }
    }

    private func attributedInline(_ content: String) -> AttributedString {
        (try? AttributedString(markdown: content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ??
            AttributedString(content)
    }
}

private struct LegalMarkdownTableView: View {
    let rows: [[String]]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index == 1, row.allSatisfy({ $0.contains("---") }) {
                    MineSettingsDivider()
                } else if !row.allSatisfy({ $0.contains("---") }) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(cell)
                                .font(index == 0 ? .caption.weight(.semibold) : .subheadline)
                                .foregroundStyle(index == 0 ? AppTheme.textSecondary : AppTheme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    if index == 0 {
                        MineSettingsDivider()
                    }
                }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: AppTheme.mineCardCornerRadius, style: .continuous)
                .fill(AppTheme.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.mineCardCornerRadius, style: .continuous)
                        .stroke(AppTheme.border.opacity(0.35), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Parser

private enum LegalMarkdownBlock {
    case heading(level: Int, String)
    case paragraph(String)
    case quote(String)
    case list([String])
    case table([[String]])
    case divider
}

private enum LegalMarkdownParser {
    static func blocks(from text: String) -> [LegalMarkdownBlock] {
        var blocks: [LegalMarkdownBlock] = []
        var paragraphLines: [String] = []
        var listItems: [String] = []
        var tableRows: [[String]] = []
        var inTable = false

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            let merged = paragraphLines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if !merged.isEmpty {
                blocks.append(.paragraph(merged))
            }
            paragraphLines = []
        }

        func flushList() {
            guard !listItems.isEmpty else { return }
            blocks.append(.list(listItems))
            listItems = []
        }

        func flushTable() {
            guard !tableRows.isEmpty else { return }
            blocks.append(.table(tableRows))
            tableRows = []
            inTable = false
        }

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flushParagraph()
                flushList()
                flushTable()
                continue
            }

            if trimmed == "---" {
                flushParagraph()
                flushList()
                flushTable()
                blocks.append(.divider)
                continue
            }

            if trimmed.hasPrefix("### ") {
                flushParagraph(); flushList(); flushTable()
                blocks.append(.heading(level: 3, String(trimmed.dropFirst(4))))
                continue
            }
            if trimmed.hasPrefix("## ") {
                flushParagraph(); flushList(); flushTable()
                blocks.append(.heading(level: 2, String(trimmed.dropFirst(3))))
                continue
            }
            if trimmed.hasPrefix("# ") {
                flushParagraph(); flushList(); flushTable()
                blocks.append(.heading(level: 1, String(trimmed.dropFirst(2))))
                continue
            }

            if trimmed.hasPrefix("> ") {
                flushParagraph(); flushList(); flushTable()
                blocks.append(.quote(String(trimmed.dropFirst(2))))
                continue
            }

            if trimmed.hasPrefix("|") {
                flushParagraph()
                flushList()
                inTable = true
                let cells = trimmed
                    .split(separator: "|", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                tableRows.append(cells)
                continue
            }

            if inTable {
                flushTable()
            }

            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                flushParagraph()
                listItems.append(String(trimmed.dropFirst(2)))
                continue
            }

            if let numbered = numberedListItem(from: trimmed) {
                flushParagraph()
                listItems.append(numbered)
                continue
            }

            flushList()
            paragraphLines.append(trimmed)
        }

        flushParagraph()
        flushList()
        flushTable()
        return blocks
    }

    private static func numberedListItem(from line: String) -> String? {
        guard let dotIndex = line.firstIndex(of: ".") else { return nil }
        let prefix = line[..<dotIndex].trimmingCharacters(in: .whitespaces)
        guard let number = Int(prefix), number > 0 else { return nil }
        var index = line.index(after: dotIndex)
        guard index < line.endIndex, line[index] == " " else { return nil }
        index = line.index(after: index)
        let content = line[index...].trimmingCharacters(in: .whitespaces)
        return content.isEmpty ? nil : content
    }
}

#Preview("Privacy") {
    NavigationStack {
        LegalDocumentView(document: .privacyPolicy)
            .environmentObject(LocalizationManager())
    }
}
