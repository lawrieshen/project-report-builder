import Foundation

enum MilestoneCountdown {
    /// Compare calendar days so time-of-day and daylight saving do not shift the label.
    static func text(deadline: Date, now: Date, calendar: Calendar = .current) -> String {
        let today = calendar.startOfDay(for: now)
        let due = calendar.startOfDay(for: deadline)
        let days = calendar.dateComponents([.day], from: today, to: due).day ?? 0
        if days == 0 { return "Due today" }
        if days < 0 { return "\(-days) \(days == -1 ? "day" : "days") overdue" }
        return "\(days) \(days == 1 ? "day" : "days") remaining"
    }
}
