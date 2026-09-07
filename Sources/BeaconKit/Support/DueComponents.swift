import Foundation

/// Builds the date components EventKit will accept for a reminder's due date.
///
/// Every rule here is one EventKit will otherwise break silently or loudly:
///
/// - The calendar must be Gregorian. Anything else raises an Objective-C
///   exception, which Swift cannot catch — so this is a precondition, not an
///   error to handle.
/// - iOS requires a start date whenever a due date is set. macOS does not, but
///   writing both keeps one code path and keeps the data valid on the phone.
/// - Omitting hour, minute and second silently turns the reminder into an
///   all-day item.
/// - Invalid dates normalise rather than fail: 31 February saves as 3 March.
///   That is a silent corruption of the user's data, so it is checked first.
public enum DueComponents {

    /// Components for an instant, or `nil` when the instant does not exist in
    /// this calendar — a gap left by a daylight-saving jump, for example.
    public static func make(from date: Date, calendar: Calendar) -> DateComponents? {
        precondition(
            calendar.identifier == .gregorian,
            "EventKit raises an uncatchable exception on any non-Gregorian calendar"
        )
        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date
        )
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        guard components.isValidDate(in: calendar) else { return nil }
        return components
    }

    /// Whether components carry a time of day, or describe a whole day.
    public static func hasTimeOfDay(_ components: DateComponents?) -> Bool {
        components?.hour != nil
    }
}
