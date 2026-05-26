import Combine
import SwiftUI

@MainActor
final class CurrencyManager: ObservableObject {
    static let storageKey = "mainCurrencyCode"

    @AppStorage(storageKey) private var storedCode: String = "" {
        didSet { refreshActiveCode(animated: false) }
    }

    @Published private(set) var activeCode: CurrencyCode

    private var formatterCache: [String: NumberFormatter] = [:]

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
        activeCode = Self.resolve(stored: stored)
        AppFormatter.currencyManager = self
    }

    var isManuallyLocked: Bool {
        !storedCode.isEmpty
    }

    var code: CurrencyCode { activeCode }

    var activeCurrencySymbol: String { activeCode.symbol }

    var activeCurrencyCode: String { activeCode.rawValue }

    func settingsSubtitle(language: AppLanguage, followSystemLabel: String) -> String {
        let effective = language.resolved
        let name = activeCode.displayName(locale: effective.locale)
        if isManuallyLocked { return name }
        switch language {
        case .system:
            return "\(followSystemLabel) · \(name)"
        case .en:
            // English compact subtitle is deferred; show follow-system label only.
            return followSystemLabel
        case .zhHans, .zhHant:
            return "\(followSystemLabel) · \(name)"
        }
    }

    func lock(to code: CurrencyCode) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            storedCode = code.rawValue
            apply(code)
        }
    }

    func followSystem() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            storedCode = ""
            apply(CurrencyCode.systemDefaultCode())
        }
    }

    func refreshIfFollowingSystem() {
        guard !isManuallyLocked else { return }
        let next = CurrencyCode.systemDefaultCode()
        guard next != activeCode else { return }
        apply(next)
    }

    func moneyFormatter(locale: Locale) -> NumberFormatter {
        let key = "\(activeCode.rawValue)|\(locale.identifier)"
        if let cached = formatterCache[key] { return cached }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = activeCode.rawValue
        formatter.locale = locale
        let fractionDigits = fractionDigits(for: activeCode)
        formatter.maximumFractionDigits = fractionDigits
        formatter.minimumFractionDigits = fractionDigits
        formatterCache[key] = formatter
        return formatter
    }

    private func refreshActiveCode(animated: Bool) {
        let next = Self.resolve(stored: storedCode)
        guard next != activeCode else { return }
        if animated {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                apply(next)
            }
        } else {
            apply(next)
        }
    }

    private func apply(_ code: CurrencyCode) {
        activeCode = code
        formatterCache.removeAll()
        objectWillChange.send()
    }

    private static func resolve(stored: String) -> CurrencyCode {
        if !stored.isEmpty, let locked = CurrencyCode.supported(stored) {
            return locked
        }
        return CurrencyCode.systemDefaultCode()
    }

    private func fractionDigits(for code: CurrencyCode) -> Int {
        switch code {
        case .JPY: return 0
        default: return 2
        }
    }
}
