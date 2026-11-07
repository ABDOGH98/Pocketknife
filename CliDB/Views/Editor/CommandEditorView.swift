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
        if draft.title.trimmingCharacters(in: .whitespaces).isEmpty { return "Add a title" }
        if draft.template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Add a command" }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Title", text: $draft.title, prompt: Text("Kill process on port"))
                        .focused($focusedField, equals: .title)
                }

                templateSection

                if !detectedParameters.isEmpty {
                    Section("Parameter Values") {
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
                    }
                }

                Section {
                    TagField(tags: $draft.tags, text: $draft.pendingTag, suggestions: existingTags)
                    Toggle("Favorite", isOn: $draft.isFavorite)
                }

                Section("Notes") {
                    TextEditor(text: $draft.notes)
                        .frame(minHeight: 36)
                        .accessibilityLabel("Notes")
                }
            }
            .formStyle(.grouped)

            Divider()
            footer
        }
        .frame(minWidth: 420, idealWidth: 480, minHeight: 380, idealHeight: 540)
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
                .frame(minHeight: 52)
                .focused($focusedField, equals: .template)
                .accessibilityLabel("Command template")
        } header: {
            HStack {
                Text("Command")
                Spacer()
                Button {
                    isInsertingParameter = true
                } label: {
                    Label("Insert Parameter", systemImage: "curlybraces")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Insert {{name}}, {{name:default}} or {{name|a,b,c}} at the cursor")
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
                    HighlightedCommand(
                        template: TemplateParser.normalizingPunctuation(draft.template),
                        values: Dictionary(uniqueKeysWithValues: detectedParameters.map { ($0.name, $0.fallbackValue) })
                    )
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(2)
                    .accessibilityLabel("Preview")
                } else {
                    Text("Tip: use `{{name}}` for a value you fill in each time.")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
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
            Button("Cancel", role: .cancel, action: cancel)
                .keyboardShortcut(.cancelAction)
            Button(command == nil ? "Add" : "Save", action: save)
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(validationMessage != nil)
                .help("⌘↩")
        }
        .padding(12)
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
            Text("Insert Parameter").font(.headline)
            Form {
                TextField("Name", text: $name, prompt: Text("port"))
                TextField("Default", text: $defaultValue, prompt: Text("Optional"))
                TextField("Values", text: $choices, prompt: Text("Optional, comma-separated"))
            }
            HStack {
                Text(snippet)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Insert") { onInsert(snippet) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(cleanedName.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}
