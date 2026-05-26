import Foundation

/// Lightweight record fields for off-main-thread period/window filtering (avoids SwiftData faulting in `body`).
struct AnalysisRecordFilterStub: Sendable {
    let publicId: UUID
    let createdAt: Date
    let typeRaw: String
}

struct AnalysisExpenseFilterBuildInput: Sendable {
    let stubs: [AnalysisRecordFilterStub]
    let periodIntervalStart: Date?
    let periodIntervalEnd: Date?
    let previousIntervalStart: Date?
    let previousIntervalEnd: Date?
    let emotionTrendWindowRaw: String
    let calendarFirstWeekday: Int
    let now: Date
}

struct AnalysisExpenseFilterBuildResult: Sendable {
    let filteredPublicIds: [UUID]
    let previousPeriodPublicIds: [UUID]
    let emotionTrendWindowPublicIds: [UUID]
}

enum AnalysisExpenseFilterCache {
    static func build(input: AnalysisExpenseFilterBuildInput) -> AnalysisExpenseFilterBuildResult {
        var calendar = Calendar.current
        calendar.firstWeekday = input.calendarFirstWeekday

        let filtered = filterExpensePublicIds(
            stubs: input.stubs,
            start: input.periodIntervalStart,
            end: input.periodIntervalEnd
        )
        let previous = filterExpensePublicIds(
            stubs: input.stubs,
            start: input.previousIntervalStart,
            end: input.previousIntervalEnd
        )
        let trendWindow = filterEmotionTrendWindowPublicIds(
            stubs: input.stubs,
            windowRaw: input.emotionTrendWindowRaw,
            calendar: calendar,
            now: input.now
        )
        return AnalysisExpenseFilterBuildResult(
            filteredPublicIds: filtered,
            previousPeriodPublicIds: previous,
            emotionTrendWindowPublicIds: trendWindow
        )
    }

    private static func filterExpensePublicIds(
        stubs: [AnalysisRecordFilterStub],
        start: Date?,
        end: Date?
    ) -> [UUID] {
        guard let start, let end else { return [] }
        return stubs.compactMap { stub in
            guard stub.typeRaw == RecordType.expense.rawValue else { return nil }
            guard stub.createdAt >= start, stub.createdAt < end else { return nil }
            return stub.publicId
        }
    }

    private static func filterEmotionTrendWindowPublicIds(
        stubs: [AnalysisRecordFilterStub],
        windowRaw: String,
        calendar: Calendar,
        now: Date
    ) -> [UUID] {
        stubs.compactMap { stub in
            guard stub.typeRaw == RecordType.expense.rawValue else { return nil }
            guard recordIsInEmotionTrendWindow(
                createdAt: stub.createdAt,
                windowRaw: windowRaw,
                calendar: calendar,
                now: now
            ) else { return nil }
            return stub.publicId
        }
    }

    static func recordIsInEmotionTrendWindow(
        createdAt: Date,
        windowRaw: String,
        calendar: Calendar,
        now: Date
    ) -> Bool {
        switch windowRaw {
        case "today":
            return calendar.isDate(createdAt, inSameDayAs: now)
        case "last7", "last14", "last30", "last60":
            let n = rollingDayCount(for: windowRaw)
            let endDay = calendar.startOfDay(for: now)
            guard let startDay = calendar.date(byAdding: .day, value: -(n - 1), to: endDay),
                  let nextMidnight = calendar.date(byAdding: .day, value: 1, to: endDay)
            else { return false }
            return createdAt >= startDay && createdAt < nextMidnight
        default:
            return false
        }
    }

    private static func rollingDayCount(for windowRaw: String) -> Int {
        switch windowRaw {
        case "today": return 1
        case "last7": return 7
        case "last14": return 14
        case "last30": return 30
        case "last60": return 60
        default: return 7
        }
    }
}
