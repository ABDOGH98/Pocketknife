import SwiftUI
import SwiftData

/// Adds a new login or edits an existing one. Shown as a sheet.
struct PasswordEditorView: View {
    let target: PasswordEditorTarget
    var onSave: (SavedPassword) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private struct Draft: Equatable {
        var title = ""
        var username = ""
        var password = ""
        var website = ""
        var notes = ""
    }

    private enum Field: Hashable {
        case title
    }

    @State private var draft = Draft()
    @State private var original = Draft()
    @State private var isRevealed = false
    @State private var generateCount = 0
    @State private var isConfirmingDiscard = false
    @State private var saveError: String?
    @FocusState private var focusedField: Field?

    private var existing: SavedPassword? {
        if case .edit(let password) = target { password } else { nil }
    }

    private var validationMessage: String? {
        if draft.title.trimmingCharacters(in: .whitespaces).isEmpty { return "Add a title" }
        if draft.password.isEmpty { return "Add a password" }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                IconTile(systemImage: existing == nil ? "plus" : "pencil", tint: Theme.amber, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(existing == nil ? "New Login" : "Edit Login")
                        .font(.system(size: 18, weight: .bold))
                    Text("The password is saved in your Mac’s Keychain.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
            .padding(20)

            VStack(alignment: .leading, spacing: 14) {
                FieldBox(label: String(localized: "Title")) {
                    TextField("Title", text: $draft.title, prompt: Text("GitHub"))
                        .focused($focusedField, equals: .title)
                }
                FieldBox(label: String(localized: "Username")) {
                    TextField("Username", text: $draft.username, prompt: Text("name@example.com"))
                        .textContentType(.username)
                        .autocorrectionDisabled()
                }
                passwordField
                FieldBox(label: String(localized: "Website"), hint: String(localized: "Optional")) {
                    TextField("Website", text: $draft.website, prompt: Text("github.com"))
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                }
                FieldBox(label: String(localized: "Notes"), hint: String(localized: "Optional")) {
                    TextField("Notes", text: $draft.notes, prompt: Text("Recovery codes are in the safe"), axis: .vertical)
                        .lineLimit(1...4)
                        .padding(.vertical, 9)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            Rectangle().fill(Theme.stroke).frame(height: 1)
            footer
        }
        .frame(width: 480)
        .background(Theme.surface)
        .environment(\.sectionAccent, Theme.amber)
        .tint(Theme.amber)
        .onAppear {
            load()
            focusedField = existing == nil ? .title : nil
        }
        .confirmationDialog("Discard changes?", isPresented: $isConfirmingDiscard) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        }
        .alert(
            "Couldn’t Save Password",
            isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(String(localized: "Password"))
            HStack(spacing: 8) {
                FieldBox(monospaced: isRevealed) {
                    Group {
                        if isRevealed {
                            TextField("Password", text: $draft.password)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("Password", text: $draft.password)
                        }
                    }
                    .labelsHidden()
                    .textContentType(.password)
                }
                Button {
                    withAnimation(Theme.motion(.ui)) { isRevealed.toggle() }
                } label: {
                    Label(isRevealed ? "Hide" : "Show", systemImage: isRevealed ? "eye.slash" : "eye")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(PillButtonStyle(kind: .ghost))
                Button {
                    draft.password = PasswordGenerator.generate()
                    generateCount += 1
                    withAnimation(Theme.motion(.ui)) { isRevealed = true }
                } label: {
                    Label("Generate", systemImage: "wand.and.stars")
                        .symbolEffect(.bounce, value: generateCount)
                }
                .buttonStyle(PillButtonStyle(kind: .secondary))
                .help("Make a strong 20-character password")
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if let validationMessage {
                Label(validationMessage, systemImage: "info.circle")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .transition(.opacity)
            }
            Spacer()
            Button("Cancel", role: .cancel) {
                if draft != original { isConfirmingDiscard = true } else { dismiss() }
            }
            .keyboardShortcut(.cancelAction)
            .buttonStyle(PillButtonStyle(kind: .ghost))
            Button(action: save) {
                HStack(spacing: 8) {
                    Text(existing == nil ? "Add Login" : "Save")
                    KeyHint(keys: "⌘↩", onAccent: true)
                }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(PillButtonStyle(kind: .primary))
            .disabled(validationMessage != nil)
        }
        .padding(16)
        .background(Theme.canvas)
        .animation(.ui, value: validationMessage)
    }

    // MARK: - Actions

    private func load() {
        if let existing {
            draft = Draft(
                title: existing.title,
                username: existing.username,
                password: existing.password,
                website: existing.website,
                notes: existing.notes
            )
        }
        original = draft
    }

    private func save() {
        let item = existing ?? SavedPassword(title: "")
        // Write the secret first, so a Keychain failure doesn't leave a login without its password.
        guard Keychain.setPassword(draft.password, for: item.keychainID.uuidString) else {
            saveError = "The password couldn’t be written to your Keychain. Your changes weren’t saved."
            return
        }
        item.title = draft.title.trimmingCharacters(in: .whitespaces)
        item.username = draft.username.trimmingCharacters(in: .whitespaces)
        item.website = draft.website.trimmingCharacters(in: .whitespaces)
        item.notes = draft.notes
        if existing == nil { context.insert(item) }
        try? context.save()
        onSave(item)
        dismiss()
    }
}
