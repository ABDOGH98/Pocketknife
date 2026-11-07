import SwiftUI

/// Fields for filling in a command's parameters. Values are stored on the command,
/// so they're kept between launches and used by Copy from anywhere in the app.
struct ParameterFormView: View {
    let parameters: [TemplateParameter]
    @Bindable var command: SavedCommand

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(parameters.enumerated()), id: \.element.id) { index, parameter in
                if index > 0 {
                    Rectangle().fill(Theme.stroke).frame(height: 1).padding(.vertical, 14)
                }
                ParameterField(parameter: parameter, command: command)
            }
        }
    }
}

private struct ParameterField: View {
    let parameter: TemplateParameter
    @Bindable var command: SavedCommand

    @Environment(\.sectionAccent) private var accent

    private var value: Binding<String> {
        Binding(
            get: { command.lastValues[parameter.name] ?? "" },
            set: { command.lastValues[parameter.name] = $0 }
        )
    }

    var body: some View {
        let current = value.wrappedValue
        let effective = current.isEmpty ? parameter.fallbackValue : current
        let canSave = !current.isEmpty && !parameter.choices.contains(current)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(parameter.name)
                    .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 6))
                if parameter.fallbackValue.isEmpty {
                    if current.isEmpty {
                        Text("Required")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.warning)
                    }
                } else {
                    Text("Default: \(parameter.fallbackValue)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                FieldBox(monospaced: true) {
                    TextField(
                        parameter.name,
                        text: value,
                        prompt: Text(parameter.fallbackValue.isEmpty ? String(localized: "Type a value") : parameter.fallbackValue)
                            .foregroundStyle(Theme.textTertiary)
                    )
                    .labelsHidden()
                    .environment(\.layoutDirection, .leftToRight)
                }
                if canSave {
                    Button {
                        withAnimation(Theme.motion(.lively)) {
                            command.parameterValues[parameter.name, default: []].append(current)
                        }
                    } label: {
                        Label("Save value", systemImage: "plus")
                    }
                    .buttonStyle(PillButtonStyle(kind: .secondary))
                    .help("Keep “\(current)” as a value you can pick next time")
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .animation(Theme.motion(.lively), value: canSave)

            if !parameter.choices.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Pick:")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                    FlowLayout(spacing: 6) {
                        ForEach(parameter.choices, id: \.self) { choice in
                            FilterChip(title: choice, isSelected: choice == effective) {
                                withAnimation(Theme.motion(.ui)) { value.wrappedValue = choice }
                            }
                            .help("Use “\(choice)”")
                        }
                    }
                }
            }
        }
    }
}
