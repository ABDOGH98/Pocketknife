import AppKit
import SwiftUI

enum AppInfo {
    static let repositoryURL = URL(string: "https://github.com/ABDOGH98/Pocketknife")!
    static let issuesURL = URL(string: "https://github.com/ABDOGH98/Pocketknife/issues")!

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}

/// A language the app is translated into. `code == nil` follows the macOS language.
struct AppLanguage: Identifiable, Hashable {
    let code: String?
    /// The name in its own language, so people can find theirs whatever the app is set to.
    let nativeName: String

    var id: String { code ?? "system" }

    static let all: [AppLanguage] = [
        AppLanguage(code: nil, nativeName: String(localized: "System")),
        AppLanguage(code: "en", nativeName: "English"),
        AppLanguage(code: "fr", nativeName: "Français"),
        AppLanguage(code: "es", nativeName: "Español"),
        AppLanguage(code: "ar", nativeName: "العربية"),
    ]

    /// The name in the current app language, shown under the native name.
    var localizedName: String {
        guard let code else { return String(localized: "Same as macOS") }
        return Locale.current.localizedString(forLanguageCode: code) ?? code
    }
}

/// Overrides the app's language through the `AppleLanguages` default, which macOS reads at launch.
enum LanguageSettings {
    /// The override saved for this app, or nil when it follows macOS.
    static var saved: String? {
        guard let domain = Bundle.main.bundleIdentifier.flatMap(UserDefaults.standard.persistentDomain(forName:)) else { return nil }
        return (domain["AppleLanguages"] as? [String])?.first
    }

    /// The override in effect when the app started; differs from `saved` until the app restarts.
    static let atLaunch: String? = saved

    static func save(_ code: String?) {
        if let code {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }

    /// Opens a fresh copy of the app, then quits this one.
    @MainActor
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }
    }
}

struct SettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var languageCode = LanguageSettings.saved

    @Environment(\.sectionAccent) private var accent

    private var needsRestart: Bool { languageCode != LanguageSettings.atLaunch }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Settings")
                        .font(.system(size: 22, weight: .bold))
                    Text("Make Pocketknife look and speak the way you like.")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                .appearAnimation()

                appearanceCard
                    .appearAnimation(index: 1)
                languageCard
                    .appearAnimation(index: 2)
                aboutCard
                    .appearAnimation(index: 3)
            }
            .padding(.horizontal, 28)
            .padding(.top, 10)
            .padding(.bottom, 28)
            .frame(maxWidth: 860, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Settings")
    }

    // MARK: - Appearance

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(title: String(localized: "Appearance"), systemImage: "paintpalette.fill")

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    FieldLabel(String(localized: "Mode"))
                    Text("Follow macOS, or always use light or dark.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                PillPicker(
                    options: AppearanceMode.allCases,
                    selection: $settings.appearance,
                    title: \.title,
                    systemImage: { $0.systemImage }
                )
                .fixedSize()
            }

            Rectangle().fill(Theme.stroke).frame(height: 1)

            VStack(alignment: .leading, spacing: 10) {
                FieldLabel(String(localized: "Theme"))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
                    ForEach(Palette.all) { palette in
                        PaletteCard(palette: palette, isSelected: palette.id == settings.paletteID) {
                            withAnimation(Theme.motion(.easeInOut(duration: 0.35))) {
                                settings.paletteID = palette.id
                            }
                        }
                    }
                }
            }

            Rectangle().fill(Theme.stroke).frame(height: 1)

            Toggle(isOn: $settings.animationsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Animations")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Slides, bounces and glowing backgrounds. Always off when Reduce Motion is on in System Settings.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .toggleStyle(.switch)
        }
        .card()
    }

    // MARK: - Language

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: String(localized: "Language"), systemImage: "globe")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(AppLanguage.all) { language in
                    LanguageOption(language: language, isSelected: language.code == languageCode) {
                        withAnimation(Theme.motion(.lively)) { languageCode = language.code }
                        LanguageSettings.save(language.code)
                    }
                }
            }

            if needsRestart {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(accent)
                        .symbolEffect(.pulse)
                    Text("Restart Pocketknife to use the new language.")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Button {
                        LanguageSettings.relaunch()
                    } label: {
                        Label("Restart Now", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(PillButtonStyle(kind: .primary))
                }
                .padding(12)
                .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(accent.opacity(0.3)))
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .card()
    }

    // MARK: - About

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: String(localized: "About"), systemImage: "info.circle.fill")

            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: "Pocketknife")
                        .font(.system(size: 18, weight: .bold))
                    Text("Version \(AppInfo.version)")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                    Text("Free and open source. Everything stays on your Mac.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
            }

            FlowLayout(spacing: 10) {
                Link(destination: AppInfo.repositoryURL) {
                    Label("View on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .buttonStyle(PillButtonStyle(kind: .primary))
                .help(AppInfo.repositoryURL.absoluteString)

                Link(destination: AppInfo.issuesURL) {
                    Label("Report an Issue", systemImage: "ladybug.fill")
                }
                .buttonStyle(PillButtonStyle(kind: .ghost))

                Link(destination: AppInfo.repositoryURL) {
                    Label("Star the Project", systemImage: "star.fill")
                }
                .buttonStyle(PillButtonStyle(kind: .secondary, tint: Theme.gold))
            }
        }
        .card()
    }
}

// MARK: - Palette card

private struct PaletteCard: View {
    let palette: Palette
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.sectionAccent) private var accent
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                preview
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(palette.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.text)
                        Text(palette.summary)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(accent)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(10)
            .background(isHovered ? Theme.raised : Theme.surface, in: shape)
            .overlay(shape.strokeBorder(isSelected ? accent : (isHovered ? Theme.strokeStrong : Theme.stroke), lineWidth: isSelected ? 2 : 1))
            .contentShape(shape)
        }
        .buttonStyle(PressableStyle())
        .onHover { isHovered = $0 }
        .pointerStyle(.link)
        .animation(.ui, value: isHovered)
        .animation(Theme.motion(.lively), value: isSelected)
        .accessibilityLabel(Text(palette.name))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// A tiny drawing of the app in this palette.
    private var preview: some View {
        HStack(spacing: 0) {
            VStack(spacing: 6) {
                Circle().fill(palette.mint).frame(width: 7, height: 7)
                Circle().fill(palette.amber).frame(width: 7, height: 7)
                Circle().fill(palette.lavender).frame(width: 7, height: 7)
                Spacer()
            }
            .padding(.top, 10)
            .frame(width: 22)
            .background(palette.rail)

            VStack(alignment: .leading, spacing: 6) {
                Capsule().fill(palette.text).frame(width: 54, height: 6)
                Capsule().fill(palette.textSecondary).frame(width: 82, height: 4)
                HStack(spacing: 5) {
                    Capsule().fill(palette.mint).frame(width: 30, height: 12)
                    Capsule().fill(palette.amber.opacity(0.35)).frame(width: 24, height: 12)
                    Capsule().fill(palette.lavender.opacity(0.35)).frame(width: 24, height: 12)
                }
                RoundedRectangle(cornerRadius: 4)
                    .fill(palette.surface)
                    .overlay(alignment: .leading) {
                        Capsule().fill(palette.textTertiary).frame(width: 46, height: 4).padding(.leading, 6)
                    }
                    .frame(height: 16)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 80)
        .background(palette.canvas)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.stroke))
    }
}

// MARK: - Language option

private struct LanguageOption: View {
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.sectionAccent) private var accent
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: language.nativeName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Text(verbatim: language.localizedName)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? accent : Theme.textTertiary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? accent.opacity(0.12) : (isHovered ? Theme.raised : Theme.surface), in: shape)
            .overlay(shape.strokeBorder(isSelected ? accent.opacity(0.6) : Theme.stroke, lineWidth: isSelected ? 1.5 : 1))
            .contentShape(shape)
        }
        .buttonStyle(PressableStyle())
        .onHover { isHovered = $0 }
        .pointerStyle(.link)
        .animation(.ui, value: isHovered)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
