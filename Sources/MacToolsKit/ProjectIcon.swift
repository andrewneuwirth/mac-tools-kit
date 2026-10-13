import AppKit

/// A project's real icon: the app it launches, a built .app in the folder, else the icon its sources
/// ship (Xcode icon set whose target matches, the site's own icon, .icns, Android launcher icon).
/// Shared by Projects and Pier. Slow-ish (walks the folder): call it off the main thread.
public enum ProjectIcon {
    public struct Found: Sendable {
        public let image: NSImage
        public let isMacIcon: Bool   // Mac icons come shaped; others need the rounded mask
    }

    /// Folders whose icons belong to something else: tests, fixtures, saved brand data, samples.
    static let junk: Set<String> = ["test", "tests", "fixtures", "__fixtures__", "data", "examples", "example",
                                               "samples", "sample", "mock", "mocks", "demo", "docs", "snapshots"]

    public static func find(root: URL, app: String?) -> Found? {
        let fm = FileManager.default
        if let app, !app.isEmpty {
            let url = app.hasPrefix("/") ? URL(fileURLWithPath: app) : root.appendingPathComponent(app)
            if fm.fileExists(atPath: url.path) { return Found(image: macIcon(url.path), isMacIcon: true) }
        }
        // A Mac app built right in the project (Projects' own build/, a checked-in .app) is the truest icon.
        for folder in [root, root.appendingPathComponent("build")] {
            let apps = ((try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []).filter { $0.pathExtension == "app" }
            if let built = apps.first(where: { normalized($0.deletingPathExtension().lastPathComponent) == normalized(root.lastPathComponent) }) ?? apps.first {
                return Found(image: macIcon(built.path), isMacIcon: true)
            }
        }
        // Folders that are big and never hold the source icon.
        let skip: Set<String> = ["node_modules", ".build", "build", "DerivedData", "Pods", ".next", "dist", "vendor",
                                 ".git", ".gradle", "Carthage", ".swiftpm", "out", "coverage", "archived"]
        guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey],
                                         options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return nil }
        var candidates: [(rank: Int, depth: Int, url: URL, mac: Bool)] = []
        let project = normalized(root.lastPathComponent)
        for case let url as URL in walker {
            let name = url.lastPathComponent
            if walker.level > 6 || skip.contains(name) || junk.contains(name.lowercased()) { walker.skipDescendants(); continue }
            let parent = url.deletingLastPathComponent().lastPathComponent.lowercased()
            let rank: Int?
            if name == "AppIcon.appiconset" {
                walker.skipDescendants()
                // Xcode target folders sit above the asset catalog; a match means it's this project's own app.
                let owners = url.pathComponents.dropLast(2).suffix(2).map(normalized)
                rank = owners.contains { $0 == project || $0.contains(project) || project.contains($0) } ? 1 : 6
            } else if ["icon.png", "apple-icon.png"].contains(name) && parent == "app" {
                rank = 2   // Next.js app-directory icon: the site's own
            } else if ["apple-touch-icon.png", "icon.png", "icon-512.png"].contains(name) && ["public", "static"].contains(parent) {
                rank = 3
            } else if url.pathExtension == "icns" {
                rank = 4
            } else if name.hasPrefix("ic_launcher") && url.path.contains("mipmap-xxxhdpi") && ["png", "webp"].contains(url.pathExtension) {
                rank = 5
            } else if name == "favicon.png" && ["public", "static"].contains(parent) {
                rank = 7   // a favicon nested in a sub-app's folder isn't the project's
            } else {
                rank = nil
            }
            if let rank { candidates.append((rank, walker.level, url, url.pathExtension == "icns")) }
        }
        for c in candidates.sorted(by: { ($0.rank, $0.depth) < ($1.rank, $1.depth) }) {
            let file = c.url.lastPathComponent == "AppIcon.appiconset" ? largestImage(in: c.url) : c.url
            if let file, let found = image(file, mac: c.mac) { return found }
        }
        return nil
    }

    /// NSWorkspace hands icons back sized 32pt, which SwiftUI then stretches; ask for the full size.
    private static func macIcon(_ path: String) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 512, height: 512)
        return icon
    }

    private static func normalized(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func largestImage(in folder: URL) -> URL? {
        let pngs = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return pngs.filter { $0.pathExtension == "png" }
            .max { ((try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) < ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    private static func image(_ url: URL, mac: Bool) -> Found? {
        NSImage(contentsOf: url).map { Found(image: $0, isMacIcon: mac) }
    }
}
