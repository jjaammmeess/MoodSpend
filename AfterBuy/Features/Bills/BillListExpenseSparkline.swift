import SwiftUI

/// Sparkline with a hard 32pt layout slot; stroke uses `Shape.trim` for left-to-right draw replay.
struct BillListExpenseSparkline: View {
    static let layoutHeight: CGFloat = 32
    /// Line draw duration when filters change (left-to-right trim).
    static let strokeDrawDuration: TimeInterval = 0.6
    static let fillFadeDuration: TimeInterval = 0.25

    let points: [BillListSparklineMetrics.Point]
    /// Parent bumps this with new points so the drawable layer remounts (same as tab switch).
    let replayToken: String
    var accessibilityLabelText: String = ""

    var body: some View {
        SparklineDrawableLayer(points: points)
            .id(replayToken)
            .frame(maxWidth: .infinity)
            .frame(height: Self.layoutHeight)
            .clipped()
            .background(AppTheme.pageBackground)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(accessibilityLabelText))
    }
}

/// Holds draw state; remounted via `.id(replayToken)` so filter changes match tab-switch behavior.
private struct SparklineDrawableLayer: View {
    let points: [BillListSparklineMetrics.Point]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var strokeProgress: CGFloat = 0
    @State private var fillOpacity: CGFloat = 0

    private let lineColor = Color(hex: "69B7CE")
    private let fillTopColor = Color(hex: "69B7CE").opacity(0.08)
    private let fillBottomColor = Color(hex: "69B7CE").opacity(0.02)

    private var amountValues: [Double] {
        points.map(\.amount)
    }

    private var hasDrawableSeries: Bool {
        !points.isEmpty && points.contains { $0.amount > 0 }
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                SparklineFillShape(values: amountValues)
                    .fill(
                        LinearGradient(
                            colors: [fillTopColor, fillBottomColor],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(fillOpacity)

                SparklineStrokeShape(values: amountValues)
                    .trim(from: 0, to: strokeProgress)
                    .stroke(
                        lineColor,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
            }
            .frame(width: size.width, height: size.height)
        }
        .onAppear {
            playDrawAnimation()
        }
    }

    private func playDrawAnimation() {
        guard hasDrawableSeries else {
            strokeProgress = 0
            fillOpacity = 0
            return
        }

        guard !reduceMotion else {
            strokeProgress = 1
            fillOpacity = 1
            return
        }

        strokeProgress = 0
        fillOpacity = 0

        Task { @MainActor in
            await Task.yield()
            guard hasDrawableSeries else { return }

            withAnimation(.easeOut(duration: BillListExpenseSparkline.strokeDrawDuration)) {
                strokeProgress = 1
            }

            let fillDelayNs = UInt64(BillListExpenseSparkline.strokeDrawDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: fillDelayNs)
            guard hasDrawableSeries else { return }

            withAnimation(.easeOut(duration: BillListExpenseSparkline.fillFadeDuration)) {
                fillOpacity = 1
            }
        }
    }
}

// MARK: - Shapes

private struct SparklineStrokeShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        let plotPoints = SparklineGeometry.normalizedPoints(values: values, in: rect)
        return SparklineGeometry.catmullRomPath(through: plotPoints)
    }
}

private struct SparklineFillShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        let plotPoints = SparklineGeometry.normalizedPoints(values: values, in: rect)
        let stroke = SparklineGeometry.catmullRomPath(through: plotPoints)
        return SparklineGeometry.closedFill(stroke: stroke, plotPoints: plotPoints, in: rect)
    }
}

// MARK: - Geometry

private enum SparklineGeometry {
    static func normalizedPoints(values: [Double], in rect: CGRect) -> [CGPoint] {
        guard !values.isEmpty else { return [] }

        let insetX: CGFloat = 2
        let insetY: CGFloat = 4
        let plotWidth = max(rect.width - insetX * 2, 1)
        let plotHeight = max(rect.height - insetY * 2, 1)
        let peak = values.max() ?? 0
        let domainMax = max(peak, 1)
        let stepX = values.count > 1 ? plotWidth / CGFloat(values.count - 1) : 0

        return values.enumerated().map { index, value in
            let x = insetX + CGFloat(index) * stepX
            let normalizedY = CGFloat(value / domainMax)
            let y = rect.maxY - insetY - normalizedY * plotHeight
            return CGPoint(x: x, y: y)
        }
    }

    static func catmullRomPath(through points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }

        if points.count == 1 {
            path.move(to: first)
            return path
        }

        path.move(to: first)

        if points.count == 2, let second = points.last {
            path.addLine(to: second)
            return path
        }

        for index in 0..<(points.count - 1) {
            let p0 = points[max(index - 1, 0)]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = points[min(index + 2, points.count - 1)]

            let control1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6,
                y: p1.y + (p2.y - p0.y) / 6
            )
            let control2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6,
                y: p2.y - (p3.y - p1.y) / 6
            )
            path.addCurve(to: p2, control1: control1, control2: control2)
        }

        return path
    }

    static func closedFill(stroke: Path, plotPoints: [CGPoint], in rect: CGRect) -> Path {
        guard let first = plotPoints.first, let last = plotPoints.last else { return Path() }
        var fill = stroke
        fill.addLine(to: CGPoint(x: last.x, y: rect.maxY))
        fill.addLine(to: CGPoint(x: first.x, y: rect.maxY))
        fill.closeSubpath()
        return fill
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var token = "0"

        var body: some View {
            VStack {
                BillListExpenseSparkline(
                    points: (0..<12).map {
                        BillListSparklineMetrics.Point(id: $0, amount: Double.random(in: 0...800))
                    },
                    replayToken: token
                )
                Button("Replay") { token = UUID().uuidString }
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
