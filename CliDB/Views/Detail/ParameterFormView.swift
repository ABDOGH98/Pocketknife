import SwiftUI

/// Fields for filling in a command's parameters. Values are stored on the command,
/// so they're kept between launches and used by Copy from anywhere in the app.
struct ParameterFormView: View {
    let parameters: [TemplateParameter]
    @Bindable var command: SavedCommand

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
            ForEach(parameters) { parameter in
                GridRow {
                    Text(parameter.name)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    ParameterField(parameter: parameter, command: command)
                }
            }
        }
    }
}

private struct ParameterField: View {
    let parameter: TemplateParameter
    @Bindable var command: SavedCommand

    private var value: Binding<String> {
        Binding(
            get: { command.lastValues[parameter.name] ?? "" },
            set: { command.lastValues[parameter.name] = $0 }
        )
    }

    var body: some View {
        let current = value.wrappedValue
        let effective = current.isEmpty ? parameter.fallbackValue : current

        HStack(spacing: 6) {
            TextField(parameter.name, text: value, prompt: parameter.fallbackValue.isEmpty ? Text("Type a value") : Text("Default: \(parameter.fallbackValue)"))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            if !parameter.choices.isEmpty {
                Menu {
                    ForEach(parameter.choices, id: \.self) { choice in
                        Button {
                            value.wrappedValue = choice
                        } label: {
                            if choice == effective {
                                Label(choice, systemImage: "checkmark")
                            } else {
                                Text(choice)
                            }
                        }
                    }
                } label: {
                    Label {
                        Text("\(parameter.choices.count) choices")
                    } icon: {
                        Image(systemName: "list.bullet")
                    }
                }
                .menuStyle(.button)
                .buttonStyle(.bordered)
                .fixedSize()
                .help("Pick a saved choice for \(parameter.name)")
                .accessibilityLabel("Choices for \(parameter.name)")
            }

            if !current.isEmpty, !parameter.choices.contains(current) {
                Button {
                    command.parameterValues[parameter.name, default: []].append(current)
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
                .help("Save “\(current)” as a choice for \(parameter.name), so you can pick it next time")
                .accessibilityLabel("Save as a choice")
            }
        }
    }
}
