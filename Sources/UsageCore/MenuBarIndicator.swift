import Foundation

public enum MenuBarDisplay: String, CaseIterable, Identifiable, Sendable {
    case both
    case fiveHour = "5h"
    case weekly = "7d"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .both: return "Both limits"
        case .fiveHour: return "Five-hour limit"
        case .weekly: return "Weekly limit"
        }
    }
}

public struct MenuBarQuota: Equatable, Sendable {
    public let label: String
    public let title: String
    public let remainingPercent: Int?

    public var value: String { remainingPercent.map { "\($0)%" } ?? "—" }
    public var accessibleDescription: String {
        remainingPercent.map { "\(title): \($0) percent remaining" } ?? "\(title): unavailable"
    }
}

public struct MenuBarIndicator: Sendable {
    public let quotas: [MenuBarQuota]

    public init(snapshot: UsageSnapshot?, display: MenuBarDisplay, isStale: Bool, now: Date = Date()) {
        let entries = snapshot?.entries ?? []
        // Keep both values in the same bucket; prefer the account's Codex bucket.
        let bucket = (entries.first { $0.id == "codex" } ?? entries.first)?.bucket
        func quota(minutes: Int, label: String, title: String) -> MenuBarQuota {
            let window = bucket?.windows.first { $0.windowDurationMins == minutes }
            let available = !isStale && window?.hasExpired(at: now) == false
            return MenuBarQuota(label: label, title: title, remainingPercent: available ? window?.remainingPercent : nil)
        }
        let fiveHour = quota(minutes: 300, label: "5h", title: "Five-hour limit")
        let weekly = quota(minutes: 10080, label: "7d", title: "Weekly limit")
        switch display {
        case .both: quotas = [fiveHour, weekly]
        case .fiveHour: quotas = [fiveHour]
        case .weekly: quotas = [weekly]
        }
    }

    public var accessibilityLabel: String {
        "Codex usage. " + quotas.map(\.accessibleDescription).joined(separator: ". ")
    }
}
