import SwiftUI
import SwiftData

/// What the password editor sheet is editing.
enum PasswordEditorTarget: Identifiable {
    case new
    case edit(SavedPassword)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let password): password.keychainID.uuidString
        }
    }
}

struct PasswordsView: View {
    var onHome: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Query private var passwords: [SavedPassword]

    @State private var selectedID: PersistentIdentifier?
    @State private var searchText = ""
    @State private var editing: PasswordEditorTarget?
    @State private var pendingDelete: SavedPassword?
    @State private var toaster = Toaster()

    var body: some View {
        let visible = filteredPasswords
        let selected = selectedPassword
        NavigationSplitView {
            list(visible)
        } detail: {
            if let selected {
                PasswordDetailView(
                    password: selected,
                    onCopyUsername: { copyUsername(selected) },
                    onCopyPassword: { copyPassword(selected) },
                    onEdit: { editing = .edit(selected) }
                )
            } else if !passwords.isEmpty {
                ContentUnavailableView(
                    "No Login Selected",
                    systemImage: "key",
                    description: Text("Choose a login from the list, or press ⌘N to add one.")
                )
            }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search passwords")
        .focusedSceneValue(\.newPasswordAction, NewPasswordAction { editing = .new })
        .sheet(item: $editing) { target in
            PasswordEditorView(target: target) { saved in
                searchText = ""
                selectedID = saved.persistentModelID
            }
        }
        .confirmationDialog(
            "Delete “\(pendingDelete?.title ?? "")”?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { password in
            Button("Delete", role: .destructive) { delete(password) }
        } message: { _ in
            Text("The username and password will be removed from Pocketknife and your Keychain. This can’t be undone.")
        }
        .toast(toaster)
        .onChange(of: searchText) {
            if !searchText.isEmpty { selectedID = filteredPasswords.first?.persistentModelID }
        }
        .task {
            if selectedID == nil { selectedID = filteredPasswords.first?.persistentModelID }
        }
    }

    private func list(_ visible: [SavedPassword]) -> some View {
        List(visible, selection: $selectedID) { password in
            PasswordRow(password: password)
        }
        .contextMenu(forSelectionType: PersistentIdentifier.self) { ids in
            if let password = ids.first.flatMap(password(with:)) {
                Button("Copy Username", systemImage: "person") { copyUsername(password) }
                    .disabled(password.username.isEmpty)
                Button("Copy Password", systemImage: "key") { copyPassword(password) }
                Divider()
                Button("Edit…", systemImage: "pencil") { editing = .edit(password) }
                Button(
                    password.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: password.isFavorite ? "star.slash" : "star"
                ) { password.isFavorite.toggle() }
                Divider()
                Button("Delete…", systemImage: "trash", role: .destructive) { pendingDelete = password }
            }
        } primaryAction: { ids in
            // Double-click copies the password.
            if let password = ids.first.flatMap(password(with:)) { copyPassword(password) }
        }
        .onDeleteCommand { pendingDelete = selectedPassword }
        .overlay { emptyState(isEmpty: visible.isEmpty) }
        .navigationTitle("Passwords")
        .navigationSubtitle(Text("^[\(visible.count) login](inflect: true)"))
        .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 420)
        .toolbar {
            HomeToolbarButton(action: onHome)
            ToolbarItem(placement: .primaryAction) {
                Button("New Password", systemImage: "plus") { editing = .new }
                    .help("New Password (⌘N)")
            }
        }
    }

    @ViewBuilder
    private func emptyState(isEmpty: Bool) -> some View {
        if passwords.isEmpty {
            ContentUnavailableView {
                Label("No Passwords Yet", systemImage: "key")
            } description: {
                Text("Save usernames and passwords here. Passwords are stored in your Mac’s Keychain.")
            } actions: {
                Button("New Password") { editing = .new }
                    .buttonStyle(.borderedProminent)
            }
        } else if isEmpty {
            ContentUnavailableView.search(text: searchText)
        }
    }

    // MARK: - Data

    private var filteredPasswords: [SavedPassword] {
        passwords
            .filter { $0.matches(searchText) }
            .sorted { lhs, rhs in
                if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }

    private var selectedPassword: SavedPassword? {
        selectedID.flatMap(password(with:))
    }

    private func password(with id: PersistentIdentifier) -> SavedPassword? {
        passwords.first { $0.persistentModelID == id }
    }

    // MARK: - Actions

    private func copyUsername(_ password: SavedPassword) {
        guard !password.username.isEmpty else { return }
        Clipboard.copy(password.username)
        toaster.show("Username Copied")
    }

    private func copyPassword(_ password: SavedPassword) {
        let secret = password.password
        guard !secret.isEmpty else {
            toaster.show("No password saved")
            return
        }
        Clipboard.copySecret(secret)
        password.useCount += 1
        password.lastUsed = .now
        toaster.show("Password Copied — clears in 1 minute")
    }

    private func delete(_ password: SavedPassword) {
        let visible = filteredPasswords
        if password.persistentModelID == selectedID, let index = visible.firstIndex(of: password) {
            let neighbor = visible.indices.contains(index + 1) ? visible[index + 1] : (index > 0 ? visible[index - 1] : nil)
            selectedID = neighbor?.persistentModelID
        }
        password.deleteSecret()
        context.delete(password)
        try? context.save()
        pendingDelete = nil
    }
}

private struct PasswordRow: View {
    let password: SavedPassword

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "key.fill")
                .foregroundStyle(.white)
                .font(.caption)
                .frame(width: 26, height: 26)
                .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(password.title)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if password.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("Favorite")
                    }
                }
                Text(password.username.isEmpty ? "No username" : password.username)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    PasswordsView()
        .modelContainer(for: SavedPassword.self, inMemory: true)
}
