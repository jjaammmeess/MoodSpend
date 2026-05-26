import Foundation
import SwiftData

enum ActiveRecordsFetch {
    static var transactionSort: [SortDescriptor<TransactionRecord>] {
        [SortDescriptor(\TransactionRecord.createdAt, order: .reverse)]
    }

    static var customOptionSort: [SortDescriptor<CustomOption>] {
        [SortDescriptor(\CustomOption.createdAt, order: .reverse)]
    }

    static func activeTransactions() -> FetchDescriptor<TransactionRecord> {
        FetchDescriptor<TransactionRecord>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: transactionSort
        )
    }

    static func activeCustomOptions() -> FetchDescriptor<CustomOption> {
        FetchDescriptor<CustomOption>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: customOptionSort
        )
    }
}
