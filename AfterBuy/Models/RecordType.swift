import Foundation

enum RecordType: String, Codable, CaseIterable, Identifiable {
    case expense
    case income

    var id: String { rawValue }
}
