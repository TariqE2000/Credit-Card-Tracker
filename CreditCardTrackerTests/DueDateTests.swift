import XCTest
@testable import CreditCardTracker

final class DueDateTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testMonthAndDayComeFromThePickedDate() {
        let due = DueDate(date: date(2026, 12, 14), calendar: calendar)
        XCTAssertEqual(due, DueDate(month: 12, day: 14))
        XCTAssertEqual(due?.digits, "1214")
    }

    func testTheYearIsDropped() {
        XCTAssertEqual(
            DueDate(date: date(2027, 3, 5), calendar: calendar),
            DueDate(date: date(2030, 3, 5), calendar: calendar)
        )
    }

    func testNextOccurrenceLaterThisYear() {
        let due = DueDate(month: 12, day: 14)!
        XCTAssertEqual(due.nextOccurrence(onOrAfter: date(2026, 11, 23), calendar: calendar), date(2026, 12, 14))
    }

    func testNextOccurrenceRollsIntoNextYearOncePassed() {
        let due = DueDate(month: 3, day: 5)!
        XCTAssertEqual(due.nextOccurrence(onOrAfter: date(2026, 11, 23), calendar: calendar), date(2027, 3, 5))
    }

    func testNextOccurrenceCountsTheReferenceDayItself() {
        let due = DueDate(month: 11, day: 23)!
        XCTAssertEqual(due.nextOccurrence(onOrAfter: date(2026, 11, 23), calendar: calendar), date(2026, 11, 23))
    }

    func testLeapDayWaitsForTheNextLeapYear() {
        let due = DueDate(month: 2, day: 29)!
        XCTAssertEqual(due.nextOccurrence(onOrAfter: date(2026, 11, 23), calendar: calendar), date(2028, 2, 29))
    }

    func testPickedDateRoundTripsThroughTheField() {
        // What the calendar shows for a typed date turns back into the same month and day.
        let typed = DueDate(digits: "0907")!
        let shown = typed.nextOccurrence(onOrAfter: date(2026, 11, 23), calendar: calendar)!
        XCTAssertEqual(DueDate(date: shown, calendar: calendar), typed)
    }
}
