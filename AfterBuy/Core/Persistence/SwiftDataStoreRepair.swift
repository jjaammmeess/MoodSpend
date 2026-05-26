import Foundation

/// File-level repair when SwiftData cannot open the store (corrupt sqlite / schema mismatch).
enum SwiftDataStoreRepair {
    static func removeStoreFiles(at url: URL) {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: url)
        for suffix in ["-shm", "-wal"] {
            try? fileManager.removeItem(atPath: url.path + suffix)
        }
    }
}
