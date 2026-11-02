import Foundation

public enum PanelFailure: Equatable, Sendable {
    case codexMissing, signInRequired, refresh

    public init(error: Error) {
        if case CodexError.missingExecutable = error {
            self = .codexMissing
        } else if case CodexError.service(let message) = error,
                  ["sign in", "sign-in", "not signed in", "not logged in", "not authenticated", "unauthorized", "authentication required", "authentication is required"]
                    .contains(where: { message.lowercased().contains($0) }) {
            self = .signInRequired
        } else {
            self = .refresh
        }
    }
}

public enum PanelPhase: String, Sendable {
    case loading, ready, refreshFailed, retrying, codexMissing, signInRequired

    public init(hasData: Bool, isRefreshing: Bool, isStale: Bool, failure: PanelFailure?) {
        if failure == .codexMissing { self = .codexMissing }
        else if failure == .signInRequired { self = .signInRequired }
        else if isRefreshing {
            if failure != nil || (hasData && isStale) { self = .retrying }
            else { self = hasData ? .ready : .loading }
        } else if failure != nil || (hasData && isStale) { self = .refreshFailed }
        else { self = hasData ? .ready : .loading }
    }

    public var requiresSetup: Bool { self == .codexMissing || self == .signInRequired }
    public var showsRefreshFailure: Bool { self == .refreshFailed || self == .retrying }
}

public struct PanelQuota: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let window: UsageWindow?

    public func remainingPercent(at date: Date) -> Int? {
        guard let window, !window.hasExpired(at: date) else { return nil }
        return window.remainingPercent
    }

    public func resetText(at date: Date) -> String {
        guard let reset = window?.resetsAt else { return "—" }
        let seconds = reset - date.timeIntervalSince1970
        guard seconds > 0 else { return "Awaiting refresh" }
        let total = max(1, Int(ceil(seconds / 60)))
        let days = total / 1440
        let hours = (total % 1440) / 60
        let minutes = total % 60
        if days > 0 { return "\(days) \(days == 1 ? "day" : "days") \(hours) h" }
        if hours > 0 { return "\(hours) h \(minutes) min" }
        return "\(minutes) min"
    }
}

public extension UsageSnapshot {
    /// Use the same account bucket as the menu bar, without mixing model-specific limits.
    var panelBucket: UsageBucket? { (entries.first { $0.id == "codex" } ?? entries.first)?.bucket }

    var panelQuotas: [PanelQuota] {
        let windows = panelBucket?.windows ?? []
        // Preserve accurate titles for accounts whose windows differ from the usual pair.
        if windows.contains(where: { ![300, 10080].contains($0.windowDurationMins ?? 0) }) {
            return windows.enumerated().map { index, window in
                PanelQuota(id: "window-\(index)", title: window.title + " limit", window: window)
            }
        }
        return Self.emptyPanelQuotas.map { quota in
            PanelQuota(id: quota.id, title: quota.title,
                       window: windows.first { $0.windowDurationMins == (quota.id == "5h" ? 300 : 10080) })
        }
    }

    static var emptyPanelQuotas: [PanelQuota] {
        [PanelQuota(id: "5h", title: "5-hour limit", window: nil),
         PanelQuota(id: "7d", title: "Weekly limit", window: nil)]
    }
}
