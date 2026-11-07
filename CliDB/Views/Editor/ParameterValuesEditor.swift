import SwiftUI

/// Edits the list of values a parameter can be filled with.
/// `newValue` is owned by the caller so a value that was typed but not yet added can still be saved.
struct ParameterValuesEditor: View {
    let parameter: TemplateParameter
    @Binding var values: [String]
    @Binding var newValue: String

    @Environment(\.sectionAccent) private var accent
    @FocusState private var isFocused: Bool

    var body: some View {
        let inlineChoices = parameter.choices.filter { !values.contains($0) }
        VStack(alignment: .leading, spacing: 8) {
            Text(parameter.name)
                .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)

            if !inlineChoices.isEmpty || !values.isEmpty {
                FlowLayout(spacing: 6) {
                    // Choices written in the template itself can only be changed there.
                    ForEach(inlineChoices, id: \.self) { choice in
                        Chip(text: choice, systemImage: "lock.fill", monospaced: true)
                            .help("Written in the command, edit it there")
                    }
                    ForEach(values, id: \.self) { value in
                        Chip(text: value, monospaced: true, tint: accent) {
                            withAnimation(Theme.motion(.ui)) { values.removeAll { $0 == value } }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }

            HStack(spacing: 8) {
                FieldBox(monospaced: true) {
                    TextField("New value", text: $newValue, prompt: Text("Add a value for \(parameter.name)"))
                        .labelsHidden()
                        .focused($isFocused)
                        .onSubmit(add)
                        .onChange(of: isFocused) {
                            if !isFocused { add() }
                        }
                }
                Button(action: add) {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(PillButtonStyle(kind: .secondary))
                .disabled(newValue.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(12)
        .background(Theme.raised.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.stroke))
    }

    private func add() {
        withAnimation(Theme.motion(.lively)) {
            values = Self.adding(newValue, to: values, for: parameter)
        }
        newValue = ""
    }

    /// Adds `raw` to `values` unless it's empty or already a value or inline choice.
    static func adding(_ raw: String, to values: [String], for parameter: TemplateParameter) -> [String] {
        let value = TemplateParser.normalizingPunctuation(raw.trimmingCharacters(in: .whitespaces))
        guard !value.isEmpty, !values.contains(value), !parameter.choices.contains(value) else { return values }
        return values + [value]
    }
}
