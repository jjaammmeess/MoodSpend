import Combine
import Foundation

/// Cached chart payloads for the Analysis tab so switching away and back does not flash empty states.
struct AnalysisTabMetricsSnapshot {
    let token: String
    let metricsCache: AnalysisViewMetricsCache
    let trendBuckets: [EmotionTrendChartBucket]
    let heatmapCells: [EmotionHeatmapCell]
    let generatedInsight: GeneratedInsight
}

@MainActor
final class AnalysisTabMetricsStore: ObservableObject {
    private(set) var snapshot: AnalysisTabMetricsSnapshot?

    func update(_ snapshot: AnalysisTabMetricsSnapshot) {
        self.snapshot = snapshot
    }
}
