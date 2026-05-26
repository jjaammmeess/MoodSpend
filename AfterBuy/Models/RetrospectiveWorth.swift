import Foundation

/// Post-hoc review of a purchase (typically prompted ~3 days after logging).
enum RetrospectiveWorth: String, Codable, CaseIterable, Identifiable {
    case worthIt
    case neutral
    case regret

    var id: String { rawValue }
}
