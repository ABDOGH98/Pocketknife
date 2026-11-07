import SwiftUI
import SwiftData

enum CommandFilter: Hashable {
    case all
    case favorites
    case tag(String)
}

enum CommandSort: String, CaseIterable, Identifiable {
    case recentlyUsed, mostUsed, name, dateAdded

    var id: Self { self }

    var title: String {
        switch self {
        case .recentlyUsed: String(localized: "Recently Used")
        case .mostUsed: String(localized: "Most Used")
        case .name: String(localized: "Name")
        case .dateAdded: String(localized: "Date Added")
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

extension SavedCommand {
    /// Copies the finished command, counts it as a use, and returns the parameters that are still empty.
    @MainActor
    @discardableResult
    func copyToClipboard() -> [String] {
        let resolved = resolve()
        Clipboard.copy(resolved.rendered)
        useCount += 1
        lastUsed = .now
        return resolved.missing
    }
}

struct CommandsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow
    @Environment(EditorEvents.self) private var editorEvents
    @Query private var commands: [SavedCommand]
    @AppStorage("didSeedSamples") private var didSeedSamples = false
    @AppStorage("sortOrder") private var sortOrder: CommandSort = .recentlyUsed

    @State private var filter: CommandFilter = .all
    @State private var selectedID: PersistentIdentifier?
    @State private var searchText = ""
    @State private var pendingDelete: SavedCommand?
    @State private var toaster = Toaster()
    @FocusState private var isSearchFocused: Bool
    @FocusState private var isListFocused: Bool

    var body: some View {
        // Filtering and sorting run once per update; both panes reuse the results.
        let visible = filteredCommands
        let selected = selectedCommand
        HStack(spacing: 0) {
            listPane(visible)
                .frame(width: 350)
            Rectangle().fill(Theme.stroke).frame(width: 1).ignoresSafeArea()
            detailPane(selected)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Commands")
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
        .onChange(of: filter) { keepSelectionVisible() }
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

    // MARK: - List pane

    private func listPane(_ visible: [SavedCommand]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Commands")
                        .font(.system(size: 22, weight: .bold))
                    Text("^[\(visible.count) command](inflect: true)")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .contentTransition(.numericText())
                }
                Spacer()
                Button {
                    perform(.new, on: nil)
                } label: {
                    HStack(spacing: 8) {
                        Label("New", systemImage: "plus")
                        KeyHint(keys: "⌘N", onAccent: true)
                    }
                }
                .buttonStyle(PillButtonStyle(kind: .primary))
                .help("New Command (⌘N)")
            }

            SearchField(
                text: $searchText,
                prompt: String(localized: "Search commands"),
                focus: $isSearchFocused,
                onSubmit: { perform(.copy, on: selectedCommand) },
                onMove: { moveSelection(by: $0, in: visible) }
            )

            filterChips

            HStack {
                Text("Sort by")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                Menu {
                    Picker("Sort By", selection: $sortOrder) {
                        ForEach(CommandSort.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } label: {
                    Label(sortOrder.title, systemImage: "arrow.up.arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .pillMenuStyle()
                .help("Change the order of the list")
                Spacer()
            }
            }
            .padding(.horizontal, 16)

            commandRows(visible)
        }
        .padding(.top, 10)
        .background(Theme.canvas)
    }

    private var filterChips: some View {
        // Count everything in one pass over the commands.
        var favorites = 0
        var tagCounts: [String: Int] = [:]
        for command in commands {
            if command.isFavorite { favorites += 1 }
            for tag in command.tags { tagCounts[tag, default: 0] += 1 }
        }
        let tags = tagCounts.keys.sorted()

        return FlowLayout(spacing: 6) {
            FilterChip(title: String(localized: "All"), systemImage: "square.stack.3d.up.fill", count: commands.count, isSelected: filter == .all) {
                setFilter(.all)
            }
            FilterChip(title: String(localized: "Favorites"), systemImage: "star.fill", count: favorites, tint: Theme.gold, isSelected: filter == .favorites) {
                setFilter(.favorites)
            }
            ForEach(tags, id: \.self) { tag in
                FilterChip(
                    title: tag,
                    systemImage: "number",
                    count: tagCounts[tag, default: 0],
                    tint: Theme.swatch(for: tag),
                    isSelected: filter == .tag(tag)
                ) {
                    setFilter(filter == .tag(tag) ? .all : .tag(tag))
                }
            }
        }
        .onChange(of: tags) {
            // The selected tag was removed from every command.
            if case .tag(let tag) = filter, !tags.contains(tag) { filter = .all }
        }
    }

    private func commandRows(_ visible: [SavedCommand]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(visible) { command in
                        CommandRow(
                            command: command,
                            isSelected: command.persistentModelID == selectedID,
                            onCopy: { perform(.copy, on: command) }
                        )
                        .id(command.persistentModelID)
                        .onTapGesture { select(command) }
                        // Double-click copies, since that's what you open the app to do.
                        .simultaneousGesture(TapGesture(count: 2).onEnded { perform(.copy, on: command) })
                        .contextMenu { contextMenu(for: command) }
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
        .onKeyPress(.return) {
            perform(.copy, on: selectedCommand)
            return .handled
        }
        .onDeleteCommand { perform(.delete, on: selectedCommand) }
        .overlay { emptyListState(isEmpty: visible.isEmpty) }
    }

    @ViewBuilder
    private func contextMenu(for command: SavedCommand) -> some View {
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

    @ViewBuilder
    private func emptyListState(isEmpty: Bool) -> some View {
        if commands.isEmpty {
            EmptyStateView(
                title: String(localized: "No commands yet"),
                message: String(localized: "Save the commands you use often, then search and copy them in seconds."),
                systemImage: "terminal"
            ) {
                Button { perform(.new, on: nil) } label: { Label("New Command", systemImage: "plus") }
                    .buttonStyle(PillButtonStyle(kind: .primary))
            }
        } else if isEmpty {
            if !searchText.isEmpty {
                EmptyStateView(
                    title: String(localized: "No results"),
                    message: String(localized: "Nothing matches “\(searchText)”. Try fewer words."),
                    systemImage: "magnifyingglass"
                ) {
                    Button("Clear Search") { searchText = "" }
                        .buttonStyle(PillButtonStyle(kind: .ghost))
                }
            } else if filter == .favorites {
                EmptyStateView(
                    title: String(localized: "No favorites"),
                    message: String(localized: "Click the star on a command to pin it here."),
                    systemImage: "star"
                )
                .environment(\.sectionAccent, Theme.gold)
            }
        }
    }

    // MARK: - Detail pane

    @ViewBuilder
    private func detailPane(_ selected: SavedCommand?) -> some View {
        if let selected {
            CommandDetailView(
                command: selected,
                onCopy: { perform(.copy, on: selected) },
                onEdit: { perform(.edit, on: selected) },
                onDuplicate: { perform(.duplicate, on: selected) },
                onDelete: { perform(.delete, on: selected) }
            )
            .id(selected.persistentModelID)
            .transition(.opacity.combined(with: .offset(x: 10)))
        } else if !commands.isEmpty {
            EmptyStateView(
                title: String(localized: "Pick a command"),
                message: String(localized: "Choose one from the list to fill it in and copy it."),
                systemImage: "hand.point.left.fill"
            )
        }
    }

    // MARK: - Data

    private var filteredCommands: [SavedCommand] {
        commands
            .filter { command in
                switch filter {
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

    private func select(_ command: SavedCommand) {
        withAnimation(Theme.motion(.ui)) { selectedID = command.persistentModelID }
        isListFocused = true
    }

    private func setFilter(_ newFilter: CommandFilter) {
        withAnimation(Theme.motion(.ui)) { filter = newFilter }
    }

    private func moveSelection(by offset: Int, in visible: [SavedCommand]) {
        guard !visible.isEmpty else { return }
        let current = visible.firstIndex { $0.persistentModelID == selectedID } ?? (offset > 0 ? -1 : visible.count)
        let next = min(max(current + offset, 0), visible.count - 1)
        withAnimation(Theme.motion(.ui)) { selectedID = visible[next].persistentModelID }
    }

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
            let missing = command.copyToClipboard()
            if missing.isEmpty {
                toaster.show(String(localized: "Copied to Clipboard"))
            } else {
                let names = missing.map { "<\($0)>" }.joined(separator: ", ")
                toaster.show(String(localized: "Copied — \(names) still empty"), kind: .warning)
            }
        case .edit:
            openWindow(id: EditorTarget.windowID, value: EditorTarget.edit(command.persistentModelID))
        case .duplicate:
            let copy = command.duplicate()
            context.insert(copy)
            try? context.save()
            reveal(copy)
            toaster.show(String(localized: "Duplicated"), kind: .info)
        case .toggleFavorite:
            withAnimation(Theme.motion(.lively)) { command.isFavorite.toggle() }
        case .delete:
            pendingDelete = command
        }
    }

    private func delete(_ command: SavedCommand) {
        let visible = filteredCommands
        if command.persistentModelID == selectedID, let index = visible.firstIndex(of: command) {
            let neighbor = visible.indices.contains(index + 1) ? visible[index + 1] : (index > 0 ? visible[index - 1] : nil)
            selectedID = neighbor?.persistentModelID
        }
        withAnimation(Theme.motion(.ui)) { context.delete(command) }
        pendingDelete = nil
    }

    /// Selects `command`, clearing filters that would hide it.
    private func reveal(_ command: SavedCommand) {
        if !filteredCommands.contains(command) {
            searchText = ""
            filter = .all
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

// MARK: - Row

private struct CommandRow: View {
    let command: SavedCommand
    let isSelected: Bool
    let onCopy: () -> Void

    @Environment(\.sectionAccent) private var accent
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(command.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    if command.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.gold)
                            .transition(.scale.combined(with: .opacity))
                            .accessibilityLabel("Favorite")
                    }
                }
                Text(command.resolve().preview)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if !command.tags.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(command.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(Theme.swatch(for: tag))
                        }
                        if command.tags.count > 3 {
                            Text("+\(command.tags.count - 3)")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                    .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if isHovered || isSelected {
                CopyButton(size: .small, action: onCopy)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(shape.fill(isSelected ? accent.opacity(0.13) : (isHovered ? Theme.raised : Theme.surface)))
        .overlay(shape.strokeBorder(isSelected ? accent.opacity(0.5) : Theme.stroke, lineWidth: isSelected ? 1.5 : 1))
        .overlay(alignment: .leading) {
            if isSelected {
                Capsule()
                    .fill(accent)
                    .frame(width: 3.5)
                    .padding(.vertical, 12)
                    .offset(x: 1)
                    .transition(.opacity.combined(with: .scale(scale: 0.5)))
            }
        }
        .contentShape(shape)
        .onHover { isHovered = $0 }
        .animation(.ui, value: isHovered)
        .animation(Theme.motion(.lively), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview {
    CommandsView()
        .modelContainer(for: SavedCommand.self, inMemory: true)
        .environment(EditorEvents())
}
