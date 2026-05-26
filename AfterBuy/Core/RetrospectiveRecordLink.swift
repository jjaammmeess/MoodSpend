import Foundation
import SwiftData

/// Stable deep link for retrospective notifications: `publicId` can collide or be reassigned during
/// `TransactionRecordPublicIdSync`, but `persistentModelID` always identifies one row.
enum RetrospectiveRecordLink {
    static func persistentToken(for record: TransactionRecord) -> String? {
        guard let data = try? JSONEncoder().encode(record.persistentModelID) else { return nil }
        return data.base64EncodedString()
    }

    static func persistentIdentifier(fromToken token: String) -> PersistentIdentifier? {
        guard let data = Data(base64Encoded: token) else { return nil }
        return try? JSONDecoder().decode(PersistentIdentifier.self, from: data)
    }
}
