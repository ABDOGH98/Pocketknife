import SwiftUI
import SwiftData

struct HomeView: View {
    var onSelect: (AppSection) -> Void
    var onRequest: (SectionRequest) -> Void

    @Environment(\.openWindow) private var openWindow
    @Query private var commands: [SavedCommand]
    @Query private var passwords: [SavedPassword]
    @State private var toaster = Toaster()

    private var recentCommands: [SavedCommand] {
        commands
            .filter { $0.lastUsed != nil }
            .sorted { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        ZStack {
            AmbientBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    cards
                    quickActions
                    if !recentCommands.isEmpty {
                        recent
                    }
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 32)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Pocketknife")
        .toast(toaster)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greeting)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .kerning(0.8)
            Text("What do you need today?")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Theme.text)
        }
        .appearAnimation()
    }

    private var cards: some View {
        HStack(alignment: .top, spacing: 16) {
            HomeCard(section: .commands, count: commands.count, countText: Text("^[\(commands.count) command](inflect: true)")) { onSelect(.commands) }
                .appearAnimation(index: 1)
            HomeCard(section: .passwords, count: passwords.count, countText: Text("^[\(passwords.count) login](inflect: true)")) { onSelect(.passwords) }
                .appearAnimation(index: 2)
            HomeCard(section: .utils, count: UtilityTool.allCases.count, countText: Text("^[\(UtilityTool.allCases.count) tool](inflect: true)")) { onSelect(.utils) }
                .appearAnimation(index: 3)
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: String(localized: "Quick actions"), systemImage: "bolt.fill")
                .environment(\.sectionAccent, Theme.gold)
            FlowLayout(spacing: 10) {
                Button {
                    openWindow(id: EditorTarget.windowID, value: EditorTarget.new)
                } label: {
                    Label("New Command", systemImage: "plus")
                }
                .buttonStyle(PillButtonStyle(kind: .secondary))
                .environment(\.sectionAccent, AppSection.commands.accent)

                Button {
                    onRequest(.newPassword)
                } label: {
                    Label("New Login", systemImage: "plus")
                }
                .buttonStyle(PillButtonStyle(kind: .secondary))
                .environment(\.sectionAccent, AppSection.passwords.accent)

                ForEach(UtilityTool.allCases) { tool in
                    Button {
                        onRequest(.utility(tool))
                    } label: {
                        Label(tool.actionTitle, systemImage: tool.systemImage)
                    }
                    .buttonStyle(PillButtonStyle(kind: .secondary))
                    .environment(\.sectionAccent, AppSection.utils.accent)
                }
            }
        }
        .appearAnimation(index: 4)
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: String(localized: "Recently used"), systemImage: "clock.fill") {
                Button("See all") { onSelect(.commands) }
                    .buttonStyle(PillButtonStyle(kind: .ghost, size: .small))
            }
            VStack(spacing: 8) {
                ForEach(recentCommands) { command in
                    RecentCommandRow(command: command) {
                        let missing = command.copyToClipboard()
                        let names = missing.joined(separator: ", ")
                        toaster.show(missing.isEmpty ? String(localized: "Copied “\(command.title)”") : String(localized: "Copied — fill in \(names)"),
                                     kind: missing.isEmpty ? .success : .warning)
                    }
                }
            }
        }
        .environment(\.sectionAccent, AppSection.commands.accent)
        .appearAnimation(index: 5)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: String(localized: "Good morning")
        case 12..<18: String(localized: "Good afternoon")
        default: String(localized: "Good evening")
        }
    }
}

// MARK: - Card

private struct HomeCard: View {
    let section: AppSection
    let count: Int
    let countText: Text
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        let accent = section.accent
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    IconTile(systemImage: section.systemImage, tint: accent, size: 52)
                        .symbolEffect(.bounce, value: isHovered)
                    Spacer()
                    KeyHint(keys: "⌘\(section.shortcut)")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(section.title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Text(section.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3, reservesSpace: true)
                }

                HStack {
                    countText
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .contentTransition(.numericText())
                    Spacer()
                    HStack(spacing: 6) {
                        Text("Open")
                        Image(systemName: "arrow.right")
                            .offset(x: isHovered ? 3 : 0)
                    }
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(isHovered ? Theme.onAccent : accent)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(isHovered ? accent : accent.opacity(0.14), in: Capsule())
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background {
                shape.fill(Theme.surface)
                shape.fill(
                    LinearGradient(colors: [accent.opacity(isHovered ? 0.14 : 0.06), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            }
            .overlay(shape.strokeBorder(isHovered ? accent.opacity(0.55) : Theme.stroke, lineWidth: isHovered ? 1.5 : 1))
            .shadow(color: accent.opacity(isHovered ? 0.22 : 0), radius: 18, y: 8)
            .offset(y: isHovered ? -3 : 0)
            .contentShape(shape)
        }
        .buttonStyle(PressableStyle())
        .onHover { isHovered = $0 }
        .pointerStyle(.link)
        .animation(Theme.motion(.lively), value: isHovered)
        .accessibilityLabel(section.title)
        .accessibilityHint(section.subtitle)
    }
}

/// Shrinks slightly while pressed; for large custom-drawn buttons such as cards.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Recent

private struct RecentCommandRow: View {
    let command: SavedCommand
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemImage: "terminal", tint: Theme.mint, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(command.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(command.resolve().preview)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 8)
            CopyButton(action: onCopy)
        }
        .card(padding: 12, radius: 14)
    }
}

extension UtilityTool {
    /// The Home quick-action title.
    var actionTitle: String {
        switch self {
        case .json: String(localized: "Format JSON")
        case .xml: String(localized: "Format XML")
        case .base64: String(localized: "Base64")
        case .jwt: String(localized: "Decode JWT")
        }
    }
}
