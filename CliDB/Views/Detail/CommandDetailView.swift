import SwiftUI

struct CommandDetailView: View {
    @Bindable var command: SavedCommand
    var onCopy: () -> Void
    var onEdit: () -> Void

    var body: some View {
        let resolved = command.resolve()
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                commandSection(resolved)
                if !resolved.parameters.isEmpty {
                    parametersSection(resolved.parameters)
                }
                if !command.notes.isEmpty {
                    notesSection
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    command.isFavorite.toggle()
                } label: {
                    Label(
                        command.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                        systemImage: command.isFavorite ? "star.fill" : "star"
                    )
                }
                .help(command.isFavorite ? "Remove from Favorites (⇧⌘F)" : "Add to Favorites (⇧⌘F)")

                Button("Edit", systemImage: "pencil", action: onEdit)
                    .help("Edit Command (⌘E)")
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(command.title)
                    .font(.title.weight(.semibold))
                    .textSelection(.enabled)
                if command.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("Favorite")
                }
            }
            usageText
                .font(.callout)
                .foregroundStyle(.secondary)
            if !command.tags.isEmpty {
                FlowLayout {
                    ForEach(command.tags, id: \.self) { tag in
                        Chip(text: tag, systemImage: "tag")
                    }
                }
            }
        }
    }

    private func commandSection(_ resolved: ResolvedCommand) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HighlightedCommand(template: resolved.template, values: resolved.values)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
                .accessibilityLabel("Command: \(resolved.rendered)")

            HStack(spacing: 12) {
                Button(action: onCopy) {
                    Label("Copy Command", systemImage: "doc.on.doc")
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: .command)
                .help("Copy to Clipboard (⌘↩)")

                let missing = resolved.missing
                if !missing.isEmpty {
                    Label("Fill in \(missing.joined(separator: ", "))", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func parametersSection(_ parameters: [TemplateParameter]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Parameters").font(.headline)
                Spacer()
                Button("Reset to Defaults") { command.lastValues = [:] }
                    .buttonStyle(.link)
                    .disabled(command.lastValues.values.allSatisfy(\.isEmpty))
            }
            GroupBox {
                ParameterFormView(parameters: parameters, command: command)
                    .padding(8)
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes").font(.headline)
            // Rendered as Markdown so links and `code` work.
            Text(LocalizedStringKey(command.notes))
                .textSelection(.enabled)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var usageText: Text {
        guard let lastUsed = command.lastUsed else { return Text("Never used") }
        let times = command.useCount == 1 ? "once" : "\(command.useCount) times"
        return Text("Used \(times) · Last used \(lastUsed, format: .relative(presentation: .named))")
    }
}
