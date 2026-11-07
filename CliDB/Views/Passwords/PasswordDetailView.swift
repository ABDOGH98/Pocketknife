import SwiftUI

struct PasswordDetailView: View {
    @Bindable var password: SavedPassword
    var onCopyUsername: () -> Void
    var onCopyPassword: () -> Void
    var onEdit: () -> Void

    @State private var isRevealed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                GroupBox {
                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 14) {
                        field("Username") {
                            Text(password.username.isEmpty ? "—" : password.username)
                                .textSelection(.enabled)
                        } actions: {
                            copyButton("Copy Username", action: onCopyUsername)
                                .disabled(password.username.isEmpty)
                        }

                        Divider().gridCellUnsizedAxes(.horizontal)

                        field("Password") {
                            // Only read from the Keychain when shown; hidden it's a fixed-length mask.
                            Text(isRevealed ? password.password : String(repeating: "•", count: 12))
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        } actions: {
                            Button {
                                isRevealed.toggle()
                            } label: {
                                Image(systemName: isRevealed ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.borderless)
                            .help(isRevealed ? "Hide Password" : "Show Password")
                            .accessibilityLabel(isRevealed ? "Hide Password" : "Show Password")
                            copyButton("Copy Password", action: onCopyPassword)
                        }

                        if let url = password.websiteURL {
                            Divider().gridCellUnsizedAxes(.horizontal)
                            field("Website") {
                                Link(password.website, destination: url)
                            } actions: {
                                EmptyView()
                            }
                        }
                    }
                    .padding(8)
                }

                HStack(spacing: 12) {
                    Button(action: onCopyPassword) {
                        Label("Copy Password", systemImage: "key")
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: .command)
                    .help("Copy Password (⌘↩)")

                    Button(action: onCopyUsername) {
                        Label("Copy Username", systemImage: "person")
                    }
                    .controlSize(.large)
                    .disabled(password.username.isEmpty)
                }

                if !password.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes").font(.headline)
                        Text(password.notes)
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Hide the password again when switching to another login.
        .onChange(of: password.keychainID) { isRevealed = false }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    password.isFavorite.toggle()
                } label: {
                    Label(
                        password.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                        systemImage: password.isFavorite ? "star.fill" : "star"
                    )
                }
                Button("Edit", systemImage: "pencil", action: onEdit)
                    .help("Edit Login")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(password.title)
                    .font(.title.weight(.semibold))
                    .textSelection(.enabled)
                if password.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("Favorite")
                }
            }
            Group {
                if let lastUsed = password.lastUsed {
                    Text("Password copied \(lastUsed, format: .relative(presentation: .named))")
                } else {
                    Text("Added \(password.createdAt, format: .dateTime.day().month().year())")
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    private func field<Value: View, Actions: View>(
        _ label: String,
        @ViewBuilder value: () -> Value,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            value()
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) { actions() }
        }
    }

    private func copyButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "doc.on.doc")
        }
        .buttonStyle(.borderless)
        .help(title)
        .accessibilityLabel(title)
    }
}
