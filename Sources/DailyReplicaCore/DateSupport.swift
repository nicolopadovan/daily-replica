import Foundation

public extension Calendar {
    static let dailyReplica: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()
}

public extension DateInterval {
    static func day(containing date: Date, calendar: Calendar = .dailyReplica) -> DateInterval {
        calendar.dateInterval(of: .day, for: date) ?? DateInterval(start: date, duration: 24 * 60 * 60)
    }
}
