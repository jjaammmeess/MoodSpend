import Foundation

enum DateFilter: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case year

    var id: String { rawValue }

    func includes(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch self {
        case .day:
            return calendar.isDate(date, inSameDayAs: now)
        case .week:
            return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) &&
                calendar.isDate(date, equalTo: now, toGranularity: .yearForWeekOfYear)
        case .month:
            return calendar.isDate(date, equalTo: now, toGranularity: .month) &&
                calendar.isDate(date, equalTo: now, toGranularity: .year)
        case .year:
            return calendar.isDate(date, equalTo: now, toGranularity: .year)
        }
    }
}
