import SwiftUI
import SwiftData

enum SidebarItem: Hashable {
    case all
    case favorites
    case tag(String)
}

enum CommandSort: String, CaseIterable, Identifiable {
    case recentlyUsed, mostUsed, name, dateAdded

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .recentlyUsed: "Recently Used"
        case .mostUsed: "Most Used"
        case .name: "Name"
        case .dateAdded: "Date Added"
        }
    }

    func areInIncreasingOrder(_ lhs: SavedCommand, _ rhs: SavedCommand) -> Bool {
        switch self {
        case .recentlyUsed:
            let left = lhs.lastUsed ?? .distantPast
            let right = rhs.lastUsed ?? .distantPast
            if left != right { return left > right }
        case .mostUsed:
            if lhs.useCount != rhs.useCount { return lhs.useCount > rhs.useCount }
        case .dateAdded:
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        case .name:
            break
        }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }
}

struct CommandsView: View {
    var onHome: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow
    @Environment(EditorEvents.self) private var editorEvents
    @Query private var commands: [SavedCommand]
    @AppStorage("didSeedSamples") private var didSeedSamples = false
    @AppStorage("sortOrder") private var sortOrder: CommandSort = .recentlyUsed

    @State private var sidebarSelection: SidebarItem? = .all
    @State private var selectedID: PersistentIdentifier?
    @State private var searchText = ""
    @State private var pendingDelete: SavedCommand?
    @State private var toaster = Toaster()

    var body: some View {
        // Filtering and sorting run once per update; every column below reuses the results.
        let visible = filteredCommands
        let selected = selectedCommand
        NavigationSplitView {
            SidebarView(commands: commands, selection: $sidebarSelection)
        } content: {
            commandList(visible)
        } detail: {
            detail(selected)
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search commands")
        .focusedSceneValue(\.commandActions, CommandActionHandler(selected: selected) { action in
            perform(action, on: selected)
        })
        .onChange(of: editorEvents.addedCommandID) {
            if let command = editorEvents.addedCommandID.flatMap(command(with:)) { reveal(command) }
        }
        .confirmationDialog(
            "Delete “\(pendingDelete?.title ?? "")”?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { command in
            Button("Delete", role: .destructive) { delete(command) }
        } message: { _ in
            Text("This command and its saved values will be removed. This can’t be undone.")
        }
        .toast(toaster)
        .onChange(of: searchText) {
            if !searchText.isEmpty { selectedID = filteredCommands.first?.persistentModelID }
        }
        .onChange(of: sidebarSelection) { keepSelectionVisible() }
        .task {
            if !didSeedSamples {
                if commands.isEmpty {
                    SampleData.insert(into: context)
                    try? context.save()
                }
                didSeedSamples = true
            }
            keepSelectionVisible()
        }
    }

    // MARK: - Columns

    private func commandList(_ visible: [SavedCommand]) -> some View {
        List(visible, selection: $selectedID) { command in
            CommandRow(command: command)
                .help("Double-click to copy")
        }
        .contextMenu(forSelectionType: PersistentIdentifier.self) { ids in
            if let command = ids.first.flatMap(command(with:)) {
                Button("Copy to Clipboard", systemImage: "doc.on.doc") { perform(.copy, on: command) }
                Divider()
                Button("Edit…", systemImage: "pencil") { perform(.edit, on: command) }
                Button("Duplicate", systemImage: "plus.square.on.square") { perform(.duplicate, on: command) }
                Button(
                    command.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: command.isFavorite ? "star.slash" : "star"
                ) { perform(.toggleFavorite, on: command) }
                Divider()
                Button("Delete…", systemImage: "trash", role: .destructive) { perform(.delete, on: command) }
            }
        } primaryAction: { ids in
            // Double-click copies, since that's what you open the app to do.
            if let command = ids.first.flatMap(command(with:)) { perform(.copy, on: command) }
        }
        .onDeleteCommand { perform(.delete, on: selectedCommand) }
        .overlay { emptyListState(isEmpty: visible.isEmpty) }
        .navigationTitle(listTitle)
        .navigationSubtitle(Text("\(visible.count) commands"))
        .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 420)
        .toolbar {
            HomeToolbarButton(action: onHome)
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Picker("Sort By", selection: $sortOrder) {
                        ForEach(CommandSort.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .help("Sort commands")

                Button("New Command", systemImage: "plus") { perform(.new, on: nil) }
                    .help("New Command (⌘N)")
            }
        }
    }

    @ViewBuilder
    private func detail(_ selected: SavedCommand?) -> some View {
        if let selected {
            CommandDetailView(
                command: selected,
                onCopy: { perform(.copy, on: selected) },
                onEdit: { perform(.edit, on: selected) }
            )
        } else if !commands.isEmpty {
            ContentUnavailableView(
                "No Command Selected",
                systemImage: "terminal",
                description: Text("Pick a command from the list to fill it in and copy it. Double-click a command to copy it right away, or press ⌘N to add one.")
            )
        }
    }

    @ViewBuilder
    private func emptyListState(isEmpty: Bool) -> some View {
        if commands.isEmpty {
            ContentUnavailableView {
                Label("No Commands Yet", systemImage: "terminal")
            } description: {
                Text("Save the commands you use often, then search and copy them in seconds.")
            } actions: {
                Button("New Command") { perform(.new, on: nil) }
                    .buttonStyle(.borderedProminent)
            }
        } else if isEmpty {
            if !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if sidebarSelection == .favorites {
                ContentUnavailableView(
                    "No Favorites",
                    systemImage: "star",
                    description: Text("Click the star on a command, or press ⇧⌘F, to keep it here.")
                )
            }
        }
    }

    // MARK: - Data

    private var listTitle: String {
        switch sidebarSelection ?? .all {
        case .all: String(localized: "All Commands")
        case .favorites: String(localized: "Favorites")
        case .tag(let tag): tag
        }
    }

    private var filteredCommands: [SavedCommand] {
        commands
            .filter { command in
                switch sidebarSelection ?? .all {
                case .all: true
                case .favorites: command.isFavorite
                case .tag(let tag): command.tags.contains(tag)
                }
            }
            .filter { $0.matches(searchText) }
            .sorted(by: sortOrder.areInIncreasingOrder)
    }

    private var selectedCommand: SavedCommand? {
        selectedID.flatMap(command(with:))
    }

    private func command(with id: PersistentIdentifier) -> SavedCommand? {
        commands.first { $0.persistentModelID == id }
    }

    // MARK: - Actions

    private func perform(_ action: CommandAction, on command: SavedCommand?) {
        if action == .new {
            openWindow(id: EditorTarget.windowID, value: EditorTarget.new)
            return
        }
        guard let command else { return }
        switch action {
        case .new:
            break
        case .copy:
            copy(command)
        case .edit:
            openWindow(id: EditorTarget.windowID, value: EditorTarget.edit(command.persistentModelID))
        case .duplicate:
            let copy = command.duplicate()
            context.insert(copy)
            try? context.save()
            reveal(copy)
        case .toggleFavorite:
            command.isFavorite.toggle()
        case .delete:
            pendingDelete = command
        }
    }

    private func copy(_ command: SavedCommand) {
        let resolved = command.resolve()
        Clipboard.copy(resolved.rendered)
        command.useCount += 1
        command.lastUsed = .now

        let missing = resolved.missing
        if missing.isEmpty {
            toaster.show("Copied to Clipboard")
        } else {
            toaster.show(
                "Copied, but \(missing.map { "<\($0)>" }.joined(separator: ", ")) is still empty",
                style: .warning
            )
        }
    }

    private func delete(_ command: SavedCommand) {
        let visible = filteredCommands
        if command.persistentModelID == selectedID, let index = visible.firstIndex(of: command) {
            let neighbor = visible.indices.contains(index + 1) ? visible[index + 1] : (index > 0 ? visible[index - 1] : nil)
            selectedID = neighbor?.persistentModelID
        }
        context.delete(command)
        pendingDelete = nil
    }

    /// Selects `command`, clearing filters that would hide it.
    private func reveal(_ command: SavedCommand) {
        if !filteredCommands.contains(command) {
            searchText = ""
            sidebarSelection = .all
        }
        selectedID = command.persistentModelID
    }

    private func keepSelectionVisible() {
        let visible = filteredCommands
        if !visible.contains(where: { $0.persistentModelID == selectedID }) {
            selectedID = visible.first?.persistentModelID
        }
    }
}

private struct SidebarView: View {
    let commands: [SavedCommand]
    @Binding var selection: SidebarItem?

    var body: some View {
        // Count everything in one pass over the commands.
        var favorites = 0
        var tagCounts: [String: Int] = [:]
        for command in commands {
            if command.isFavorite { favorites += 1 }
            for tag in command.tags { tagCounts[tag, default: 0] += 1 }
        }
        let tags = tagCounts.keys.sorted()

        return List(selection: $selection) {
            Section("Library") {
                Label("All Commands", systemImage: "terminal")
                    .badge(commands.count)
                    .tag(SidebarItem.all)
                Label("Favorites", systemImage: "star")
                    .badge(favorites)
                    .tag(SidebarItem.favorites)
            }
            if !tags.isEmpty {
                Section("Tags") {
                    ForEach(tags, id: \.self) { tag in
                        Label(tag, systemImage: "tag")
                            .badge(tagCounts[tag, default: 0])
                            .tag(SidebarItem.tag(tag))
                    }
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 170, ideal: 200, max: 280)
        .onChange(of: tags) {
            // The selected tag was removed from every command.
            if case .tag(let tag) = selection, !tags.contains(tag) { selection = .all }
        }
    }
}

private struct CommandRow: View {
    let command: SavedCommand

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(command.title)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if command.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("Favorite")
                }
            }
            Text(command.resolve().preview)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            if !command.tags.isEmpty {
                Text(command.tags.map { "#\($0)" }.joined(separator: "  "))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    CommandsView()
        .modelContainer(for: SavedCommand.self, inMemory: true)
        .environment(EditorEvents())
}
