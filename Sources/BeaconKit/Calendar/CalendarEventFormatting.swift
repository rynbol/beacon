import Foundation

public enum CalendarEventFormatting {
    public static func timeRange(_ event: CalendarEventSnapshot, calendar: Calendar = .current, locale: Locale = .current) -> String {
        if event.isAllDay {
            let lastDay = max(event.start, event.end.addingTimeInterval(-1))
            if calendar.isDate(event.start, inSameDayAs: lastDay) { return "All day" }
            let formatter = DateIntervalFormatter()
            formatter.locale = locale; formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
            formatter.dateStyle = .medium; formatter.timeStyle = .none
            return "All day · " + formatter.string(from: event.start, to: lastDay)
        }
        if calendar.isDate(event.start, inSameDayAs: event.end) {
            let formatter = DateIntervalFormatter()
            formatter.locale = locale; formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
            formatter.dateStyle = .none; formatter.timeStyle = .short
            return formatter.string(from: event.start, to: event.end)
        }
        let formatter = DateFormatter()
        formatter.locale = locale; formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        let acrossYears = calendar.component(.year, from: event.start) != calendar.component(.year, from: event.end)
        formatter.setLocalizedDateFormatFromTemplate(acrossYears ? "yMMMdjm" : "MMMdjm")
        return formatter.string(from: event.start) + " – " + formatter.string(from: event.end)
    }
}
