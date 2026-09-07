import Foundation

public struct ParsedCapture: Sendable, Equatable {
    /// The text with any date phrase removed.
    public let title: String
    /// The instant the date phrase named, if there was one.
    public let due: Date?

    public init(title: String, due: Date?) {
        self.title = title
        self.due = due
    }
}

/// Pulls a due date out of ordinary typed text.
///
/// "pay rent friday 9am" becomes the title "pay rent" due Friday at 09:00. This
/// closes the loudest complaint against the app Beacon is modelled on, whose
/// capture only parses dates out of dictation.
///
/// `NSDataDetector` does the work: it is on the device already, costs nothing,
/// needs no network, and handles the phrasings people actually type.
public enum Capture {

    private static let detector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.date.rawValue
    )

    public static func parse(_ text: String, now: Date = Date()) -> ParsedCapture {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ParsedCapture(title: trimmed, due: nil) }

        // Relative durations come first, because the system detector does not
        // read "in 2 hours" or "in 30 minutes" at all — and those are exactly
        // how people phrase a reminder. Where it does read a phrase such as
        // "in 3 days", it rounds to midday; an offset from now is what the user
        // meant.
        if let relative = parseRelative(trimmed, now: now) { return relative }

        guard let detector else { return ParsedCapture(title: trimmed, due: nil) }

        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard
            let match = detector.firstMatch(in: trimmed, range: range),
            let date = match.date,
            let matched = Range(match.range, in: trimmed)
        else {
            return ParsedCapture(title: trimmed, due: nil)
        }

        // A date phrase that swallowed the entire text leaves nothing to name
        // the task, so keep the text and drop the date.
        var title = trimmed
        title.removeSubrange(matched)
        title = tidy(title)
        guard !title.isEmpty else { return ParsedCapture(title: trimmed, due: nil) }

        return ParsedCapture(title: title, due: date)
    }

    private static let relativePattern = try? NSRegularExpression(
        pattern: #"\bin\s+(\d{1,4})\s*(minutes?|mins?|hours?|hrs?|days?|weeks?)\b"#,
        options: .caseInsensitive
    )

    /// Reads "in 20 minutes", "in 2 hours", "in 3 days", "in 1 week".
    private static func parseRelative(_ text: String, now: Date) -> ParsedCapture? {
        guard let relativePattern else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = relativePattern.firstMatch(in: text, range: range),
            let amountRange = Range(match.range(at: 1), in: text),
            let unitRange = Range(match.range(at: 2), in: text),
            let matched = Range(match.range, in: text),
            let amount = Int(text[amountRange])
        else { return nil }

        let unit = text[unitRange].lowercased()
        let seconds: TimeInterval
        switch unit.first {
        case "m": seconds = 60
        case "h": seconds = 3_600
        case "d": seconds = 86_400
        case "w": seconds = 604_800
        default: return nil
        }

        var title = text
        title.removeSubrange(matched)
        title = tidy(title)
        guard !title.isEmpty else { return nil }

        return ParsedCapture(title: title, due: now.addingTimeInterval(TimeInterval(amount) * seconds))
    }

    /// Removes the connecting words a date phrase leaves behind, so "call Ana
    /// on tuesday" does not become "call Ana on".
    private static func tidy(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let danglers = ["at", "on", "by", "in", "this", "next", "the"]
        var changed = true
        while changed {
            changed = false
            for word in danglers {
                for pattern in [" \(word)", "\(word) "] where
                    pattern.hasPrefix(" ") ? result.lowercased().hasSuffix(pattern)
                                           : result.lowercased().hasPrefix(pattern) {
                    if pattern.hasPrefix(" ") {
                        result.removeLast(pattern.count)
                    } else {
                        result.removeFirst(pattern.count)
                    }
                    result = result.trimmingCharacters(in: .whitespacesAndNewlines)
                    changed = true
                }
            }
        }
        return result
    }
}
