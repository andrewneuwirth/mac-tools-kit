import Foundation
import ServiceManagement

/// What Usage Rings writes to ~/Library/Application Support/UsageRings/usage.json.
/// Same shape as UsageRings' SharedSnapshot (Shared/SharedUsage.swift); that file is the writer.
public struct UsageSnapshot: Codable, Equatable, Sendable {
    public struct Window: Codable, Equatable, Sendable {
        public var percent: Double
        public var resetsAt: Date?
    }

    public struct Reading: Codable, Equatable, Sendable {
        public var short: Window?
        public var long: Window?
        public var note: String?
        public var failed = false
        public var stale = false

        /// The window that bites first, the one a ring's centre number reports.
        public var primary: Window? { short ?? long }
        public var secondary: Window? { short == nil ? nil : long }
    }

    public var claude: Reading?
    public var chatgpt: Reading?
    public var updated: Date

    public static var file: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/UsageRings/usage.json")
    }

    /// nil when Usage Rings has never run or the file is unreadable.
    public static func read(from url: URL = file) -> UsageSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(UsageSnapshot.self, from: data)
    }
}

/// The "Open at Login" toggle every tool shows.
public enum LoginItem {
    public static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    public static func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Open at Login: \(error.localizedDescription)")
        }
    }
}
