import Foundation

extension TransactionRecord {
    func markDeleted(at date: Date = Date()) {
        deletedAt = date
        touchUpdatedAt()
    }
}

extension CustomOption {
    func markDeleted(at date: Date = Date()) {
        deletedAt = date
        updatedAt = date
    }
}
