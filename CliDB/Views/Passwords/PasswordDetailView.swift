import SwiftUI

struct PasswordDetailView: View {
    @Bindable var password: SavedPassword
    var onCopyUsername: () -> Void
    var onCopyPassword: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var isRevealed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                    .appearAnimation()

                VStack(spacing: 0) {
                    FieldRow(label: String(localized: "Username"), systemImage: "person.fill") {
                        Text(password.username.isEmpty ? String(localized: "No username") : password.username)
                            .foregroundStyle(password.username.isEmpty ? Theme.textTertiary : Theme.text)
                            .textSelection(.enabled)
                    } actions: {
                        CopyButton(size: .small, action: onCopyUsername)
                            .disabled(password.username.isEmpty)
                    }

                    divider

                    FieldRow(label: String(localized: "Password"), systemImage: "key.fill") {
                        // Only read from the Keychain when shown; hidden it's a fixed-length mask.
                        Text(isRevealed ? password.password : String(repeating: "•", count: 14))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.text)
                            .textSelection(.enabled)
                            .contentTransition(.opacity)
                    } actions: {
                        Button {
                            withAnimation(Theme.motion(.ui)) { isRevealed.toggle() }
                        } label: {
                            Label(isRevealed ? "Hide" : "Show", systemImage: isRevealed ? "eye.slash" : "eye")
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(PillButtonStyle(kind: .ghost, size: .small))
                        CopyButton(size: .small, action: onCopyPassword)
                    }

                    if let url = password.websiteURL {
                        divider
                        FieldRow(label: String(localized: "Website"), systemImage: "globe") {
                            Text(password.website)
                                .foregroundStyle(Theme.text)
                                .textSelection(.enabled)
                                .lineLimit(1)
                        } actions: {
                            Link(destination: url) {
                                Label("Open", systemImage: "arrow.up.right")
                            }
                            .buttonStyle(PillButtonStyle(kind: .ghost, size: .small))
                        }
                    }
                }
                .card(padding: 6)
                .appearAnimation(index: 1)

                HStack(spacing: 10) {
                    CopyButton(
                        title: String(localized: "Copy Password"),
                        systemImage: "key.fill",
                        kind: .primary,
                        size: .large,
                        shortcutHint: "⌘↩",
                        shortcut: KeyboardShortcut(.return, modifiers: .command),
                        action: onCopyPassword
                    )
                    CopyButton(title: String(localized: "Copy Username"), systemImage: "person.fill", size: .large, action: onCopyUsername)
                        .disabled(password.username.isEmpty)
                }
                .appearAnimation(index: 2)

                Label("Copied passwords are hidden from clipboard managers and cleared after a minute.", systemImage: "lock.shield.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                    .appearAnimation(index: 3)

                if !password.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: String(localized: "Notes"), systemImage: "text.alignleft")
                        Text(password.notes)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .card()
                    .appearAnimation(index: 4)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 14)
            .padding(.bottom, 28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        // Hide the password again when switching to another login.
        .onChange(of: password.keychainID) { isRevealed = false }
    }

    private var divider: some View {
        Rectangle().fill(Theme.stroke).frame(height: 1).padding(.horizontal, 12)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            IconTile(letter: password.initial, tint: Theme.swatch(for: password.title), size: 58)
            VStack(alignment: .leading, spacing: 6) {
                Text(password.title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Group {
                    if let lastUsed = password.lastUsed {
                        Text("Password copied \(lastUsed, format: .relative(presentation: .named))")
                    } else {
                        Text("Added \(password.createdAt, format: .dateTime.day().month().year())")
                    }
                }
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 12)
            HStack(spacing: 8) {
                FavoriteButton(isFavorite: $password.isFavorite)
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(PillButtonStyle(kind: .ghost))
                Button(action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(PillButtonStyle(kind: .destructive))
                .help("Delete this login (⌘⌫)")
            }
            .fixedSize()
        }
    }
}

/// One field of a login: an icon, a label above the value, and its actions on the right.
private struct FieldRow<Value: View, Actions: View>: View {
    let label: String
    let systemImage: String
    @ViewBuilder var value: Value
    @ViewBuilder var actions: Actions

    @Environment(\.sectionAccent) private var accent
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 32, height: 32)
                .background(accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                value
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 8) { actions }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(isHovered ? Theme.raised : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onHover { isHovered = $0 }
        .animation(.ui, value: isHovered)
    }
}
