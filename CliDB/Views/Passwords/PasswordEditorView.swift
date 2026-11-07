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
    }

    private enum Field: Hashable {
        case title
    }

    @State private var draft = Draft()
    @State private var original = Draft()
    @State private var isRevealed = false
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
            Form {
                Section {
                    TextField("Title", text: $draft.title, prompt: Text("GitHub"))
                        .focused($focusedField, equals: .title)
                    TextField("Username", text: $draft.username, prompt: Text("name@example.com"))
                        .textContentType(.username)
                        .autocorrectionDisabled()
                    passwordField
                }
            }
            .formStyle(.grouped)

            Divider()
            footer
        }
        .frame(width: 460)
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
        LabeledContent("Password") {
            HStack(spacing: 6) {
                Group {
                    if isRevealed {
                        TextField("Password", text: $draft.password)
                            .font(.system(.body, design: .monospaced))
                            .autocorrectionDisabled()
                    } else {
                        SecureField("Password", text: $draft.password)
                    }
                }
                .labelsHidden()
                .textContentType(.password)

                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .help(isRevealed ? "Hide Password" : "Show Password")
                .accessibilityLabel(isRevealed ? "Hide Password" : "Show Password")

                Button {
                    draft.password = PasswordGenerator.generate()
                    isRevealed = true
                } label: {
                    Image(systemName: "wand.and.stars")
                }
                .buttonStyle(.borderless)
                .help("Generate a Strong Password")
                .accessibilityLabel("Generate a Strong Password")
            }
        }
    }

    private var footer: some View {
        HStack {
            if let validationMessage {
                Text(validationMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancel", role: .cancel) {
                if draft != original { isConfirmingDiscard = true } else { dismiss() }
            }
            .keyboardShortcut(.cancelAction)
            Button(existing == nil ? "Add" : "Save", action: save)
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(validationMessage != nil)
                .help("⌘↩")
        }
        .padding(12)
    }

    // MARK: - Actions

    private func load() {
        if let existing {
            draft = Draft(
                title: existing.title,
                username: existing.username,
                password: existing.password
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
        if existing == nil { context.insert(item) }
        try? context.save()
        onSave(item)
        dismiss()
    }
}
