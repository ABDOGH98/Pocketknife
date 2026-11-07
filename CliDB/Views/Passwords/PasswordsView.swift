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
    @Binding var pendingRequest: SectionRequest?

    @Environment(\.modelContext) private var context
    @Query private var passwords: [SavedPassword]

    @State private var selectedID: PersistentIdentifier?
    @State private var searchText = ""
    @State private var editing: PasswordEditorTarget?
    @State private var pendingDelete: SavedPassword?
    @State private var toaster = Toaster()
    @FocusState private var isSearchFocused: Bool
    @FocusState private var isListFocused: Bool

    var body: some View {
        let visible = filteredPasswords
        let selected = selectedPassword
        HStack(spacing: 0) {
            listPane(visible)
                .frame(width: 330)
            Rectangle().fill(Theme.stroke).frame(width: 1).ignoresSafeArea()
            Group {
                if let selected {
                    PasswordDetailView(
                        password: selected,
                        onCopyUsername: { copyUsername(selected) },
                        onCopyPassword: { copyPassword(selected) },
                        onEdit: { editing = .edit(selected) },
                        onDelete: { pendingDelete = selected }
                    )
                    .id(selected.persistentModelID)
                    .transition(.opacity.combined(with: .offset(x: 10)))
                } else if !passwords.isEmpty {
                    EmptyStateView(
                        title: String(localized: "Pick a login"),
                        message: String(localized: "Choose one from the list to see and copy its details."),
                        systemImage: "hand.point.left.fill"
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Passwords")
        .focusedSceneValue(\.newPasswordAction, NewPasswordAction { editing = .new })
        .sheet(item: $editing) { target in
            PasswordEditorView(target: target) { saved in
                searchText = ""
                selectedID = saved.persistentModelID
                toaster.show(String(localized: "Login Saved"))
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
            if pendingRequest == .newPassword {
                pendingRequest = nil
                editing = .new
            }
        }
    }

    // MARK: - List

    private func listPane(_ visible: [SavedPassword]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Passwords")
                            .font(.system(size: 22, weight: .bold))
                        Text("^[\(visible.count) login](inflect: true)")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    Button {
                        editing = .new
                    } label: {
                        HStack(spacing: 8) {
                            Label("New", systemImage: "plus")
                            KeyHint(keys: "⌘N", onAccent: true)
                        }
                    }
                    .buttonStyle(PillButtonStyle(kind: .primary))
                    .help("New Login (⌘N)")
                }

                SearchField(
                    text: $searchText,
                    prompt: String(localized: "Search logins"),
                    focus: $isSearchFocused,
                    onSubmit: { if let selectedPassword { copyPassword(selectedPassword) } },
                    onMove: { moveSelection(by: $0, in: visible) }
                )
            }
            .padding(.horizontal, 16)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(visible) { password in
                            PasswordRow(
                                password: password,
                                isSelected: password.persistentModelID == selectedID,
                                onCopy: { copyPassword(password) }
                            )
                            .id(password.persistentModelID)
                            .onTapGesture { select(password) }
                            // Double-click copies the password.
                            .simultaneousGesture(TapGesture(count: 2).onEnded { copyPassword(password) })
                            .contextMenu { contextMenu(for: password) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .animation(Theme.motion(.ui), value: visible.map(\.persistentModelID))
                }
                .scrollContentBackground(.hidden)
                .onChange(of: selectedID) {
                    if let selectedID { withAnimation(Theme.motion(.ui)) { proxy.scrollTo(selectedID) } }
                }
            }
            .focusable()
            .focused($isListFocused)
            .focusEffectDisabled()
            .onKeyPress(.downArrow) {
                moveSelection(by: 1, in: visible)
                return .handled
            }
            .onKeyPress(.upArrow) {
                moveSelection(by: -1, in: visible)
                return .handled
            }
            .onDeleteCommand { pendingDelete = selectedPassword }
            .overlay { emptyState(isEmpty: visible.isEmpty) }
        }
        .padding(.top, 10)
    }

    @ViewBuilder
    private func contextMenu(for password: SavedPassword) -> some View {
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

    @ViewBuilder
    private func emptyState(isEmpty: Bool) -> some View {
        if passwords.isEmpty {
            EmptyStateView(
                title: String(localized: "No logins yet"),
                message: String(localized: "Save usernames and passwords here. Passwords are stored in your Mac’s Keychain."),
                systemImage: "key.fill"
            ) {
                Button { editing = .new } label: { Label("New Login", systemImage: "plus") }
                    .buttonStyle(PillButtonStyle(kind: .primary))
            }
        } else if isEmpty {
            EmptyStateView(
                title: String(localized: "No results"),
                message: String(localized: "Nothing matches “\(searchText)”."),
                systemImage: "magnifyingglass"
            ) {
                Button("Clear Search") { searchText = "" }
                    .buttonStyle(PillButtonStyle(kind: .ghost))
            }
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

    private func select(_ password: SavedPassword) {
        withAnimation(Theme.motion(.ui)) { selectedID = password.persistentModelID }
        isListFocused = true
    }

    private func moveSelection(by offset: Int, in visible: [SavedPassword]) {
        guard !visible.isEmpty else { return }
        let current = visible.firstIndex { $0.persistentModelID == selectedID } ?? (offset > 0 ? -1 : visible.count)
        let next = min(max(current + offset, 0), visible.count - 1)
        withAnimation(Theme.motion(.ui)) { selectedID = visible[next].persistentModelID }
    }

    private func copyUsername(_ password: SavedPassword) {
        guard !password.username.isEmpty else { return }
        Clipboard.copy(password.username)
        toaster.show(String(localized: "Username Copied"))
    }

    private func copyPassword(_ password: SavedPassword) {
        let secret = password.password
        guard !secret.isEmpty else {
            toaster.show(String(localized: "No password saved"), kind: .warning)
            return
        }
        Clipboard.copySecret(secret)
        password.useCount += 1
        password.lastUsed = .now
        toaster.show(String(localized: "Password Copied — clears in 1 minute"))
    }

    private func delete(_ password: SavedPassword) {
        let visible = filteredPasswords
        if password.persistentModelID == selectedID, let index = visible.firstIndex(of: password) {
            let neighbor = visible.indices.contains(index + 1) ? visible[index + 1] : (index > 0 ? visible[index - 1] : nil)
            selectedID = neighbor?.persistentModelID
        }
        password.deleteSecret()
        withAnimation(Theme.motion(.ui)) { context.delete(password) }
        try? context.save()
        pendingDelete = nil
    }
}

// MARK: - Row

extension SavedPassword {
    /// The first letter of the title, for the avatar tile.
    var initial: String {
        title.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "?"
    }
}

private struct PasswordRow: View {
    let password: SavedPassword
    let isSelected: Bool
    let onCopy: () -> Void

    @Environment(\.sectionAccent) private var accent
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        HStack(spacing: 12) {
            IconTile(letter: password.initial, tint: Theme.swatch(for: password.title), size: 36)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(password.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    if password.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.gold)
                            .accessibilityLabel("Favorite")
                    }
                }
                Text(password.username.isEmpty ? String(localized: "No username") : password.username)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if isHovered || isSelected {
                CopyButton(title: String(localized: "Copy"), systemImage: "key", size: .small, action: onCopy)
                    .help("Copy Password")
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(shape.fill(isSelected ? accent.opacity(0.13) : (isHovered ? Theme.raised : Theme.surface)))
        .overlay(shape.strokeBorder(isSelected ? accent.opacity(0.5) : Theme.stroke, lineWidth: isSelected ? 1.5 : 1))
        .contentShape(shape)
        .onHover { isHovered = $0 }
        .animation(.ui, value: isHovered)
        .animation(Theme.motion(.lively), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview {
    PasswordsView(pendingRequest: .constant(nil))
        .modelContainer(for: SavedPassword.self, inMemory: true)
}
