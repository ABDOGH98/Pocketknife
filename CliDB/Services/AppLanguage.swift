import AppKit

/// Picks the language Pocketknife shows, independently of the Mac's language.
///
/// It writes the app's own `AppleLanguages` preference: the same setting that
/// System Settings › General › Language & Region › Applications uses, so both stay in sync.
@MainActor
enum AppLanguage {
    /// Every language the app is translated into, as String Catalog codes.
    static let supported = [
        "en", "ar", "de", "es", "fr", "hi", "id", "it", "ja", "ko",
        "nl", "pl", "pt-BR", "ru", "sv", "th", "tr", "vi", "zh-Hans", "zh-Hant",
    ]

    private static let key = "AppleLanguages"

    /// The language chosen for Pocketknife only, or nil when it follows the Mac.
    static var chosen: String? {
        let domain = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") ?? [:]
        guard let preferred = domain[key] as? [String], !preferred.isEmpty else { return nil }
        return Bundle.preferredLocalizations(from: supported, forPreferences: preferred).first
    }

    /// The language Pocketknife uses when it follows the Mac.
    static var macLanguage: String {
        let global = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?[key] as? [String]
        return Bundle.preferredLocalizations(from: supported, forPreferences: global ?? ["en"]).first ?? "en"
    }

    /// The language the app is showing right now.
    static var current: String {
        Bundle.main.preferredLocalizations.first ?? "en"
    }

    /// Saves the choice (nil follows the Mac). It takes effect the next time the app starts.
    static func choose(_ code: String?) {
        if let code {
            UserDefaults.standard.set([code], forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// The language the app will show after a restart.
    static var effective: String { chosen ?? macLanguage }

    /// A language's name written in that language, like "Deutsch" or "日本語", so people
    /// can find their own language whatever the app is currently showing.
    static func nativeName(_ code: String) -> String {
        let locale = Locale(identifier: code)
        let name = locale.localizedString(forIdentifier: code) ?? code
        return name.prefix(1).uppercased(with: locale) + name.dropFirst()
    }

    /// Opens a fresh copy of the app, then quits this one.
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }
    }
}
