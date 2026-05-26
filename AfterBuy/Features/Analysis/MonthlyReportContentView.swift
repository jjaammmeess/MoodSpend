import SwiftUI

// MARK: - Model

struct MonthlyReportContentModel {
    struct EmotionHighlight: Identifiable {
        let id: String
        let title: String
        let emotionRaw: String
        let color: Color
        let colorHex: String
        let ratioText: String
    }

    let productName: String
    let reportTitle: String
    let reportSubtitle: String
    let generatedAtText: String
    let periodRangeLabel: String
    let expenseLabel: String
    let totalExpenseText: String
    let totalCountText: String
    let topEmotionText: String
    let effectiveRatioText: String
    let emotionPaletteTitle: String
    let emotionPaletteFootnote: String?
    let rulesTitle: String
    let patternLines: [String]
    let warmTipTitle: String
    let warmTipBody: String
    let footerTagline: String
    let appStoreLabel: String
    let noDataText: String
    let emotionHighlights: [EmotionHighlight]
}

enum MonthlyReportPresentation {
    /// In-app scroll: navigation bar shows period title; no duplicate headline.
    case interactive
    /// Fixed-width snapshot for share export.
    case exportSnapshot
}

// MARK: - Content

struct MonthlyReportContentView: View {
    let model: MonthlyReportContentModel
    let presentation: MonthlyReportPresentation

    private var isExportSnapshot: Bool {
        presentation == .exportSnapshot
    }

    private var canvasWidth: CGFloat? {
        isExportSnapshot ? 390 : nil
    }

    private var topInset: CGFloat {
        isExportSnapshot ? 64 : 16
    }

    private var bottomInset: CGFloat {
        isExportSnapshot ? 14 : 20
    }

    var body: some View {
        VStack(spacing: 0) {
            if isExportSnapshot {
                Text(model.reportTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(ReportShareTheme.title)
                    .multilineTextAlignment(.center)
                    .padding(.top, topInset)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 8)
            }

            Text(model.reportSubtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ReportShareTheme.subtitle)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, isExportSnapshot ? 0 : topInset)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)

            summaryGlassCard
                .padding(.horizontal, sectionHorizontalPadding)
                .padding(.bottom, 16)

            emotionSection
                .padding(.horizontal, sectionHorizontalPadding)
                .padding(.bottom, 14)

            rulesSection
                .padding(.horizontal, rulesHorizontalPadding)
                .padding(.bottom, 12)

            warmTipSection
                .padding(.horizontal, rulesHorizontalPadding)
                .padding(.bottom, 16)

            footerSection
                .padding(.horizontal, footerHorizontalPadding)
                .padding(.bottom, bottomInset)
        }
        .frame(width: canvasWidth, alignment: .top)
        .frame(maxWidth: isExportSnapshot ? nil : .infinity, alignment: .top)
        .background {
            ZStack {
                ReportShareTheme.canvasGradient
                ReportShareTheme.ambientGlow
                    .allowsHitTesting(false)
            }
        }
    }

    private var sectionHorizontalPadding: CGFloat {
        isExportSnapshot ? 22 : 16
    }

    private var rulesHorizontalPadding: CGFloat {
        isExportSnapshot ? 26 : 20
    }

    private var footerHorizontalPadding: CGFloat {
        isExportSnapshot ? 24 : 16
    }

    // MARK: - Summary card

    private var summaryMetadataRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(model.generatedAtText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(model.periodRangeLabel)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(ReportShareTheme.muted)
        .monospacedDigit()
    }

    private var summaryGlassCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryMetadataRow

            HStack(spacing: 8) {
                Image(systemName: "yensign.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ReportShareTheme.accent)
                Text(model.expenseLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ReportShareTheme.subtitle)
            }

            Text(model.totalExpenseText)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(ReportShareTheme.title)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .overlay(ReportShareTheme.divider)

            metricRow(icon: "list.number", label: model.totalCountText)
            metricRow(icon: "trophy.fill", label: model.topEmotionText)
            metricRow(icon: "sparkles", label: model.effectiveRatioText)
        }
        .padding(20)
        .background { ReportShareGlassBackground(cornerRadius: 22) }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ReportShareTheme.glassStroke, lineWidth: 1)
        }
    }

    private func metricRow(icon: String, label: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ReportShareTheme.accent.opacity(0.9))
                .frame(width: 18, height: 18)

            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ReportShareTheme.body)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Emotion pills

    private var emotionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.emotionPaletteTitle)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(ReportShareTheme.title)

            if model.emotionHighlights.isEmpty {
                Text(model.noDataText)
                    .font(.system(size: 13))
                    .foregroundStyle(ReportShareTheme.muted)
            } else {
                VStack(spacing: 8) {
                    ForEach(model.emotionHighlights) { item in
                        ReportShareEmotionGlowPill(
                            title: item.title,
                            ratioText: item.ratioText,
                            gradient: ReportShareEmotionGradients.gradient(for: item.emotionRaw, fallback: item.color)
                        )
                    }
                }

                if let footnote = model.emotionPaletteFootnote {
                    Text(footnote)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ReportShareTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Rules & warm tip

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.rulesTitle)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(ReportShareTheme.title)

            if model.patternLines.isEmpty {
                Text(model.noDataText)
                    .font(.system(size: 14))
                    .foregroundStyle(ReportShareTheme.muted)
                    .lineSpacing(6)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(model.patternLines.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(ReportShareTheme.accent.opacity(0.55))
                                .frame(width: 5, height: 5)
                                .padding(.top, 6)
                            Text(line)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(ReportShareTheme.body)
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.leading, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var warmTipSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.warmTipTitle)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(ReportShareTheme.title)

            Text(model.warmTipBody)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(ReportShareTheme.body)
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(spacing: 8) {
                ReportShareAppIconBadge(size: 56, glowRadius: 20)

                Text(model.productName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ReportShareTheme.title)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 8) {
                storeBadge(systemImage: "apple.logo", title: model.appStoreLabel)

                Text(model.footerTagline)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ReportShareTheme.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 8)
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(ReportShareTheme.glassStroke.opacity(0.7), lineWidth: 1)
                }
        }
    }

    private func storeBadge(systemImage: String, title: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(ReportShareTheme.body)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
    }
}

// MARK: - Theme

enum ReportShareTheme {
    static let title = Color(hex: "F2F6F8")
    static let subtitle = Color(hex: "B8C5CC")
    static let body = Color(hex: "D2DCE2")
    static let muted = Color(hex: "7A8A94")
    static let accent = Color(hex: "69B7CE")
    static let divider = Color.white.opacity(0.12)
    static let glassStroke = Color.white.opacity(0.18)
    static let navigationBarBackground = Color(hex: "06090D")

    static var canvasGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "06090D"),
                Color(hex: "0E1419"),
                Color(hex: "121A22"),
                Color(hex: "0A0E14"),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var ambientGlow: some View {
        ZStack {
            RadialGradient(
                colors: [Color(hex: "62496F").opacity(0.35), .clear],
                center: UnitPoint(x: 0.15, y: 0.22),
                startRadius: 0,
                endRadius: 220
            )
            RadialGradient(
                colors: [Color(hex: "3F6F76").opacity(0.28), .clear],
                center: UnitPoint(x: 0.85, y: 0.35),
                startRadius: 0,
                endRadius: 200
            )
            RadialGradient(
                colors: [Color(hex: "69B7CE").opacity(0.12), .clear],
                center: UnitPoint(x: 0.5, y: 1.0),
                startRadius: 0,
                endRadius: 280
            )
        }
    }
}

// MARK: - Components

struct ReportShareGlassBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(hex: "1A2229").opacity(0.72))

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.14),
                            Color.white.opacity(0.04),
                            Color.clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "69B7CE").opacity(0.12),
                            Color.clear,
                        ],
                        center: UnitPoint(x: 0.2, y: 0),
                        startRadius: 0,
                        endRadius: 180
                    )
                )
        }
    }
}

struct ReportShareAppIconBadge: View {
    let size: CGFloat
    let glowRadius: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "69B7CE").opacity(0.55),
                            Color(hex: "62496F").opacity(0.25),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: size * 0.2,
                        endRadius: glowRadius
                    )
                )
                .frame(width: glowRadius * 2.2, height: glowRadius * 2.2)
                .blur(radius: 8)

            Image("AboutAppIcon")
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.55),
                                    Color.white.opacity(0.12),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                }
                .shadow(color: Color(hex: "69B7CE").opacity(0.45), radius: 14, x: 0, y: 6)
        }
    }
}

struct ReportShareEmotionGlowPill: View {
    let title: String
    let ratioText: String
    let gradient: LinearGradient

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 12)
            Text(ratioText)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            ZStack {
                Capsule(style: .continuous)
                    .fill(gradient)
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.22),
                                Color.clear,
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
        }
        .clipShape(Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.45),
                            Color.white.opacity(0.08),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Color(hex: "69B7CE").opacity(0.25), radius: 12, x: 0, y: 6)
        .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)
    }
}

enum ReportShareEmotionGradients {
    static func gradient(for emotionRaw: String, fallback: Color) -> LinearGradient {
        if let tag = EmotionTag.from(raw: emotionRaw) {
            return presetGradient(for: tag)
        }
        let lead = fallback
        let trail = fallback.opacity(0.65)
        return LinearGradient(
            colors: [lead, trail],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private static func presetGradient(for tag: EmotionTag) -> LinearGradient {
        switch tag {
        case .stress:
            return LinearGradient(
                colors: [Color(hex: "4A3D6B"), Color(hex: "3F6F76"), Color(hex: "69B7CE")],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .necessity:
            return LinearGradient(
                colors: [Color(hex: "E8B84A"), Color(hex: "C67A42"), Color(hex: "3F6F76")],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .ritual:
            return LinearGradient(
                colors: [Color(hex: "8C76A1"), Color(hex: "6A8FB8"), Color(hex: "5F90B2")],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .impulse:
            return LinearGradient(
                colors: [Color(hex: "C65840"), Color(hex: "8C4E5A"), Color(hex: "62496F")],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .pamper:
            return LinearGradient(
                colors: [Color(hex: "69B7CE"), Color(hex: "5F90B2"), Color(hex: "8C76A1")],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .social:
            return LinearGradient(
                colors: [Color(hex: "F4CE4B"), Color(hex: "E8A84A"), Color(hex: "C65840")],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

#if DEBUG
#Preview("Export") {
    MonthlyReportContentView(
        model: .preview,
        presentation: .exportSnapshot
    )
}

#Preview("Interactive") {
    ScrollView {
        MonthlyReportContentView(
            model: .preview,
            presentation: .interactive
        )
    }
    .preferredColorScheme(.dark)
}

private extension MonthlyReportContentModel {
    static var preview: MonthlyReportContentModel {
        MonthlyReportContentModel(
            productName: "花钱了",
            reportTitle: "本月情绪消费报告",
            reportSubtitle: "记的不仅是花销，更是花钱时的心情",
            generatedAtText: "生成时间：2026/05/21",
            periodRangeLabel: "2026年5月",
            expenseLabel: "本月总支出",
            totalExpenseText: "¥2,772.00",
            totalCountText: "本期消费笔数：29",
            topEmotionText: "本期 TOP 情绪：解压发泄",
            effectiveRatioText: "有效快乐消费占比：21%（占非刚需内）",
            emotionPaletteTitle: "本期心情花费 Top 3（占总额）",
            emotionPaletteFootnote: "其余心情合计约 19%（仅展示金额最高的 3 项）",
            rulesTitle: "本期规律摘要",
            patternLines: [
                "你本期在「餐饮美食」类目消费最多（13 笔）。",
                "你在晚上消费更集中（10 笔）。",
            ],
            warmTipTitle: "温柔提醒",
            warmTipBody: "在除刚需外的消费里，无效情绪消费约占 78%（有效快乐约 21%）。本期刚需必要约占总额的 26%。建议下次下单前先停 30 秒，问问自己是否真的需要。",
            footerTagline: "你的情绪消费觉察伙伴",
            appStoreLabel: "App Store",
            noDataText: "暂无数据",
            emotionHighlights: [
                .init(id: "stress", title: "解压发泄", emotionRaw: "stress", color: .purple, colorHex: "62496F", ratioText: "47%"),
                .init(id: "necessity", title: "刚需必要", emotionRaw: "necessity", color: .teal, colorHex: "3F6F76", ratioText: "26%"),
                .init(id: "ritual", title: "仪式感", emotionRaw: "ritual", color: .blue, colorHex: "5F90B2", ratioText: "8%"),
            ]
        )
    }
}
#endif
