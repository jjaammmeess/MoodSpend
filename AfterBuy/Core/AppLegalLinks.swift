import Foundation

/// Legal document identifiers for in-app markdown (bundle resources).
enum AppLegalLinks {
    enum Document {
        case privacyPolicy
        case termsOfUse
        case technicalSupport
    }

    /// Legal markdown: Simplified Chinese only when UI language resolves to `zh-Hans`; all other languages use English.
    private static func usesSimplifiedChineseLegalDocuments(for language: AppLanguage) -> Bool {
        language.resolved == .zhHans
    }

    /// Bundle resource base name (copied to app bundle root by Xcode).
    static func bundleResourceName(for document: Document, language: AppLanguage) -> String {
        let useSimplifiedChinese = usesSimplifiedChineseLegalDocuments(for: language)
        switch document {
        case .privacyPolicy:
            return useSimplifiedChinese ? "privacy-policy.zh-Hans" : "privacy-policy"
        case .termsOfUse:
            return useSimplifiedChinese ? "terms-of-use.zh-Hans" : "terms-of-use"
        case .technicalSupport:
            return useSimplifiedChinese ? "technical-support.zh-Hans" : "technical-support"
        }
    }
}
