import SwiftUI

/// Controls decorative chart motion on the Analysis tab (Timeline loops, stagger entrances).
/// Set from `AnalysisView` based on `scenePhase`; child charts read via `@Environment`.
enum AnalysisChartMotionMode: Equatable {
    /// Timeline + stagger entrances allowed.
    case live
    /// App inactive/background, or brief post-foreground cooldown: freeze Timeline, cancel stagger.
    case suspended
}

private struct AnalysisChartMotionModeKey: EnvironmentKey {
    static let defaultValue: AnalysisChartMotionMode = .live
}

extension EnvironmentValues {
    var analysisChartMotionMode: AnalysisChartMotionMode {
        get { self[AnalysisChartMotionModeKey.self] }
        set { self[AnalysisChartMotionModeKey.self] = newValue }
    }
}

/// Maps `scenePhase` → `AnalysisChartMotionMode` for the analysis scroll content tree.
private struct AnalysisChartMotionPhaseController: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Binding var motionMode: AnalysisChartMotionMode
    @State private var timelineResumeTask: Task<Void, Never>?

    /// Delay Timeline resume after foreground so immediate scrolling stays smooth.
    private static let timelineResumeDelayNanoseconds: UInt64 = 300_000_000

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, phase in
                timelineResumeTask?.cancel()
                switch phase {
                case .active:
                    timelineResumeTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: Self.timelineResumeDelayNanoseconds)
                        guard !Task.isCancelled else { return }
                        motionMode = .live
                    }
                case .inactive, .background:
                    motionMode = .suspended
                @unknown default:
                    motionMode = .suspended
                }
            }
    }
}

extension View {
    func analysisChartMotionLifecycle(motionMode: Binding<AnalysisChartMotionMode>) -> some View {
        modifier(AnalysisChartMotionPhaseController(motionMode: motionMode))
    }
}
