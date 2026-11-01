import AppKit
import Combine
import ServiceManagement
import UsageCore

@MainActor
final class UsageModel: ObservableObject {
    @Published var snapshot: UsageSnapshot?
    @Published var errorMessage: String?
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

    init(demo: Bool = false) {
        isDemo = demo
        if demo {
            snapshot = .demo
            lastUpdated = Date()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    var isStale: Bool {
        guard let lastUpdated else { return true }
        return errorMessage != nil || now.timeIntervalSince(lastUpdated) > 150
    }

    var indicator: MenuBarIndicator {
        MenuBarIndicator(snapshot: snapshot, display: menuBarDisplay, isStale: isStale, now: now)
    }

    func setMenuBarDisplay(_ display: MenuBarDisplay) {
        menuBarDisplay = display
        UserDefaults.standard.set(display.rawValue, forKey: "menuBarDisplay")
        onChange?()
    }

    var executablePath: String? { CodexExecutable.locate(customPath: customPath) }

    private func tick() {
        now = Date()
        onChange?()
        let elapsed = lastAttempt.map { now.timeIntervalSince($0) } ?? .infinity
        if elapsed >= 60 || (snapshot?.remainingPercent(at: now) == nil && elapsed >= 15) { refresh() }
    }

    func refresh() {
        guard !isDemo, !isRefreshing else { return }
        lastAttempt = Date()
        guard let path = executablePath else {
            errorMessage = CodexError.missingExecutable.localizedDescription
            onChange?()
            return
        }
        isRefreshing = true
        refreshTask = Task {
            defer { isRefreshing = false; onChange?() }
            do {
                snapshot = try await client.readLimits(executablePath: path)
                lastUpdated = Date()
                now = Date()
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func chooseExecutable() {
        let panel = NSOpenPanel()
        panel.title = "Choose the Codex executable"
        panel.message = "Choose the codex executable installed by Homebrew, npm, or the Codex app."
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            customPath = url.path
            UserDefaults.standard.set(customPath, forKey: "codexPath")
            refresh()
        }
    }

    func useAutomaticLocation() {
        customPath = ""
        UserDefaults.standard.removeObject(forKey: "codexPath")
        refresh()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            if enabled && !launchAtLogin { SMAppService.openSystemSettingsLoginItems() }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            errorMessage = "Could not change launch at login: \(error.localizedDescription)"
        }
    }

    func shutdown() async {
        timer?.invalidate()
        refreshTask?.cancel()
        await client.shutdown()
    }
}
