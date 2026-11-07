import SwiftUI

struct CommandDetailView: View {
    @Bindable var command: SavedCommand
    var onCopy: () -> Void
    var onEdit: () -> Void
    var onDuplicate: () -> Void
    var onDelete: () -> Void

    @Environment(\.sectionAccent) private var accent

    var body: some View {
        let resolved = command.resolve()
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                    .appearAnimation()
                commandCard(resolved)
                    .appearAnimation(index: 1)
                if !resolved.parameters.isEmpty {
                    parametersCard(resolved.parameters)
                        .appearAnimation(index: 2)
                }
                if !command.notes.isEmpty {
                    notesCard
                        .appearAnimation(index: 3)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 14)
            .padding(.bottom, 28)
            .frame(maxWidth: 780, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(command.title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                    usageText
                }
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                if !command.tags.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(command.tags, id: \.self) { TagChip(tag: $0) }
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 12)
            HStack(spacing: 8) {
                FavoriteButton(isFavorite: $command.isFavorite)
                Button(action: onEdit) {
                    HStack(spacing: 8) {
                        Label("Edit", systemImage: "pencil")
                        KeyHint(keys: "⌘E")
                    }
                }
                .buttonStyle(PillButtonStyle(kind: .ghost))
                Menu {
                    Button("Duplicate", systemImage: "plus.square.on.square", action: onDuplicate)
                    Divider()
                    Button("Delete…", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                        .font(.system(size: 13, weight: .semibold))
                }
                .pillMenuStyle(height: 34)
                .help("Duplicate or delete")
            }
            .fixedSize()
        }
    }

    // MARK: - Command

    private func commandCard(_ resolved: ResolvedCommand) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("$")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(accent)
                HighlightedCommand(template: resolved.template, values: resolved.values, accent: accent)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(Theme.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Command: \(resolved.rendered)")
            }
            .padding(16)
            // Shell commands read left to right, even when the app is in Arabic.
            .environment(\.layoutDirection, .leftToRight)
            .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.stroke))
            .animation(Theme.motion(.ui), value: resolved.rendered)

            HStack(spacing: 12) {
                CopyButton(
                    title: String(localized: "Copy Command"),
                    kind: .primary,
                    size: .large,
                    shortcutHint: "⌘↩",
                    shortcut: KeyboardShortcut(.return, modifiers: .command),
                    action: onCopy
                )

                let missing = resolved.missing
                if !missing.isEmpty {
                    Label("Fill in \(missing.joined(separator: ", "))", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.warning)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(Theme.warning.opacity(0.13), in: Capsule())
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .animation(Theme.motion(.lively), value: resolved.missing)
        }
        .card()
    }

    // MARK: - Parameters

    private func parametersCard(_ parameters: [TemplateParameter]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: String(localized: "Fill in the blanks"), systemImage: "slider.horizontal.3") {
                Button {
                    withAnimation(Theme.motion(.ui)) { command.lastValues = [:] }
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(PillButtonStyle(kind: .ghost, size: .small))
                .disabled(command.lastValues.values.allSatisfy(\.isEmpty))
                .help("Clear what you typed and go back to the defaults")
            }
            ParameterFormView(parameters: parameters, command: command)
        }
        .card()
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: String(localized: "Notes"), systemImage: "text.alignleft")
            // Rendered as Markdown so links and `code` work.
            Text(LocalizedStringKey(command.notes))
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .card()
    }

    private var usageText: Text {
        guard let lastUsed = command.lastUsed else { return Text("Never used yet") }
        let when = lastUsed.formatted(.relative(presentation: .named))
        if command.useCount == 1 { return Text("Used once · last \(when)") }
        return Text("Used \(command.useCount) times · last \(when)")
    }
}

/// A labelled star toggle that pops when switched on.
struct FavoriteButton: View {
    @Binding var isFavorite: Bool

    var body: some View {
        Button {
            withAnimation(Theme.motion(.lively)) { isFavorite.toggle() }
        } label: {
            Label(isFavorite ? "Favorite" : "Add to Favorites", systemImage: isFavorite ? "star.fill" : "star")
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: isFavorite)
        }
        .buttonStyle(PillButtonStyle(kind: isFavorite ? .secondary : .ghost, tint: isFavorite ? Theme.gold : nil))
        .help(isFavorite ? "Remove from Favorites (⇧⌘F)" : "Add to Favorites (⇧⌘F)")
    }
}
