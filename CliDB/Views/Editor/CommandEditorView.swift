import SwiftUI
import SwiftData

/// Creates a new command when `command` is nil, otherwise edits it. Shown in its own window.
struct CommandEditorView: View {
    let command: SavedCommand?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(EditorEvents.self) private var editorEvents
    @Query private var allCommands: [SavedCommand]

    private struct Draft: Equatable {
        var title = ""
        var template = ""
        var notes = ""
        var tags: [String] = []
        var isFavorite = false
        var parameterValues: [String: [String]] = [:]
        // Text typed into the tag and value fields but not yet added with Return.
        var pendingTag = ""
        var pendingValues: [String: String] = [:]
    }

    private enum Field: Hashable {
        case title, template
    }

    @State private var draft = Draft()
    @State private var original = Draft()
    @State private var templateSelection: TextSelection?
    @State private var isInsertingParameter = false
    @State private var isConfirmingDiscard = false
    @FocusState private var focusedField: Field?

    private var detectedParameters: [TemplateParameter] {
        TemplateParser.parameters(in: draft.template)
    }

    private var existingTags: [String] {
        Set(allCommands.flatMap(\.tags)).sorted()
    }

    private var hasChanges: Bool { draft != original }

    private var validationMessage: String? {
        if draft.title.trimmingCharacters(in: .whitespaces).isEmpty { return String(localized: "Give the command a name") }
        if draft.template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return String(localized: "Type the command itself") }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Form {
                Section {
                    TextField("Name", text: $draft.title, prompt: Text("e.g. Kill process on port"))
                        .focused($focusedField, equals: .title)
                        .onSubmit { focusedField = .template }
                } header: {
                    Text("Name")
                } footer: {
                    FormHint("A short description you’ll recognize when searching.")
                }

                templateSection

                if !detectedParameters.isEmpty {
                    Section {
                        ForEach(detectedParameters) { parameter in
                            ParameterValuesEditor(
                                parameter: parameter,
                                values: Binding(
                                    get: { draft.parameterValues[parameter.name, default: []] },
                                    set: { draft.parameterValues[parameter.name] = $0 }
                                ),
                                newValue: Binding(
                                    get: { draft.pendingValues[parameter.name, default: ""] },
                                    set: { draft.pendingValues[parameter.name] = $0 }
                                )
                            )
                        }
                    } header: {
                        Text("Choices (optional)")
                    } footer: {
                        FormHint("Saved choices appear in a menu next to each blank, so you can pick instead of typing.")
                    }
                }

                Section {
                    TagField(tags: $draft.tags, text: $draft.pendingTag, suggestions: existingTags)
                    Toggle("Favorite", isOn: $draft.isFavorite)
                } header: {
                    Text("Organize")
                } footer: {
                    FormHint("Tags group commands in the sidebar. Favorites get their own list.")
                }

                Section {
                    TextEditor(text: $draft.notes)
                        .frame(minHeight: 44)
                        .accessibilityLabel("Notes")
                        .overlay(alignment: .topLeading) {
                            if draft.notes.isEmpty {
                                Text("When to use it, gotchas, links…")
                                    .foregroundStyle(.tertiary)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                } header: {
                    Text("Notes (optional)")
                } footer: {
                    FormHint("Markdown works: **bold**, `code` and links.")
                }
            }
            .formStyle(.grouped)

            FormFooter(
                missing: validationMessage,
                saveTitle: command == nil ? "Add Command" : "Save",
                onCancel: cancel,
                onSave: save
            )
        }
        .frame(minWidth: 440, idealWidth: 500, minHeight: 420, idealHeight: 620)
        .navigationTitle(command == nil ? "New Command" : "Edit “\(original.title)”")
        .onAppear {
            load()
            focusedField = command == nil ? .title : nil
        }
        .confirmationDialog("Discard changes?", isPresented: $isConfirmingDiscard) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text(command == nil ? "This command hasn’t been added yet." : "Your edits to this command will be lost.")
        }
    }

    private var templateSection: some View {
        Section {
            TextEditor(text: $draft.template, selection: $templateSelection)
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
                .frame(minHeight: 60)
                .focused($focusedField, equals: .template)
                .accessibilityLabel("Command template")
                // Shell commands read left to right even when the app is in Arabic.
                .environment(\.layoutDirection, .leftToRight)
                .overlay(alignment: .topLeading) {
                    if draft.template.isEmpty {
                        Text("e.g. lsof -ti :{{port:3000}} | xargs kill -9")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
        } header: {
            HStack {
                Text("Command")
                Spacer()
                Button {
                    isInsertingParameter = true
                } label: {
                    Label("Insert Blank…", systemImage: "curlybraces")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Add a part you fill in each time, like a port or a branch name, at the cursor")
                .popover(isPresented: $isInsertingParameter, arrowEdge: .bottom) {
                    InsertParameterView { snippet in
                        insert(snippet)
                        isInsertingParameter = false
                    }
                }
            }
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if TemplateParser.hasUnclosedPlaceholder(in: draft.template) {
                    Label("A placeholder isn’t closed. Check your {{ and }}.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else if !detectedParameters.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Preview")
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        HighlightedCommand(
                            template: TemplateParser.normalizingPunctuation(draft.template),
                            values: Dictionary(uniqueKeysWithValues: detectedParameters.map { ($0.name, $0.fallbackValue) })
                        )
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(2)
                    }
                    .accessibilityElement(children: .combine)
                    let names = detectedParameters.map(\.name).joined(separator: ", ")
                    Text("You’ll fill in \(names) each time you copy it.")
                        .foregroundStyle(.secondary)
                } else {
                    PlaceholderCheatSheet()
                }
            }
            .font(.caption)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "terminal.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                Text(command == nil ? "New Command" : "Edit Command")
                    .font(.headline)
                Text(command == nil ? String(localized: "Save a command once, then fill in the blanks and copy it any time.") : original.title)
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

    // MARK: - Actions

    private func load() {
        if let command {
            draft = Draft(
                title: command.title,
                template: command.template,
                notes: command.notes,
                tags: command.tags,
                isFavorite: command.isFavorite,
                parameterValues: command.parameterValues
            )
        }
        original = draft
    }

    private func cancel() {
        if hasChanges {
            isConfirmingDiscard = true
        } else {
            dismiss()
        }
    }

    /// Inserts `snippet` at the cursor, or appends it when the editor has no cursor.
    private func insert(_ snippet: String) {
        if case .selection(let range)? = templateSelection?.indices,
           range.upperBound <= draft.template.endIndex {
            draft.template.replaceSubrange(range, with: snippet)
        } else {
            if !draft.template.isEmpty, !draft.template.hasSuffix(" ") { draft.template += " " }
            draft.template += snippet
        }
        templateSelection = nil
        focusedField = .template
    }

    private func save() {
        let title = draft.title.trimmingCharacters(in: .whitespaces)
        let template = TemplateParser.normalizingPunctuation(draft.template.trimmingCharacters(in: .whitespacesAndNewlines))
        // Include anything typed but not yet added with Return.
        let tags = TagField.adding(draft.pendingTag, to: draft.tags)
        var parameterValues: [String: [String]] = [:]
        for parameter in TemplateParser.parameters(in: template) {
            let values = ParameterValuesEditor.adding(
                draft.pendingValues[parameter.name, default: ""],
                to: draft.parameterValues[parameter.name, default: []],
                for: parameter
            )
            if !values.isEmpty { parameterValues[parameter.name] = values }
        }

        let target = command ?? SavedCommand(title: title, template: template)
        target.title = title
        target.template = template
        target.notes = draft.notes
        target.tags = tags
        target.isFavorite = draft.isFavorite
        target.parameterValues = parameterValues
        if command == nil {
            context.insert(target)
        }
        // Saving gives a new command its permanent ID before it's selected.
        try? context.save()
        if command == nil {
            editorEvents.addedCommandID = target.persistentModelID
        }
        dismiss()
    }
}

/// Builds a placeholder from a name, default and list without having to remember the syntax.
private struct InsertParameterView: View {
    var onInsert: (String) -> Void

    @State private var name = ""
    @State private var defaultValue = ""
    @State private var choices = ""

    private var cleanedName: String {
        name.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")
            .filter { !"{}:|".contains($0) }
    }

    private var snippet: String {
        let defaultPart = defaultValue.filter { !"{}|".contains($0) }.trimmingCharacters(in: .whitespaces)
        let choiceList = choices
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).filter { !"{}".contains($0) } }
            .filter { !$0.isEmpty }
        var result = "{{" + (cleanedName.isEmpty ? "name" : cleanedName)
        if !defaultPart.isEmpty { result += ":" + defaultPart }
        if !choiceList.isEmpty { result += "|" + choiceList.joined(separator: ",") }
        return result + "}}"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Insert a Blank").font(.headline)
                Text("A part of the command you fill in each time you copy it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("port"))
                } footer: {
                    Text("What you’re asked to fill in, like port or branch.")
                }
                Section {
                    TextField("Default", text: $defaultValue, prompt: Text("Optional"))
                } footer: {
                    Text("Used when you leave the value empty.")
                }
                Section {
                    TextField("Choices", text: $choices, prompt: Text("Optional, e.g. dev, staging, prod"))
                } footer: {
                    Text("Choices to pick from a menu, separated by commas.")
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text(snippet)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Insert") { onInsert(snippet) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(cleanedName.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 340)
    }
}

/// Shown under an empty template so the placeholder syntax can be learned at a glance
/// instead of remembered from the docs.
private struct PlaceholderCheatSheet: View {
    private let rows: [(syntax: String, meaning: LocalizedStringKey)] = [
        ("{{port}}", "a value you type each time"),
        ("{{port:3000}}", "with a default"),
        ("{{env|dev,prod}}", "pick from a list"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Wrap the parts that change in double curly braces:")
                .foregroundStyle(.secondary)
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 2) {
                ForEach(rows, id: \.syntax) { row in
                    GridRow {
                        Text(verbatim: row.syntax)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.primary)
                        Text(row.meaning)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
