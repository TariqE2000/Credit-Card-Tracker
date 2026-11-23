import XCTest
@testable import CreditCardTracker

final class FormInputTests: XCTestCase {
    private let us = Locale(identifier: "en_US")

    func testReadsAmounts() {
        XCTAssertEqual(FormInput.decimal(from: "2480.15", locale: us), Decimal(string: "2480.15", locale: us))
        XCTAssertEqual(FormInput.decimal(from: "2,480.15", locale: us), Decimal(string: "2480.15", locale: us))
        XCTAssertEqual(FormInput.decimal(from: " 45 ", locale: us), 45)
        XCTAssertEqual(FormInput.decimal(from: "0", locale: us), 0)
    }

    func testRejectsBadAmounts() {
        XCTAssertNil(FormInput.decimal(from: "", locale: us))
        XCTAssertNil(FormInput.decimal(from: "abc", locale: us))
        XCTAssertNil(FormInput.decimal(from: "1.2.3", locale: us))
        XCTAssertNil(FormInput.decimal(from: "-5", locale: us))
    }

    func testEmptyFieldCountsAsValid() {
        XCTAssertTrue(FormInput.isValidOptionalAmount("", locale: us))
        XCTAssertTrue(FormInput.isValidOptionalAmount("  ", locale: us))
        XCTAssertTrue(FormInput.isValidOptionalAmount("24.99", locale: us))
        XCTAssertFalse(FormInput.isValidOptionalAmount("1.2.3", locale: us))
    }

    func testTextForValue() {
        XCTAssertEqual(FormInput.text(for: nil, locale: us), "")
        XCTAssertEqual(FormInput.text(for: 45, locale: us), "45")
        XCTAssertEqual(FormInput.text(for: Decimal(string: "2480.15", locale: us), locale: us), "2480.15")
        XCTAssertEqual(FormInput.text(for: Decimal(string: "24.9", locale: us), locale: us), "24.9")
    }

    func testDueDateTyping() {
        XCTAssertEqual(FormInput.dueDateDigits(fromTyped: "1"), "1")
        XCTAssertEqual(FormInput.dueDateDigits(fromTyped: "5"), "05")
        XCTAssertEqual(FormInput.dueDateDigits(fromTyped: "12 / 14"), "1214")
        XCTAssertEqual(FormInput.dueDateDigits(fromTyped: "12345"), "1234")
        XCTAssertEqual(FormInput.dueDateDigits(fromTyped: "1a2"), "12")
        XCTAssertEqual(FormInput.dueDateDigits(fromTyped: "12 / "), "12")
    }

    func testDueDateDisplay() {
        XCTAssertEqual(FormInput.dueDateDisplay(forDigits: ""), "")
        XCTAssertEqual(FormInput.dueDateDisplay(forDigits: "12"), "12")
        XCTAssertEqual(FormInput.dueDateDisplay(forDigits: "121"), "12 / 1")
        XCTAssertEqual(FormInput.dueDateDisplay(forDigits: "1214"), "12 / 14")
    }
}
