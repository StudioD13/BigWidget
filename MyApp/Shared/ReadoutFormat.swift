import SwiftUI

/// Text and colors for each readout, shared by the app and the widgets so they always match.
enum ReadoutFormat {
    // MARK: Time

    /// Hours and minutes without an AM/PM marker, e.g. "9:05" or "21:05".
    static func clock(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute(.twoDigits))
    }

    /// Hours and minutes separately, for a stacked two-line clock (e.g. "9" over "05").
    static func clockParts(_ date: Date) -> (hour: String, minute: String) {
        (
            date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted))),
            date.formatted(.dateTime.minute(.twoDigits))
        )
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

    static func shortMonth(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated)).uppercased()
    }

    // MARK: Battery

    static func battery(_ level: Double?) -> String {
        guard let level else { return "--" }
        return "\(Int((level * 100).rounded()))%"
    }

    static func batteryTint(_ level: Double?) -> Color {
        guard let level else { return .gray }
        switch level {
        case ..<0.2: return NeonColor.red
        case ..<0.5: return NeonColor.yellow
        default: return NeonColor.green
        }
    }

    // MARK: Weather

    /// Classic weather color: blue when cold, green when mild, orange when warm, red when hot.
    static func weatherTint(celsius: Double?) -> Color {
        guard let celsius else { return .gray }
        switch celsius {
        case ..<5: return NeonColor.blue
        case ..<18: return NeonColor.green
        case ..<28: return NeonColor.orange
        default: return NeonColor.red
        }
    }

    // MARK: Tints

    static let timeTint = NeonColor.blue
    static let dateTint = NeonColor.red
}
