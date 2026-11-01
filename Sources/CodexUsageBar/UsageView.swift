import AppKit
import SwiftUI
import UsageCore

struct UsageView: View {
    @ObservedObject var model: UsageModel
    private let accent = Color(red: 0.20, green: 0.69, blue: 0.49)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 36, height: 36)
                    .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Codex Usage Bar").font(.headline)
                    Text(model.isDemo ? "Preview · sample data" : "Your remaining quota")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.refresh() } label: {
                    if model.isRefreshing { ProgressView().controlSize(.small) }
                    else { Image(systemName: "arrow.clockwise") }
                }
                .buttonStyle(.borderless)
                .disabled(model.isRefreshing || model.isDemo)
                .help("Refresh usage")
                .accessibilityLabel("Refresh usage")
            }

            if let message = model.errorMessage {
                Label {
                    Text(message).font(.caption).textSelection(.enabled)
                } icon: { Image(systemName: "exclamationmark.circle") }
                .foregroundStyle(.orange)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
            }

            if let snapshot = model.snapshot, !snapshot.windows.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(snapshot.entries) { entry in
                        VStack(alignment: .leading, spacing: 13) {
                            HStack {
                                Text(entry.title).font(.subheadline.weight(.semibold))
                                Spacer()
                                if let plan = entry.bucket.planType {
                                    Text(plan.capitalized).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            ForEach(Array(entry.bucket.windows.enumerated()), id: \.offset) { _, window in
                                windowView(window)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                Text("Menu bar: \(model.menuBarDisplay.title.lowercased()), quota remaining.")
                    .font(.caption2).foregroundStyle(.secondary)
            } else if model.isRefreshing {
                HStack { Spacer(); ProgressView("Reading your usage…"); Spacer() }.padding(.vertical, 18)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connect your Codex account").font(.subheadline.weight(.semibold))
                    Text("Install Codex, then sign in with your ChatGPT account in Terminal:")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("codex login").font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    Button("Setup instructions") { openProject("#setup") }
                        .font(.caption)
                    if model.executablePath != nil {
                        Text("No quota windows yet? Confirm that Codex is signed in with ChatGPT and supports account usage limits.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 6)
            }

            Divider()
            HStack {
                if let date = model.lastUpdated {
                    Text("\(model.isStale ? "Last read" : "Updated") \(date.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("Refreshes every minute").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.showSettings.toggle() } label: { Image(systemName: "gearshape") }
                    .buttonStyle(.borderless).help("Settings").accessibilityLabel("Settings")
                Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
                    .buttonStyle(.borderless).help("Quit Codex Usage Bar").accessibilityLabel("Quit Codex Usage Bar")
            }
            if model.showSettings {
                settings
            }
        }
        .padding(20)
        .frame(width: 350)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private func windowView(_ window: UsageWindow) -> some View {
        let expired = window.hasExpired(at: model.now)
        let color: Color = window.remainingPercent <= 10 ? .red : window.remainingPercent <= 25 ? .orange : accent
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.title).font(.subheadline)
                Spacer()
                Text(expired ? "Awaiting refresh" : "\(window.remainingPercent)% left")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(expired ? Color.secondary : color)
            }
            ProgressView(value: Double(window.remainingPercent), total: 100)
                .tint(color).opacity(model.isStale ? 0.45 : 1)
                .accessibilityLabel("\(window.title) remaining quota")
                .accessibilityValue(expired ? "Awaiting refresh" : "\(window.remainingPercent) percent")
            if let reset = window.resetsAt {
                HStack(spacing: 3) {
                    Text(expired ? "Reset time passed · refreshing" : "Resets")
                    if !expired { Text(Date(timeIntervalSince1970: reset), style: .relative) }
                }
                .font(.caption2).foregroundStyle(.secondary)
                .help(Date(timeIntervalSince1970: reset).formatted(date: .complete, time: .shortened))
            }
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Menu bar display", selection: Binding(get: { model.menuBarDisplay }, set: { model.setMenuBarDisplay($0) })) {
                ForEach(MenuBarDisplay.allCases) { display in
                    Text(display.title).tag(display)
                }
            }
            .pickerStyle(.menu)
            .controlSize(.small)
            Toggle("Launch at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                .toggleStyle(.switch).controlSize(.small)
            VStack(alignment: .leading, spacing: 6) {
                Text("Codex location").font(.caption.weight(.medium))
                Text(model.executablePath ?? "Not found")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(2).textSelection(.enabled)
                HStack {
                    Button("Choose…") { model.chooseExecutable() }
                    if !model.customPath.isEmpty { Button("Automatic") { model.useAutomaticLocation() } }
                }.controlSize(.small)
            }
            Button("View on GitHub") { openProject("") }.font(.caption)
        }
    }

    private func openProject(_ fragment: String) {
        NSWorkspace.shared.open(URL(string: "https://github.com/alisov66/codex-usage-bar\(fragment)")!)
    }
}
