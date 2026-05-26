import Foundation

enum LegalDocumentLoader {
    static func markdown(
        for document: AppLegalLinks.Document,
        language: AppLanguage
    ) -> String? {
        let name = AppLegalLinks.bundleResourceName(for: document, language: language)
        let url =
            Bundle.main.url(forResource: name, withExtension: "md")
            ?? Bundle.main.url(forResource: name, withExtension: "md", subdirectory: "Legal")
            ?? Bundle.main.url(forResource: name, withExtension: "md", subdirectory: "Resources/Legal")
        guard let url, let raw = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return sanitizeForInAppDisplay(raw)
    }

    /// Strips GitHub HTML chrome and in-document TOC (anchor links are not used in-app).
    private static func sanitizeForInAppDisplay(_ raw: String) -> String {
        var output: [String] = []
        var skippingHTMLParagraph = false
        var skippingTableOfContents = false

        for line in raw.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.lowercased().hasPrefix("<p ") || trimmed == "<p align=\"center\">" {
                skippingHTMLParagraph = true
                continue
            }
            if skippingHTMLParagraph {
                if trimmed.contains("</p>") {
                    skippingHTMLParagraph = false
                }
                continue
            }
            if trimmed.hasPrefix("<") && trimmed.contains(">") {
                continue
            }

            if trimmed == "## 目录" || trimmed == "## Contents" {
                skippingTableOfContents = true
                continue
            }
            if skippingTableOfContents {
                if trimmed.hasPrefix("## ") && trimmed != "## 目录" && trimmed != "## Contents" {
                    skippingTableOfContents = false
                    output.append(line)
                }
                continue
            }

            output.append(line)
        }

        return output.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
