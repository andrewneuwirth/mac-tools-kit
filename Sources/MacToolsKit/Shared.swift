import Foundation
import ServiceManagement

/// The Claude and ChatGPT usage reading in ~/Library/Application Support/UsageRings/usage.json.
/// Pier writes it (Sources/Pier/Usage, moved from the retired Usage Rings app); the path keeps its old name.
public struct UsageSnapshot: Codable, Equatable, Sendable {
    public struct Window: Codable, Equatable, Sendable {
        public var percent: Double
        public var resetsAt: Date?
        public init(percent: Double, resetsAt: Date?) { self.percent = percent; self.resetsAt = resetsAt }
    }

    public struct Reading: Codable, Equatable, Sendable {
        public var short: Window?
        public var long: Window?
        public var note: String?
        public var failed = false
        public var stale = false

        public init(short: Window?, long: Window?, note: String?, failed: Bool, stale: Bool) {
            self.short = short; self.long = long; self.note = note; self.failed = failed; self.stale = stale
        }

        /// The window that bites first, the one a ring's centre number reports.
        public var primary: Window? { short ?? long }
        public var secondary: Window? { short == nil ? nil : long }
    }

    public var claude: Reading?
    public var chatgpt: Reading?
    public var updated: Date

    public init(claude: Reading?, chatgpt: Reading?, updated: Date) {
        self.claude = claude; self.chatgpt = chatgpt; self.updated = updated
    }

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

    /// Writes the snapshot unless only `updated` changed. True when the stored readings changed.
    @discardableResult
    public func write(to url: URL = file) -> Bool {
        var old = Self.read(from: url)
        old?.updated = updated
        guard old != self else { return false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? encoder.encode(self).write(to: url, options: .atomic)
        return true
    }
}

/// One project's site or local server, as Pier's Projects tile and search and the Projects app
/// both list it. The single list lives in ~/Library/Application Support/Projects/projects.json.
public struct ProjectLink: Codable, Equatable, Identifiable, Sendable {
    public var title: String
    public var url: String
    /// The project folder under ~/Developer, e.g. "Creative/reelforge".
    public var path: String?
    /// For a server on this Mac: the shell command that starts it, run in that folder.
    public var start: String?
    public var id: String { url }

    public init(title: String, url: String, path: String? = nil, start: String? = nil) {
        self.title = title; self.url = url; self.path = path; self.start = start
    }
}

public enum ProjectLinks {
    public static var file: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Projects/projects.json")
    }

    /// nil when the file is missing or doesn't parse (a typo mid-edit): callers keep what they had.
    public static func load(from url: URL = file) -> [ProjectLink]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([ProjectLink].self, from: data)
    }

    public static func save(_ links: [ProjectLink], to url: URL = file) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? encoder.encode(links).write(to: url, options: .atomic)
    }
}

/// The "Open at Login" toggle every tool shows.
public enum LoginItem {
    public static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// false when macOS refused (callers may beep, as Usage Rings does).
    @discardableResult
    public static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return true
        } catch {
            NSLog("Open at Login: \(error.localizedDescription)")
            return false
        }
    }
}
