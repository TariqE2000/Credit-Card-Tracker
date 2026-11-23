import Foundation

/// Turning what the user types in the card form into numbers, and back.
enum FormInput {
    /// Reads an amount such as "2480.15" or "2,480.15". Empty, negative or unreadable text gives nil.
    static func decimal(from text: String, locale: Locale = .current) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.generatesDecimalNumbers = true

        guard let number = formatter.number(from: trimmed) as? NSDecimalNumber else { return nil }
        let value = number.decimalValue
        return value >= 0 ? value : nil
    }

    /// Text to put back in a field: "2480.15", "45", or "" when there is no value.
    static func text(for value: Decimal?, locale: Locale = .current) -> String {
        guard let value else { return "" }
        return value.formatted(
            .number
                .grouping(.never)
                .precision(.fractionLength(0...2))
                .locale(locale)
        )
    }

    /// True when the field is empty (nothing to save) or holds a readable amount.
    static func isValidOptionalAmount(_ text: String, locale: Locale = .current) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || decimal(from: trimmed, locale: locale) != nil
    }

    /// Shows typed due date digits as "12 / 14".
    static func dueDateDisplay(forDigits digits: String) -> String {
        digits.count <= 2 ? digits : "\(digits.prefix(2)) / \(digits.dropFirst(2))"
    }

    /// Keeps only the digits of what was typed in the due date field (at most four). A first digit
    /// that cannot start a month (2 to 9) gets a 0 in front, so typing "5" becomes "05".
    static func dueDateDigits(fromTyped text: String) -> String {
        var digits = String(text.filter { $0.isASCII && $0.isNumber }.prefix(4))
        if digits.count == 1, let first = digits.first, first > "1" {
            digits = "0" + digits
        }
        return digits
    }
}
