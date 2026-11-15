import AppKit
import SwiftUI
import Sparkle

/// Sparkle's standard updater, shared by every newi tools app that ships updates (docs/updates.md).
/// The feed and key come from Info.plist (SUFeedURL, SUPublicEDKey). Without them, as in a bare
/// `swift run`, nothing starts and the controls stay disabled. Call `AppUpdater.start()` at launch.
@MainActor
public final class AppUpdater: ObservableObject {
    public static let shared = AppUpdater()

    public let controller: SPUStandardUpdaterController
    public var updater: SPUUpdater { controller.updater }
    /// False while a check is running, and always when the bundle has no feed or key.
    @Published public private(set) var canCheck = false
    @Published public private(set) var lastChecked: Date?
    private var observations: [NSKeyValueObservation] = []

    /// True when Info.plist has both SUFeedURL and SUPublicEDKey.
    public static var isConfigured: Bool {
        let info = Bundle.main.infoDictionary ?? [:]
        return info["SUFeedURL"] != nil && info["SUPublicEDKey"] != nil
    }

    private init() {
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        guard Self.isConfigured else { return }
        controller.startUpdater()
        observations = [
            updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
                let value = updater.canCheckForUpdates
                Task { @MainActor in self?.canCheck = value }
            },
            updater.observe(\.lastUpdateCheckDate, options: [.initial, .new]) { [weak self] updater, _ in
                let value = updater.lastUpdateCheckDate
                Task { @MainActor in self?.lastChecked = value }
            },
        ]
    }

    /// Starts the scheduled checks (daily, SUScheduledCheckInterval). Safe to call more than once.
    public static func start() { _ = shared }

    public var automaticallyChecks: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { objectWillChange.send(); updater.automaticallyChecksForUpdates = newValue }
    }

    public var automaticallyDownloads: Bool {
        get { updater.automaticallyDownloadsUpdates }
        set { objectWillChange.send(); updater.automaticallyDownloadsUpdates = newValue }
    }

    /// Shows Sparkle's window: up to date, or the new version's notes with Install.
    public func checkNow() { controller.checkForUpdates(nil) }

    /// "Check for Updates…" for an AppKit menu; Sparkle enables it only when a check can start.
    public func menuItem(title: String = "Check for Updates…") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        item.target = controller
        return item
    }

    public var lastCheckedText: String {
        guard let lastChecked else { return "Not checked yet" }
        if Date().timeIntervalSince(lastChecked) < 60 { return "Last checked just now" }
        return "Last checked " + lastChecked.formatted(.relative(presentation: .named))
    }
}

/// "Check for Updates…" for SwiftUI menus, e.g. `CommandGroup(after: .appInfo) { CheckForUpdatesButton() }`.
public struct CheckForUpdatesButton: View {
    @ObservedObject private var updates = AppUpdater.shared
    public init() {}
    public var body: some View {
        Button("Check for Updates…") { updates.checkNow() }.disabled(!updates.canCheck)
    }
}

/// The Updates section for a grouped `Form`: the two automatic switches, when it last checked, and Check Now.
public struct AppUpdateSettings: View {
    @ObservedObject private var updates = AppUpdater.shared
    public init() {}
    public var body: some View {
        Section("Updates") {
            Toggle("Check for updates automatically", isOn: $updates.automaticallyChecks)
            Toggle("Download and install automatically", isOn: $updates.automaticallyDownloads)
                .disabled(!updates.automaticallyChecks)
            LabeledContent {
                Button("Check Now") { updates.checkNow() }.disabled(!updates.canCheck)
            } label: {
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")")
                Text(updates.lastCheckedText)
            }
        }
    }
}
