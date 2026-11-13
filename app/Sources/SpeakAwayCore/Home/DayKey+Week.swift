import Foundation

extension DayKey {
    /// 0 for Monday through 6 for Sunday. Day 0 (1 January 1970) was a Thursday.
    public var weekdayIndex: Int { (((ordinal % 7) + 7) % 7 + 3) % 7 }

    public var mondayOfWeek: DayKey { adding(-weekdayIndex) }

    public var sundayOfWeek: DayKey { adding(6 - weekdayIndex) }
}
