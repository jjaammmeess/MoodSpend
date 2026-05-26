import SwiftUI
import UIKit

// MARK: - Expression evaluation (+ − × ÷, precedence, unary ±)

private enum ExprParseError: Error {
    case invalid
    case divisionByZero
    case trailingJunk
}

private struct ExpressionEvaluator {
    private let chars: [Character]
    private var i: Int = 0

    init(_ s: String) {
        chars = Array(s)
    }

    private var atEnd: Bool { i >= chars.count }

    private func peek() -> Character? {
        guard !atEnd else { return nil }
        return chars[i]
    }

    mutating func evaluate() throws -> Double {
        let v = try parseExpression()
        guard atEnd else { throw ExprParseError.trailingJunk }
        return v
    }

    private mutating func parseExpression() throws -> Double {
        var v = try parseTerm()
        while let c = peek() {
            if c == "+" {
                i += 1
                v += try parseTerm()
            } else if c == "-" {
                i += 1
                v -= try parseTerm()
            } else {
                break
            }
        }
        return v
    }

    private mutating func parseTerm() throws -> Double {
        var v = try parseFactor()
        while let c = peek() {
            if c == "*" {
                i += 1
                v *= try parseFactor()
            } else if c == "/" {
                i += 1
                let d = try parseFactor()
                guard d != 0 else { throw ExprParseError.divisionByZero }
                v /= d
            } else {
                break
            }
        }
        return v
    }

    private mutating func parseFactor() throws -> Double {
        if peek() == "+" {
            i += 1
            return try parseFactor()
        }
        if peek() == "-" {
            i += 1
            return -(try parseFactor())
        }
        return try parseNumber()
    }

    private mutating func parseNumber() throws -> Double {
        guard let c = peek(), (c.isNumber || c == ".") else { throw ExprParseError.invalid }
        let start = i
        var sawDot = false
        while let ch = peek() {
            if ch.isNumber {
                i += 1
            } else if ch == "." {
                guard !sawDot else { break }
                sawDot = true
                i += 1
            } else {
                break
            }
        }
        let slice = String(chars[start..<i])
        guard slice != ".", let v = Double(slice) else { throw ExprParseError.invalid }
        return v
    }
}

private enum AmountExpr {
    static func previewValue(for raw: String) -> Double? {
        var work = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !work.isEmpty else { return nil }
        while let last = work.last, "+-*/".contains(last) {
            work.removeLast()
        }
        guard !work.isEmpty else { return nil }
        var ev = ExpressionEvaluator(work)
        guard let v = try? ev.evaluate(), v.isFinite else { return nil }
        return v
    }

    static func confirmedValue(for raw: String) -> Double? {
        let work = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !work.isEmpty else { return nil }
        var ev = ExpressionEvaluator(work)
        guard let v = try? ev.evaluate(), v.isFinite else { return nil }
        return v
    }
}

// MARK: - Token buffer

private enum CalcToken: Equatable {
    case num(String)
    case op(Character)

    private static let opSet: Set<Character> = ["+", "-", "*", "/"]

    static func isBinaryOp(_ c: Character) -> Bool {
        opSet.contains(c)
    }
}

private struct CalculatorBuffer {
    private(set) var tokens: [CalcToken] = []

    var rawExpression: String {
        tokens.map { t in
            switch t {
            case .num(let s): return s
            case .op(let c): return String(c)
            }
        }.joined()
    }

    var displayExpression: String {
        rawExpression
            .replacingOccurrences(of: "*", with: "×")
            .replacingOccurrences(of: "/", with: "÷")
    }

    /// Spaced flow for the header / history line (e.g. `22 + 23`).
    var flowDisplayExpression: String {
        tokens.map { token in
            switch token {
            case .num(let s): return s
            case .op(let c):
                let sym: String = switch c {
                case "+": "+"
                case "-": "−"
                case "*": "×"
                case "/": "÷"
                default: String(c)
                }
                return sym
            }
        }
        .joined(separator: " ")
    }

    mutating func appendDigit(_ d: Character) {
        guard d.isNumber else { return }
        guard let last = tokens.last else {
            tokens.append(.num(String(d)))
            return
        }
        switch last {
        case .op:
            tokens.append(.num(String(d)))
        case .num(var s):
            if s == "0", d != "." {
                s = String(d)
                tokens[tokens.count - 1] = .num(s)
                return
            }
            if s == "-", d == "." {
                s = "-0."
                tokens[tokens.count - 1] = .num(s)
                return
            }
            guard canAppendDigit(to: s) else { return }
            s.append(d)
            tokens[tokens.count - 1] = .num(s)
        }
    }

    mutating func appendDot() {
        guard let last = tokens.last else {
            tokens.append(.num("0."))
            return
        }
        switch last {
        case .op:
            tokens.append(.num("0."))
        case .num(var s):
            guard !s.contains(".") else { return }
            if s.isEmpty || s == "-" {
                s = s == "-" ? "-0." : "0."
            } else if s.last?.isNumber == true {
                s.append(".")
            } else {
                return
            }
            tokens[tokens.count - 1] = .num(s)
        }
    }

    mutating func appendBinaryOperator(_ op: Character) {
        guard CalcToken.isBinaryOp(op) else { return }
        if tokens.isEmpty {
            if op == "-" { tokens.append(.num("-")) }
            return
        }
        switch tokens[tokens.count - 1] {
        case .op:
            tokens[tokens.count - 1] = .op(op)
        case .num(let s):
            guard isCompleteNumber(s) else { return }
            var fixed = s
            if fixed.hasSuffix(".") {
                fixed.removeLast()
            }
            tokens[tokens.count - 1] = .num(fixed)
            tokens.append(.op(op))
        }
    }

    mutating func backspace() {
        guard let last = tokens.last else { return }
        switch last {
        case .op:
            tokens.removeLast()
        case .num(let s):
            if s.count <= 1 {
                tokens.removeLast()
            } else {
                tokens[tokens.count - 1] = .num(String(s.dropLast()))
            }
        }
    }

    mutating func clear() {
        tokens.removeAll()
    }

    mutating func negateLastNumber() {
        guard case .num(let s) = tokens.last, isCompleteNumber(s), let v = Double(s) else { return }
        tokens[tokens.count - 1] = .num(Self.formatNumberToken(-v))
    }

    mutating func percentLastNumber() {
        guard case .num(let s) = tokens.last, isCompleteNumber(s), let v = Double(s) else { return }
        tokens[tokens.count - 1] = .num(Self.formatNumberToken(v / 100))
    }

    mutating func loadFromAmountText(_ text: String) {
        tokens.removeAll()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let _ = Double(trimmed) else { return }
        tokens.append(.num(trimmed))
    }

    private func canAppendDigit(to s: String) -> Bool {
        guard let dot = s.firstIndex(of: ".") else { return true }
        let fracLen = s[s.index(after: dot)...].count
        return fracLen < 2 || s.last == "."
    }

    private func isCompleteNumber(_ s: String) -> Bool {
        guard !s.isEmpty, s != "-", s != "-." else { return false }
        if s.hasSuffix(".") { return false }
        return Double(s) != nil
    }

    private static func formatNumberToken(_ v: Double) -> String {
        let x = (v * 10_000).rounded() / 10_000
        if abs(x) < 1e-12 { return "0" }
        if x.truncatingRemainder(dividingBy: 1) == 0, abs(x) <= Double(Int.max) {
            return String(Int(x))
        }
        var s = String(format: "%.4f", x)
        while s.last == "0" { s.removeLast() }
        if s.last == "." { s.removeLast() }
        return s
    }
}

// MARK: - Premium calculator sheet

struct AmountCalculatorSheet: View {
    @EnvironmentObject private var localization: LocalizationManager

    let accentColor: Color
    let initialAmountText: String
    let onConfirm: (String) -> Void
    let onDismiss: () -> Void
    let onLiveAmountDisplayChange: ((String) -> Void)?

    @State private var buffer = CalculatorBuffer()

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    private let gridRowSpacing: CGFloat = 8
    private let keyHeight: CGFloat = 46
    private let keypadBottomBreathing: CGFloat = 12

    private var operatorTint: Color { Color(hex: "8A959C") }

    init(
        accentColor: Color,
        initialAmountText: String,
        onConfirm: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void,
        onLiveAmountDisplayChange: ((String) -> Void)? = nil
    ) {
        self.accentColor = accentColor
        self.initialAmountText = initialAmountText
        self.onConfirm = onConfirm
        self.onDismiss = onDismiss
        self.onLiveAmountDisplayChange = onLiveAmountDisplayChange
    }

    var body: some View {
        VStack(spacing: 12) {
            compactDisplaySection

            premiumKeypad
                .padding(.horizontal, 20)
                .padding(.bottom, keypadBottomBreathing)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel(localization.text(.recordAmountCalculatorHint))
        .accessibilityAction(.escape, onDismiss)
        .onAppear {
            buffer.loadFromAmountText(initialAmountText)
            emitLiveAmountDisplay()
        }
    }

    // MARK: - Compact readout (title/cancel removed — dismiss via dim tap or confirm)

    private var compactDisplaySection: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if !buffer.flowDisplayExpression.isEmpty {
                Text(buffer.flowDisplayExpression)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.opacity)
            }

            Text(mainDisplayText)
                .font(amountReadoutFont)
                .monospacedDigit()
                .foregroundStyle(amountReadoutForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.35)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .animation(.easeOut(duration: 0.18), value: buffer.rawExpression)
    }

    private var isShowingAmountPlaceholder: Bool {
        AmountExpr.previewValue(for: buffer.rawExpression) == nil && buffer.rawExpression.isEmpty
    }

    private var amountReadoutFont: Font {
        if isShowingAmountPlaceholder {
            return .system(size: 16, weight: .regular, design: .rounded)
        }
        return .system(size: 40, weight: .semibold, design: .rounded)
    }

    private var amountReadoutForeground: Color {
        isShowingAmountPlaceholder ? .secondary.opacity(0.6) : .primary
    }

    private var mainDisplayText: String {
        if let v = AmountExpr.previewValue(for: buffer.rawExpression) {
            return formatPreview(v)
        }
        if buffer.rawExpression.isEmpty {
            return localization.text(.recordAmountPlaceholder)
        }
        return "—"
    }

    // MARK: - Keypad

    private var premiumKeypad: some View {
        LazyVGrid(columns: gridColumns, spacing: gridRowSpacing) {
            PremiumCalculatorKeyButton(icon: "delete.left", role: .utility) {
                deletePressed()
            }
            PremiumCalculatorKeyButton(text: "±", role: .utility) {
                buffer.negateLastNumber()
                emitLiveAmountDisplay()
            }
            PremiumCalculatorKeyButton(text: "%", role: .utility) {
                buffer.percentLastNumber()
                emitLiveAmountDisplay()
            }
            PremiumCalculatorKeyButton(text: "÷", role: .operator) {
                operatorPressed("/")
            }

            ForEach(["7", "8", "9"], id: \.self) { digit in
                PremiumCalculatorKeyButton(text: digit, role: .digit) {
                    numberPressed(digit)
                }
            }
            PremiumCalculatorKeyButton(text: "×", role: .operator) {
                operatorPressed("*")
            }

            ForEach(["4", "5", "6"], id: \.self) { digit in
                PremiumCalculatorKeyButton(text: digit, role: .digit) {
                    numberPressed(digit)
                }
            }
            PremiumCalculatorKeyButton(text: "−", role: .operator) {
                operatorPressed("-")
            }

            ForEach(["1", "2", "3"], id: \.self) { digit in
                PremiumCalculatorKeyButton(text: digit, role: .digit) {
                    numberPressed(digit)
                }
            }
            PremiumCalculatorKeyButton(text: "+", role: .operator) {
                operatorPressed("+")
            }

            PremiumCalculatorKeyButton(text: AppFormatter.activeCurrencyCode, role: .subdued) {
                clearAll()
            }
            PremiumCalculatorKeyButton(text: "0", role: .digit) {
                numberPressed("0")
            }
            PremiumCalculatorKeyButton(text: ".", role: .digit) {
                buffer.appendDot()
                emitLiveAmountDisplay()
            }

            confirmCapsuleButton
        }
    }

    private var confirmCapsuleButton: some View {
        Button {
            submitAmount()
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: keyHeight)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.85), accentColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
        }
        .buttonStyle(PremiumKeyPressStyle())
    }

    // MARK: - Input actions

    private func numberPressed(_ num: String) {
        guard let ch = num.first, ch.isNumber else { return }
        buffer.appendDigit(ch)
        emitLiveAmountDisplay()
    }

    private func operatorPressed(_ op: String) {
        guard let ch = op.first else { return }
        buffer.appendBinaryOperator(ch)
        emitLiveAmountDisplay()
    }

    private func deletePressed() {
        buffer.backspace()
        emitLiveAmountDisplay()
    }

    private func clearAll() {
        buffer.clear()
        emitLiveAmountDisplay()
    }

    private func submitAmount() {
        guard let v = AmountExpr.confirmedValue(for: buffer.rawExpression), v > 0, v <= 99_999_999.99 else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        onConfirm(String(format: "%.2f", v))
        onDismiss()
    }

    private var amountFieldLiveString: String {
        if let v = AmountExpr.previewValue(for: buffer.rawExpression) {
            return formatPreview(v)
        }
        let expr = buffer.displayExpression.trimmingCharacters(in: .whitespacesAndNewlines)
        return expr
    }

    private func emitLiveAmountDisplay() {
        onLiveAmountDisplayChange?(amountFieldLiveString)
    }

    private func formatPreview(_ v: Double) -> String {
        if abs(v - v.rounded()) < 1e-9, abs(v) <= Double(Int.max) {
            return String(Int(v.rounded()))
        }
        return String(format: "%.2f", v)
    }
}

// MARK: - Borderless keys

private enum PremiumKeyRole {
    case digit
    case `operator`
    case utility
    case subdued
}

private struct PremiumCalculatorKeyButton: View {
    var text: String?
    var icon: String?
    var role: PremiumKeyRole = .digit
    var action: () -> Void

    private var operatorTint: Color { Color(hex: "8A959C") }

    var body: some View {
        Button(action: action) {
            Group {
                if let text {
                    Text(text)
                        .font(fontForRole)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                }
            }
            .foregroundStyle(foregroundForRole)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(PremiumKeyPressStyle())
    }

    private var fontForRole: Font {
        switch role {
        case .digit:
            return .system(size: 26, weight: .medium, design: .rounded)
        case .operator:
            return .system(size: 22, weight: .medium, design: .rounded)
        case .utility, .subdued:
            return .system(size: 20, weight: .medium, design: .rounded)
        }
    }

    private var foregroundForRole: Color {
        switch role {
        case .digit:
            return .primary
        case .operator:
            return operatorTint
        case .utility:
            return .primary
        case .subdued:
            return .secondary.opacity(0.6)
        }
    }
}

private struct PremiumKeyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.45 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    AmountCalculatorSheet(
        accentColor: AppTheme.actionBlue,
        initialAmountText: "12.50",
        onConfirm: { _ in },
        onDismiss: {}
    )
    .environmentObject(LocalizationManager())
}
