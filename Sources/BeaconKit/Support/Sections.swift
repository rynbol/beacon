import Foundation

/// The only grouping the list offers. Relative dates, nothing else — no
/// folders, no tags, no saved views, because a task the user has to go looking
/// for is a task the user will forget.
public enum TaskSection: Int, CaseIterable, Sendable, Comparable {
    case today
    case tomorrow
    case next7
    case next30
    case later
    /// Deferred indefinitely. Last before completed work, so it never competes
    /// with anything that has a real date.
    case someday
    case recentlyCompleted

    public var title: String {
        switch self {
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        case .next7: return "Next 7 Days"
        case .next30: return "Next 30 Days"
        case .later: return "Later"
        case .someday: return "Someday"
        case .recentlyCompleted: return "Recently Completed"
        }
    }

    public static func < (lhs: TaskSection, rhs: TaskSection) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// One section and the tasks inside it, ready for a list to iterate.
public struct TaskGroup: Identifiable, Sendable, Equatable {
    public let section: TaskSection
    public let tasks: [TaskSnapshot]
    public var id: Int { section.rawValue }
}

/// How the list is divided.
public enum Grouping: String, Sendable, CaseIterable, Identifiable {
    /// Relative-date sections. The default, because when a task is due is the
    /// only thing that decides whether it needs attention now.
    case time
    /// One section per Reminders list, for people who already sort their tasks
    /// that way.
    case list

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .time: return "By time"
        case .list: return "By list"
        }
    }
}

/// One group when grouping by list. Lists are named by the user, so the header
/// is a free string rather than a case.
public struct ListGroup: Identifiable, Sendable, Equatable {
    public let name: String
    public let tasks: [TaskSnapshot]
    public var id: String { name }
}

public enum Sections {

    /// Groups by Reminders list.
    ///
    /// Completed tasks stay in their own trailing group rather than joining a
    /// list, so finishing something never buries it back among the unfinished.
    public static func groupByList(
        _ tasks: [TaskSnapshot], now: Date, calendar: Calendar
    ) -> [ListGroup] {
        var buckets: [String: [TaskSnapshot]] = [:]
        var completed: [TaskSnapshot] = []

        var someday: [TaskSnapshot] = []
        for task in tasks {
            if task.isCompleted {
                completed.append(task)
            } else if task.isSomeday(now: now, horizon: Settings.default.somedayHorizon) {
                someday.append(task)
            } else {
                let name = task.listName.isEmpty ? "Reminders" : task.listName
                buckets[name, default: []].append(task)
            }
        }

        var groups = buckets.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map { name in
                ListGroup(name: name, tasks: sortForDisplay(buckets[name] ?? []))
            }
        if !someday.isEmpty {
            groups.append(
                ListGroup(name: TaskSection.someday.title, tasks: sortForDisplay(someday))
            )
        }
        if !completed.isEmpty {
            groups.append(
                ListGroup(name: TaskSection.recentlyCompleted.title, tasks: sortForDisplay(completed))
            )
        }
        return groups
    }

    /// Undated first — a task with no time is due now — then by due date, then
    /// by title so the order never wobbles between reads.
    static func sortForDisplay(_ tasks: [TaskSnapshot]) -> [TaskSnapshot] {
        tasks.sorted { lhs, rhs in
            switch (lhs.due, rhs.due) {
            case let (l?, r?) where l != r: return l < r
            case (nil, .some): return true
            case (.some, nil): return false
            default: return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }

    /// Where a task belongs.
    ///
    /// Anything undated or already past its due date lands in Today. There is
    /// no overdue bucket, and that is deliberate: the app never tells the user
    /// they are behind.
    public static func bucket(
        _ task: TaskSnapshot, now: Date, calendar: Calendar,
        somedayHorizon: TimeInterval = Settings.default.somedayHorizon
    ) -> TaskSection {
        if task.isCompleted { return .recentlyCompleted }
        if task.isSomeday(now: now, horizon: somedayHorizon) { return .someday }
        guard let due = task.due, due > now else { return .today }

        let today = calendar.startOfDay(for: now)
        let dueDay = calendar.startOfDay(for: due)
        let days = calendar.dateComponents([.day], from: today, to: dueDay).day ?? 0

        switch days {
        case ..<1: return .today
        case 1: return .tomorrow
        case 2...7: return .next7
        case 8...30: return .next30
        default: return .later
        }
    }

    /// Groups tasks into display order: sections in fixed order, tasks inside a
    /// section by due date, with undated tasks first because they are due now.
    public static func group(
        _ tasks: [TaskSnapshot], now: Date, calendar: Calendar,
        somedayHorizon: TimeInterval = Settings.default.somedayHorizon
    ) -> [TaskGroup] {
        var buckets: [TaskSection: [TaskSnapshot]] = [:]
        for task in tasks {
            let section = bucket(task, now: now, calendar: calendar, somedayHorizon: somedayHorizon)
            buckets[section, default: []].append(task)
        }
        return TaskSection.allCases.compactMap { section in
            guard let group = buckets[section], !group.isEmpty else { return nil }
            return TaskGroup(section: section, tasks: sortForDisplay(group))
        }
    }

    /// The line under a task title.
    ///
    /// A past-due task reads "Now", never a date in red. Everything is due now
    /// or in the future (DESIGN.md §2).
    public static func relativeText(
        for task: TaskSnapshot, now: Date, calendar: Calendar,
        somedayHorizon: TimeInterval = Settings.default.somedayHorizon
    ) -> String {
        if task.isCompleted { return "Done" }
        if task.isSomeday(now: now, horizon: somedayHorizon) { return "Someday" }
        guard let due = task.due, due > now else { return "Now" }

        let today = calendar.startOfDay(for: now)
        let dueDay = calendar.startOfDay(for: due)
        let days = calendar.dateComponents([.day], from: today, to: dueDay).day ?? 0

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = .current

        guard task.hasTimeOfDay else {
            switch days {
            case 0: return "Today"
            case 1: return "Tomorrow"
            case 2...6: formatter.dateFormat = "EEEE"; return formatter.string(from: due)
            default: formatter.dateFormat = "d MMM"; return formatter.string(from: due)
            }
        }

        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let time = formatter.string(from: due)

        switch days {
        case 0: return time
        case 1: return "Tomorrow at \(time)"
        case 2...6:
            let weekday = DateFormatter()
            weekday.calendar = calendar; weekday.timeZone = calendar.timeZone
            weekday.dateFormat = "EEEE"
            return "\(weekday.string(from: due)) at \(time)"
        default:
            let day = DateFormatter()
            day.calendar = calendar; day.timeZone = calendar.timeZone
            day.dateFormat = "d MMM"
            return "\(day.string(from: due)) at \(time)"
        }
    }
}
