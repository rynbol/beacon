import Foundation

/// Mirrors Apple Reminders priority without affecting Beacon's alert schedule.
public enum Urgency: String, CaseIterable, Sendable {
    case none, low, medium, high

    public var title: String { rawValue.capitalized }
    public var priority: Int {
        switch self { case .none: 0; case .low: 9; case .medium: 5; case .high: 1 }
    }
    public init(priority: Int) {
        switch priority {
        case 1...4: self = .high
        case 5: self = .medium
        case 6...9: self = .low
        default: self = .none
        }
    }
}
