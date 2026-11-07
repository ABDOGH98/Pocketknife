import AppKit
import SwiftUI

// MARK: - Theme

/// The colors of the current palette, read live from `AppSettings`.
///
/// Views read these in `body`, so SwiftUI redraws them when the user picks another theme in Settings.
/// Accent names (`mint`, `amber`…) are roles named after the default Slate palette; other palettes
/// fill each role with their own hue.
enum Theme {
    static var palette: Palette { AppSettings.shared.palette }

    // Surfaces
    static var canvas: Color { palette.canvas }
    static var rail: Color { palette.rail }
    static var surface: Color { palette.surface }
    static var raised: Color { palette.raised }
    static var sunken: Color { palette.sunken }
    static let stroke = Color(light: 0x000000, dark: 0xFFFFFF, alpha: 0.08)
    static let strokeStrong = Color(light: 0x000000, dark: 0xFFFFFF, alpha: 0.16)

    // Text
    static var text: Color { palette.text }
    static var textSecondary: Color { palette.textSecondary }
    static var textTertiary: Color { palette.textTertiary }

    // Accent roles
    /// Commands, success.
    static var mint: Color { palette.mint }
    /// Passwords, warnings.
    static var amber: Color { palette.amber }
    /// Utilities.
    static var lavender: Color { palette.lavender }
    /// Home, Settings, information.
    static var sky: Color { palette.sky }
    /// Errors, deleting.
    static var coral: Color { palette.coral }
    /// Favorites.
    static var gold: Color { palette.gold }
    /// Text and icons drawn on top of a filled accent.
    static var onAccent: Color { palette.onAccent }

    static var success: Color { mint }
    static var warning: Color { amber }
    static var danger: Color { coral }

    /// Soft accents used to tell tags and logins apart at a glance.
    static var swatches: [Color] { [mint, sky, lavender, amber, coral, gold] }

    /// The same name always gets the same swatch.
    static func swatch(for name: String) -> Color {
        let sum = name.lowercased().unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        let swatches = swatches
        return swatches[sum % swatches.count]
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 18
    }

    /// `animation`, or nil when animations are off in Settings or the user asked macOS to reduce motion.
    @MainActor
    static func motion(_ animation: Animation) -> Animation? {
        guard AppSettings.shared.animationsEnabled,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return nil }
        return animation
    }
}

extension Animation {
    /// Hover, selection and other small state changes.
    static let ui = Animation.snappy(duration: 0.22)
    /// Things that should feel lively: copy confirmations, cards appearing.
    static let lively = Animation.spring(response: 0.38, dampingFraction: 0.72)
}

extension EnvironmentValues {
    /// The accent of the section a view lives in; buttons and highlights pick it up.
    @Entry var sectionAccent: Color = Theme.mint
}

// MARK: - Palettes

/// A complete set of colors for light and dark mode.
///
/// Every palette follows the same rules so it stays easy on the eyes: no pure black or white,
/// small steps between surfaces, and accents that are softer in dark mode and deeper in light mode
/// (so white text on a filled button stays readable).
struct Palette: Identifiable, Hashable, Sendable {
    let id: String
    let name: LocalizedStringResource
    let summary: LocalizedStringResource

    let canvas: Color
    let rail: Color
    let surface: Color
    let raised: Color
    let sunken: Color
    let text: Color
    let textSecondary: Color
    let textTertiary: Color
    let mint: Color
    let amber: Color
    let lavender: Color
    let sky: Color
    let coral: Color
    let gold: Color
    let onAccent: Color

    static func == (lhs: Palette, rhs: Palette) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static let all: [Palette] = [.slate, .forest, .ocean, .dusk, .paper, .graphite]

    static func named(_ id: String) -> Palette {
        all.first { $0.id == id } ?? .slate
    }

    /// The default: navy-slate from the app icon with mint, amber and lavender.
    static let slate = Palette(
        id: "slate", name: "Slate", summary: "Navy calm, the default",
        canvas: .init(light: 0xF3F2EE, dark: 0x12171D),
        rail: .init(light: 0xE9E7E1, dark: 0x0D1217),
        surface: .init(light: 0xFBFAF7, dark: 0x191F26),
        raised: .init(light: 0xFFFFFF, dark: 0x212831),
        sunken: .init(light: 0xEEECE6, dark: 0x0F1419),
        text: .init(light: 0x1E242B, dark: 0xE4E7EB),
        textSecondary: .init(light: 0x59626D, dark: 0x9CA6B2),
        textTertiary: .init(light: 0x89919B, dark: 0x6B7581),
        mint: .init(light: 0x1C8577, dark: 0x5FCDB9),
        amber: .init(light: 0xB4650F, dark: 0xF2A950),
        lavender: .init(light: 0x6754C4, dark: 0xB0A1F6),
        sky: .init(light: 0x2F6FB8, dark: 0x7FB2EE),
        coral: .init(light: 0xC4473F, dark: 0xF08A80),
        gold: .init(light: 0xB98510, dark: 0xF2C55C),
        onAccent: .init(light: 0xFFFFFF, dark: 0x0D1217)
    )

    /// Deep green with sage and peach: restful, like a park bench.
    static let forest = Palette(
        id: "forest", name: "Forest", summary: "Sage greens, very restful",
        canvas: .init(light: 0xF1F3EE, dark: 0x111713),
        rail: .init(light: 0xE6E9E1, dark: 0x0C110E),
        surface: .init(light: 0xFAFBF7, dark: 0x18201B),
        raised: .init(light: 0xFFFFFF, dark: 0x1F2923),
        sunken: .init(light: 0xEBEEE6, dark: 0x0D120F),
        text: .init(light: 0x1C2420, dark: 0xE2E8E3),
        textSecondary: .init(light: 0x56635B, dark: 0x98A89E),
        textTertiary: .init(light: 0x86928A, dark: 0x66766C),
        mint: .init(light: 0x2E7D4F, dark: 0x7ACB94),
        amber: .init(light: 0xA8621A, dark: 0xE8B068),
        lavender: .init(light: 0x6A5BB0, dark: 0xB3A6EE),
        sky: .init(light: 0x2C6E8F, dark: 0x84C0DD),
        coral: .init(light: 0xB5483F, dark: 0xEE8E84),
        gold: .init(light: 0xA88412, dark: 0xE9C76A),
        onAccent: .init(light: 0xFFFFFF, dark: 0x0C110E)
    )

    /// Deep sea blue with aqua and coral.
    static let ocean = Palette(
        id: "ocean", name: "Ocean", summary: "Deep blue with aqua",
        canvas: .init(light: 0xEEF3F6, dark: 0x0E1520),
        rail: .init(light: 0xE2E9EE, dark: 0x0A101A),
        surface: .init(light: 0xF8FAFC, dark: 0x151E2B),
        raised: .init(light: 0xFFFFFF, dark: 0x1C2737),
        sunken: .init(light: 0xE7EDF1, dark: 0x0B111A),
        text: .init(light: 0x1A2330, dark: 0xE1E8F0),
        textSecondary: .init(light: 0x546273, dark: 0x96A5B8),
        textTertiary: .init(light: 0x8593A3, dark: 0x64748A),
        mint: .init(light: 0x1A7F96, dark: 0x5EC4DC),
        amber: .init(light: 0xB0602A, dark: 0xF0A672),
        lavender: .init(light: 0x5B5FC7, dark: 0xA3A7F5),
        sky: .init(light: 0x2867B8, dark: 0x7DAAF0),
        coral: .init(light: 0xC0444E, dark: 0xF2878F),
        gold: .init(light: 0xB08414, dark: 0xEFC660),
        onAccent: .init(light: 0xFFFFFF, dark: 0x0A101A)
    )

    /// Soft plum evening tones with violet and rose.
    static let dusk = Palette(
        id: "dusk", name: "Dusk", summary: "Plum evening, violet and rose",
        canvas: .init(light: 0xF4F1F5, dark: 0x15121A),
        rail: .init(light: 0xE9E5EC, dark: 0x100D14),
        surface: .init(light: 0xFBF9FC, dark: 0x1D1923),
        raised: .init(light: 0xFFFFFF, dark: 0x25202D),
        sunken: .init(light: 0xEEEAF0, dark: 0x110E15),
        text: .init(light: 0x241F2A, dark: 0xE7E2EC),
        textSecondary: .init(light: 0x625A6B, dark: 0xA79FB2),
        textTertiary: .init(light: 0x938B9C, dark: 0x776F82),
        mint: .init(light: 0x7A4FB5, dark: 0xC4A3F2),
        amber: .init(light: 0xB3602F, dark: 0xF2A877),
        lavender: .init(light: 0xB0457A, dark: 0xF09BC4),
        sky: .init(light: 0x3E6AB8, dark: 0x8DB2F2),
        coral: .init(light: 0xC2454B, dark: 0xF28A8E),
        gold: .init(light: 0xA8820F, dark: 0xF0CB6A),
        onAccent: .init(light: 0xFFFFFF, dark: 0x100D14)
    )

    /// Warm paper with low blue light, gentle for night work and long reading.
    static let paper = Palette(
        id: "paper", name: "Paper", summary: "Warm sepia, low blue light",
        canvas: .init(light: 0xF5EFE4, dark: 0x1A1612),
        rail: .init(light: 0xECE4D6, dark: 0x14110E),
        surface: .init(light: 0xFBF7EF, dark: 0x221D18),
        raised: .init(light: 0xFFFDF8, dark: 0x2A241E),
        sunken: .init(light: 0xEFE7DA, dark: 0x15120F),
        text: .init(light: 0x2E261E, dark: 0xECE3D6),
        textSecondary: .init(light: 0x6B5D4E, dark: 0xB2A391),
        textTertiary: .init(light: 0x9A8B79, dark: 0x7F715F),
        mint: .init(light: 0x3F7F6A, dark: 0x8FC7AE),
        amber: .init(light: 0xA85E1E, dark: 0xE9AE6E),
        lavender: .init(light: 0x7B5C9E, dark: 0xC1A8DE),
        sky: .init(light: 0x3F6E8F, dark: 0x92BAD3),
        coral: .init(light: 0xB44A3A, dark: 0xEC8F7E),
        gold: .init(light: 0xA07C14, dark: 0xE3C072),
        onAccent: .init(light: 0xFFFDF8, dark: 0x14110E)
    )

    /// Neutral grays with a blue lead accent, for a minimal look.
    static let graphite = Palette(
        id: "graphite", name: "Graphite", summary: "Neutral grays, minimal",
        canvas: .init(light: 0xF2F2F3, dark: 0x141516),
        rail: .init(light: 0xE8E8EA, dark: 0x0F1011),
        surface: .init(light: 0xFAFAFA, dark: 0x1B1C1E),
        raised: .init(light: 0xFFFFFF, dark: 0x232427),
        sunken: .init(light: 0xECECEE, dark: 0x101112),
        text: .init(light: 0x1F2023, dark: 0xE4E4E6),
        textSecondary: .init(light: 0x5C5E63, dark: 0xA0A2A8),
        textTertiary: .init(light: 0x8C8E93, dark: 0x6E7076),
        mint: .init(light: 0x2F6FB8, dark: 0x7FB2EE),
        amber: .init(light: 0xB4650F, dark: 0xF2A950),
        lavender: .init(light: 0x6754C4, dark: 0xB0A1F6),
        sky: .init(light: 0x1C8577, dark: 0x5FCDB9),
        coral: .init(light: 0xC4473F, dark: 0xF08A80),
        gold: .init(light: 0xB98510, dark: 0xF2C55C),
        onAccent: .init(light: 0xFFFFFF, dark: 0x0F1011)
    )
}

// MARK: - Settings

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

/// User preferences that change how the whole app looks, saved in UserDefaults.
@Observable
final class AppSettings: @unchecked Sendable {
    static let shared = AppSettings()

    @ObservationIgnored private let defaults = UserDefaults.standard

    var paletteID: String {
        didSet { defaults.set(paletteID, forKey: "themePalette") }
    }

    var appearance: AppearanceMode {
        didSet {
            defaults.set(appearance.rawValue, forKey: "themeAppearance")
            MainActor.assumeIsolated { applyAppearance() }
        }
    }

    var animationsEnabled: Bool {
        didSet { defaults.set(animationsEnabled, forKey: "animationsEnabled") }
    }

    var palette: Palette { Palette.named(paletteID) }

    private init() {
        paletteID = defaults.string(forKey: "themePalette") ?? Palette.slate.id
        appearance = defaults.string(forKey: "themeAppearance").flatMap(AppearanceMode.init) ?? .system
        animationsEnabled = defaults.object(forKey: "animationsEnabled") as? Bool ?? true
    }

    /// Forces light or dark for every window, or follows macOS.
    @MainActor
    func applyAppearance() {
        NSApp?.appearance = appearance.nsAppearance
    }
}

// MARK: - Sections

enum AppSection: Hashable, CaseIterable {
    case commands, passwords, utils, settings

    /// The sections listed in the middle of the rail and on Home.
    static let tools: [AppSection] = [.commands, .passwords, .utils]

    var title: String {
        switch self {
        case .commands: String(localized: "Commands")
        case .passwords: String(localized: "Passwords")
        case .utils: String(localized: "Utilities")
        case .settings: String(localized: "Settings")
        }
    }

    var subtitle: String {
        switch self {
        case .commands: String(localized: "Fill in and copy the shell commands you can never quite remember.")
        case .passwords: String(localized: "Logins at hand, with passwords kept safely in your Keychain.")
        case .utils: String(localized: "Format JSON and XML, encode Base64 and decode JWTs.")
        case .settings: String(localized: "Theme, language and information about the app.")
        }
    }

    var systemImage: String {
        switch self {
        case .commands: "terminal.fill"
        case .passwords: "key.fill"
        case .utils: "wrench.and.screwdriver.fill"
        case .settings: "gearshape.fill"
        }
    }

    var accent: Color {
        switch self {
        case .commands: Theme.mint
        case .passwords: Theme.amber
        case .utils: Theme.lavender
        case .settings: Theme.sky
        }
    }

    var shortcut: Character {
        switch self {
        case .commands: "1"
        case .passwords: "2"
        case .utils: "3"
        case .settings: ","
        }
    }
}

// MARK: - Helpers

extension Color {
    /// A color that follows the window's light or dark appearance.
    init(light: UInt32, dark: UInt32, alpha: CGFloat = 1) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light, alpha: alpha)
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
