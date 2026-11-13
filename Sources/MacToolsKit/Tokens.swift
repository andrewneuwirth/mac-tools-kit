import SwiftUI
import AppKit

// Mirrors project/tokens.json in the "Mac Tools" design system
// (the design system). Change a value there first, then here.

public enum MT {
    public enum Space {
        public static let s4: CGFloat = 4, s6: CGFloat = 6, s8: CGFloat = 8, s10: CGFloat = 10
        public static let s12: CGFloat = 12, s18: CGFloat = 18, s26: CGFloat = 26
    }

    public enum Radius {
        public static let control: CGFloat = 8, row: CGFloat = 10, card: CGFloat = 14
        public static let panel: CGFloat = 18, section: CGFloat = 24
    }

    public enum Motion {
        public static let quick = Animation.easeInOut(duration: 0.15)
        public static let panel = Animation.spring(response: 0.3, dampingFraction: 0.85)
        public static let value = Animation.smooth(duration: 0.45)

        /// nil under Reduce Motion, so `.animation(MT.Motion.allowed(.quick), value:)` does nothing then.
        public static func allowed(_ animation: Animation) -> Animation? {
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : animation
        }
    }
}

public extension Color {
    // Neutrals
    static let mtGround = Color.dynamic(light: 0xf7f7f9, dark: 0x0e0f12)
    static let mtSurface = Color.dynamic(light: 0xffffff, dark: 0x1f2126)
    static let mtInk = Color.dynamic(light: 0x1f2328, dark: 0xdbdee3)
    static let mtInkMuted = Color.dynamic(light: 0x6b7280, dark: 0x8a9199)
    static let mtHairline = Color.dynamic(light: 0xe3e3e6, dark: 0x303236)
    static let mtFillInset = Color.dynamic(light: 0x000000, lightAlpha: 0.04, dark: 0xffffff, darkAlpha: 0.06)
    static let mtFillHover = Color.dynamic(light: 0x000000, lightAlpha: 0.07, dark: 0xffffff, darkAlpha: 0.10)
    static let mtRingTrack = Color.dynamic(light: 0x000000, lightAlpha: 0.12, dark: 0xffffff, darkAlpha: 0.14)

    // Status: always paired with a symbol or word.
    static let mtGood = Color.dynamic(light: 0x2f9e5b, dark: 0x66cc87)
    static let mtWarn = Color.dynamic(light: 0xb7791f, dark: 0xf2b545)
    static let mtBad = Color.dynamic(light: 0xd64541, dark: 0xe85754)

    // Partners: one definition, imported everywhere.
    static let mtClaude = Color(hex: 0xd97757)
    static let mtChatGPT = Color(hex: 0x10a37f)

    // App accents
    static let mtJot = Color(hex: 0x338cfa)
    static let mtProjects = Color(hex: 0x807ef2)
    static let mtHangar = Color(hex: 0xed8f5c)
    static let mtUsageRings = Color(hex: 0xb98fdd)
    static let mtTextViewer = Color.dynamic(light: 0x0550ae, dark: 0x79b8ff)
    static let mtLinkChoice = Color(hex: 0xfa5c5c)
    static let mtCommandCenter = Color(hex: 0x1fb6c9)
    static let mtVitals = Color(hex: 0x8bc34a)

    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double(hex >> 16 & 0xff) / 255, green: Double(hex >> 8 & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255, opacity: alpha)
    }

    static func dynamic(light: UInt32, lightAlpha: CGFloat = 1, dark: UInt32, darkAlpha: CGFloat = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light, alpha: isDark ? darkAlpha : lightAlpha)
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat) {
        self.init(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255,
                  blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
    }
}

/// The family's status language.
public enum MTStatus: Sendable {
    case good, warn, bad

    public var color: Color {
        switch self { case .good: .mtGood; case .warn: .mtWarn; case .bad: .mtBad }
    }

    /// Shared usage thresholds: 50% warns, 80% is bad, below that the caller's base colour.
    public static func forUsage(_ percent: Double) -> MTStatus? {
        percent >= 80 ? .bad : percent >= 50 ? .warn : nil
    }
}

public func usageTint(_ percent: Double, base: Color) -> Color {
    MTStatus.forUsage(percent)?.color ?? base
}
