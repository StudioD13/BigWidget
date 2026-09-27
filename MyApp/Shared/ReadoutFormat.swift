import SwiftUI

/// Text and colors for each readout, shared by the app and the widgets so they always match.
enum ReadoutFormat {
    // MARK: Time

    /// Hours and minutes without an AM/PM marker, e.g. "9:05" or "21:05".
    static func clock(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute(.twoDigits))
    }

    /// "AM"/"PM" when the current locale uses a 12-hour clock, otherwise `nil`.
    static func period(_ date: Date) -> String? {
        let pattern = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? ""
        guard pattern.contains("a") else { return nil }
        let hour = Calendar.current.component(.hour, from: date)
        let formatter = DateFormatter()
        return hour < 12 ? formatter.amSymbol : formatter.pmSymbol
    }

    // MARK: Date

    static func weekday(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide)).uppercased()
    }

    static func shortWeekday(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated)).uppercased()
    }

    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day())
    }

    static func month(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide)).uppercased()
    }

    // MARK: Battery

    static func battery(_ level: Double?) -> String {
        guard let level else { return "--" }
        return "\(Int((level * 100).rounded()))%"
    }

    static func batteryTint(_ level: Double?) -> Color {
        guard let level else { return .gray }
        switch level {
        case ..<0.2: return .red
        case ..<0.5: return .orange
        default: return .green
        }
    }

    // MARK: Tints

    static let timeTint = Color.cyan
    static let dateTint = Color.pink
}
