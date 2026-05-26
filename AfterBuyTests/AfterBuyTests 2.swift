//
//  AfterBuyTests.swift
//  AfterBuyTests
//

import Foundation
import SwiftData
import Testing
@testable import AfterBuy

struct AfterBuyTests {

    @Test @MainActor
    func transactionPublicIdsAreMadeUnique() throws {
        let controller = PersistenceController.inMemoryForPreviews()
        let context = ModelContext(controller.modelContainer)

        let sharedId = UUID()
        let first = TransactionRecord(
            amount: 10,
            type: .expense,
            categoryKey: "food",
            categoryName: "Food",
            emotionRaw: EmotionTag.necessity.rawValue,
            emotionName: "necessity",
            emotionColorHex: EmotionTag.necessity.colorHex,
            note: "a",
            publicId: sharedId
        )
        let second = TransactionRecord(
            amount: 20,
            type: .expense,
            categoryKey: "food",
            categoryName: "Food",
            emotionRaw: EmotionTag.necessity.rawValue,
            emotionName: "necessity",
            emotionColorHex: EmotionTag.necessity.colorHex,
            note: "b",
            publicId: sharedId
        )
        context.insert(first)
        context.insert(second)
        try context.save()

        TransactionRecordPublicIdSync.ensureUniquePublicIds(modelContext: context)

        #expect(first.publicId != second.publicId)
    }

    @Test @MainActor
    func customOptionPublicIdsAreMadeUnique() throws {
        let controller = PersistenceController.inMemoryForPreviews()
        let context = ModelContext(controller.modelContainer)

        let sharedId = UUID()
        let first = CustomOption(kind: .category, name: "A", publicId: sharedId)
        let second = CustomOption(kind: .category, name: "B", publicId: sharedId)
        context.insert(first)
        context.insert(second)
        try context.save()

        CustomOptionPublicIdSync.ensureUniquePublicIds(modelContext: context)

        #expect(first.publicId != second.publicId)
    }

    @Test @MainActor
    func softDeletedRecordsAreExcludedFromActiveFetch() throws {
        let controller = PersistenceController.inMemoryForPreviews()
        let context = ModelContext(controller.modelContainer)

        let active = TransactionRecord(
            amount: 1,
            type: .expense,
            categoryKey: "k",
            categoryName: "K",
            emotionRaw: EmotionTag.necessity.rawValue,
            emotionName: "n",
            emotionColorHex: EmotionTag.necessity.colorHex,
            note: ""
        )
        let deleted = TransactionRecord(
            amount: 2,
            type: .expense,
            categoryKey: "k",
            categoryName: "K",
            emotionRaw: EmotionTag.necessity.rawValue,
            emotionName: "n",
            emotionColorHex: EmotionTag.necessity.colorHex,
            note: ""
        )
        deleted.markDeleted()
        context.insert(active)
        context.insert(deleted)
        try context.save()

        let fetched = try context.fetch(ActiveRecordsFetch.activeTransactions())
        #expect(fetched.count == 1)
        #expect(fetched.first?.publicId == active.publicId)
    }
}
