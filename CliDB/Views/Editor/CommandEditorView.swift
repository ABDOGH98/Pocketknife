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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        IconTile(systemImage: command == nil ? "plus" : "pencil", tint: Theme.mint, size: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(command == nil ? "New Command" : "Edit Command")
                                .font(.system(size: 18, weight: .bold))
                            Text("Use {{name}} for the parts you fill in each time.")
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    FieldBox(label: String(localized: "Title")) {
                        TextField("Title", text: $draft.title, prompt: Text("Kill process on port"))
                            .focused($focusedField, equals: .title)
                    }

                    templateSection

                    if !detectedParameters.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: String(localized: "Values to pick from"), systemImage: "list.bullet.rectangle")
                            Text("Optional. Saved values show up as chips you can click when filling in the command.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textTertiary)
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
                        .card(padding: 16)
                        .transition(.opacity.combined(with: .offset(y: 6)))
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        TagField(tags: $draft.tags, text: $draft.pendingTag, suggestions: existingTags)
                        Rectangle().fill(Theme.stroke).frame(height: 1)
                        Toggle(isOn: $draft.isFavorite.animation(Theme.motion(.lively))) {
                            Label("Favorite", systemImage: draft.isFavorite ? "star.fill" : "star")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(draft.isFavorite ? Theme.gold : Theme.text)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .toggleStyle(.switch)
                    }
                    .card(padding: 16)

                    FieldBox(label: String(localized: "Notes"), hint: String(localized: "Optional · Markdown")) {
                        TextField("Notes", text: $draft.notes, prompt: Text("What it does, when to use it"), axis: .vertical)
                            .lineLimit(2...6)
                            .padding(.vertical, 9)
                    }
                }
                .padding(20)
                .animation(Theme.motion(.ui), value: detectedParameters.isEmpty)
            }
            .scrollContentBackground(.hidden)

            Rectangle().fill(Theme.stroke).frame(height: 1)
            footer
        }
        .background(Theme.canvas)
        .environment(\.sectionAccent, Theme.mint)
        .tint(Theme.mint)
        .frame(minWidth: 460, idealWidth: 520, minHeight: 420, idealHeight: 620)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                FieldLabel(String(localized: "Command"))
                Spacer()
                Button {
                    isInsertingParameter = true
                } label: {
                    Label("Insert Parameter", systemImage: "curlybraces")
                }
                .buttonStyle(PillButtonStyle(kind: .secondary, size: .small))
                .help("Insert {{name}}, {{name:default}} or {{name|a,b,c}} at the cursor")
                .popover(isPresented: $isInsertingParameter, arrowEdge: .bottom) {
                    InsertParameterView { snippet in
                        insert(snippet)
                        isInsertingParameter = false
                    }
                }
            }

            TextEditor(text: $draft.template, selection: $templateSelection)
                .font(.system(size: 13.5, design: .monospaced))
                .autocorrectionDisabled()
                .scrollContentBackground(.hidden)
                .frame(minHeight: 64)
                .padding(8)
                .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(focusedField == .template ? Theme.mint.opacity(0.7) : Theme.stroke, lineWidth: focusedField == .template ? 1.5 : 1)
                )
                .focused($focusedField, equals: .template)
                .environment(\.layoutDirection, .leftToRight)
                .accessibilityLabel("Command template")

            Group {
                if TemplateParser.hasUnclosedPlaceholder(in: draft.template) {
                    Label("A placeholder isn’t closed. Check your {{ and }}.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.warning)
                } else if !detectedParameters.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Preview")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.textTertiary)
                        HighlightedCommand(
                            template: TemplateParser.normalizingPunctuation(draft.template),
                            values: Dictionary(uniqueKeysWithValues: detectedParameters.map { ($0.name, $0.fallbackValue) })
                        )
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(2)
                        .accessibilityLabel("Preview")
                    }
                } else {
                    Label("Tip: write {{name}} for a value you fill in each time, or use Insert Parameter.", systemImage: "lightbulb.fill")
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .font(.system(size: 12))
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if let validationMessage {
                Label(validationMessage, systemImage: "info.circle")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button("Cancel", role: .cancel, action: cancel)
                .keyboardShortcut(.cancelAction)
                .buttonStyle(PillButtonStyle(kind: .ghost))
            Button(action: save) {
                HStack(spacing: 8) {
                    Text(command == nil ? "Add Command" : "Save")
                    KeyHint(keys: "⌘↩", onAccent: true)
                }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(PillButtonStyle(kind: .primary))
            .disabled(validationMessage != nil)
        }
        .padding(16)
        .background(Theme.surface)
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
            Text("Insert Parameter")
                .font(.system(size: 15, weight: .bold))
            FieldBox(label: String(localized: "Name")) {
                TextField("Name", text: $name, prompt: Text("port"))
            }
            FieldBox(label: String(localized: "Default"), hint: String(localized: "Optional")) {
                TextField("Default", text: $defaultValue, prompt: Text("3000"))
            }
            FieldBox(label: String(localized: "Values"), hint: String(localized: "Optional, comma-separated")) {
                TextField("Values", text: $choices, prompt: Text("3000, 8080"))
            }
            Text(snippet)
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(Theme.mint)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 9))
            Button {
                onInsert(snippet)
            } label: {
                Label("Insert", systemImage: "arrow.down.to.line")
            }
            .buttonStyle(PillButtonStyle(kind: .primary, fullWidth: true))
            .keyboardShortcut(.defaultAction)
            .disabled(cleanedName.isEmpty)
        }
        .padding(16)
        .frame(width: 320)
        .environment(\.sectionAccent, Theme.mint)
    }
}
