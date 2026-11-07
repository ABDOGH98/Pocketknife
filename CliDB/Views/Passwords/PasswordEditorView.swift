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
        var isFavorite = false
    }

    private enum Field: Hashable {
        case title, username, password, website
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

    private var missing: String? {
        if draft.title.trimmingCharacters(in: .whitespaces).isEmpty { return String(localized: "Give this login a name") }
        if draft.password.isEmpty { return String(localized: "Add a password, or click Generate") }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Form {
                Section {
                    TextField("Name", text: $draft.title, prompt: Text("e.g. GitHub"))
                        .focused($focusedField, equals: .title)
                        .onSubmit { focusedField = .username }
                    TextField("Username", text: $draft.username, prompt: Text("e.g. name@example.com"))
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .username)
                        .onSubmit { focusedField = .password }
                } header: {
                    Text("Account")
                }

                Section {
                    passwordField
                    strengthMeter
                } header: {
                    Text("Password")
                } footer: {
                    FormHint("Stored only in your Mac’s Keychain, never in Pocketknife’s own database.")
                }

                Section {
                    TextField("Website", text: $draft.website, prompt: Text("e.g. github.com"))
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .website)
                    Toggle("Favorite", isOn: $draft.isFavorite)
                    TextField("Notes", text: $draft.notes, prompt: Text("Recovery codes hint, security question…"), axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Text("Extras")
                } footer: {
                    FormHint("All optional. Favorites stay at the top of the list.")
                }
            }
            .formStyle(.grouped)

            FormFooter(
                missing: missing,
                saveTitle: existing == nil ? "Add Login" : "Save",
                onCancel: cancel,
                onSave: save
            )
        }
        .frame(width: 480)
        .frame(minHeight: 520)
        .onAppear {
            load()
            focusedField = existing == nil ? .title : nil
        }
        .confirmationDialog("Discard changes?", isPresented: $isConfirmingDiscard) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text(existing == nil ? "This login hasn’t been added yet." : "Your edits to this login will be lost.")
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

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                Text(existing == nil ? "New Login" : "Edit Login")
                    .font(.headline)
                Text(existing == nil ? String(localized: "Only a name and a password are required.") : original.title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 4)
    }

    private var passwordField: some View {
        LabeledContent("Password") {
            HStack(spacing: 6) {
                Group {
                    if isRevealed {
                        TextField("Password", text: $draft.password, prompt: Text("Type or generate"))
                            .font(.system(.body, design: .monospaced))
                            .autocorrectionDisabled()
                    } else {
                        SecureField("Password", text: $draft.password, prompt: Text("Type or generate"))
                    }
                }
                .labelsHidden()
                .textContentType(.password)
                .focused($focusedField, equals: .password)

                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .frame(width: 18)
                }
                .buttonStyle(.borderless)
                .help(isRevealed ? "Hide Password" : "Show Password")
                .accessibilityLabel(isRevealed ? "Hide Password" : "Show Password")

                Button {
                    draft.password = PasswordGenerator.generate()
                    isRevealed = true
                } label: {
                    Label("Generate", systemImage: "wand.and.stars")
                }
                .help("Create a strong 20-character password")
            }
        }
    }

    private var strengthMeter: some View {
        let strength = PasswordStrength(draft.password)
        let color: Color = switch strength {
        case .empty: .secondary
        case .weak: .red
        case .fair: .orange
        case .strong: .green
        }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(1...3, id: \.self) { level in
                    Capsule()
                        .fill(strength.rawValue >= level ? AnyShapeStyle(color) : AnyShapeStyle(.quaternary))
                        .frame(height: 4)
                }
            }
            HStack(spacing: 6) {
                if strength != .empty {
                    Text(strength.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(color)
                }
                Text(strength.advice)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .animation(.snappy, value: strength)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Password strength: \(strength.title). \(strength.advice)"))
    }

    // MARK: - Actions

    private func load() {
        if let existing {
            draft = Draft(
                title: existing.title,
                username: existing.username,
                password: existing.password,
                website: existing.website,
                notes: existing.notes,
                isFavorite: existing.isFavorite
            )
        }
        original = draft
    }

    private func cancel() {
        if draft != original { isConfirmingDiscard = true } else { dismiss() }
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
        item.isFavorite = draft.isFavorite
        if existing == nil { context.insert(item) }
        try? context.save()
        onSave(item)
        dismiss()
    }
}
