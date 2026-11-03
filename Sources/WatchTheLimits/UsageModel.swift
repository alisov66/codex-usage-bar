import AppKit
import Combine
import ServiceManagement
import UsageCore

enum PanelPreviewScenario: String, CaseIterable {
    case loading, ready, refreshFailed = "refresh-failed", refreshFailedEmpty = "refresh-failed-empty"
    case retrying, retryingEmpty = "retrying-empty", codexMissing = "codex-missing", signInRequired = "sign-in-required"
    case expired
}

@MainActor
final class UsageModel: ObservableObject {
    @Published var snapshot: UsageSnapshot?
    @Published var errorMessage: String?
    @Published var failure: PanelFailure?
    @Published var isRefreshing = false
    @Published var lastUpdated: Date?
    @Published var now = Date()
    @Published var showSettings = false
    @Published var menuBarDisplay = MenuBarDisplay(rawValue: UserDefaults.standard.string(forKey: "menuBarDisplay") ?? "") ?? .both
    @Published var customPath = UserDefaults.standard.string(forKey: "codexPath") ?? ""
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    var onChange: (() -> Void)?
    private let client = CodexClient()
    private var timer: Timer?
    private var refreshTask: Task<Void, Never>?
    private var lastAttempt: Date?
    let isDemo: Bool

    init(demo: Bool = false, preview: PanelPreviewScenario? = nil, expanded: Bool = false) {
        isDemo = demo || preview != nil
        showSettings = expanded
        if isDemo {
            configurePreview(preview ?? .ready)
        } else {
            timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
        }
    }

    var hasPanelData: Bool { snapshot?.panelBucket?.windows.isEmpty == false }

    var isStale: Bool {
        guard let lastUpdated else { return true }
        return failure != nil || now.timeIntervalSince(lastUpdated) > 150
    }

    var phase: PanelPhase {
        PanelPhase(hasData: hasPanelData, isRefreshing: isRefreshing, isStale: isStale, failure: failure)
    }

    var planTitle: String? { snapshot?.panelBucket?.planType?.capitalized }
    var quotas: [PanelQuota] { snapshot?.panelQuotas ?? UsageSnapshot.emptyPanelQuotas }

    var indicator: MenuBarIndicator {
        MenuBarIndicator(snapshot: snapshot, display: menuBarDisplay, isStale: isStale, now: now)
    }

    func setMenuBarDisplay(_ display: MenuBarDisplay) {
        menuBarDisplay = display
        if !isDemo { UserDefaults.standard.set(display.rawValue, forKey: "menuBarDisplay") }
        onChange?()
    }

    var executablePath: String? { CodexExecutable.locate(customPath: customPath) }

    var displayedExecutablePath: String {
        isDemo ? "/usr/local/bin/codex" : executablePath ?? (customPath.isEmpty ? "Not found" : customPath)
    }

    private func tick() {
        now = Date()
        onChange?()
        let elapsed = lastAttempt.map { now.timeIntervalSince($0) } ?? .infinity
        if elapsed >= 60 || (snapshot?.remainingPercent(at: now) == nil && elapsed >= 15) { refresh() }
    }

    func refresh() {
        guard !isRefreshing else { return }
        if isDemo {
            isRefreshing = true
            refreshTask = Task {
                try? await Task.sleep(nanoseconds: 800_000_000)
                guard !Task.isCancelled else { return }
                configurePreview(.ready)
                onChange?()
            }
            return
        }
        lastAttempt = Date()
        guard let path = executablePath else {
            failure = .codexMissing
            errorMessage = CodexError.missingExecutable.localizedDescription
            onChange?()
            return
        }
        // Retry setup as a fresh load, preserving ordinary failures until recovery.
        if failure == .codexMissing || failure == .signInRequired { failure = nil; errorMessage = nil }
        isRefreshing = true
        refreshTask = Task {
            defer { isRefreshing = false; onChange?() }
            do {
                let next = try await client.readLimits(executablePath: path)
                guard next.panelBucket?.windows.isEmpty == false else {
                    failure = .refresh
                    errorMessage = "Codex returned no usage limits for this account."
                    return
                }
                snapshot = next
                lastUpdated = Date()
                now = Date()
                failure = nil
                errorMessage = nil
            } catch {
                failure = PanelFailure(error: error)
                errorMessage = error.localizedDescription
            }
        }
    }

    func chooseExecutable() {
        let panel = NSOpenPanel()
        panel.title = "Locate Codex"
        panel.message = "Choose the codex executable installed by Homebrew, npm, or the Codex app."
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            customPath = url.path
            if !isDemo { UserDefaults.standard.set(customPath, forKey: "codexPath") }
            refresh()
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        if isDemo { launchAtLogin = enabled; return }
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            if enabled && !launchAtLogin { SMAppService.openSystemSettingsLoginItems() }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            let alert = NSAlert(error: error)
            alert.messageText = "Could not change launch at login"
            alert.runModal()
        }
    }

    func shutdown() async {
        timer?.invalidate()
        refreshTask?.cancel()
        await client.shutdown()
    }

    private func configurePreview(_ scenario: PanelPreviewScenario) {
        menuBarDisplay = .fiveHour
        launchAtLogin = true
        failure = nil
        errorMessage = nil
        isRefreshing = false
        snapshot = nil
        lastUpdated = nil
        now = Date()
        if [.ready, .refreshFailed, .retrying, .expired].contains(scenario) {
            let firstReset = now.addingTimeInterval(scenario == .expired ? -10 : 8460).timeIntervalSince1970
            let secondReset = now.addingTimeInterval(576000).timeIntervalSince1970
            snapshot = try! JSONDecoder().decode(UsageSnapshot.self, from: Data("""
            {"rateLimits":{"limitId":"codex","planType":"plus",
            "primary":{"usedPercent":50,"windowDurationMins":300,"resetsAt":\(firstReset)},
            "secondary":{"usedPercent":50,"windowDurationMins":10080,"resetsAt":\(secondReset)}}}
            """.utf8))
            lastUpdated = now
        }
        switch scenario {
        case .loading: isRefreshing = true
        case .refreshFailed, .refreshFailedEmpty: failure = .refresh
        case .retrying, .retryingEmpty: failure = .refresh; isRefreshing = true
        case .codexMissing: failure = .codexMissing
        case .signInRequired: failure = .signInRequired
        case .ready, .expired: break
        }
    }
}
