import SwiftUI

/// A collapsible row for editing the list of values a parameter can be filled with.
/// `newValue` is owned by the caller so a value that was typed but not yet added can still be saved.
struct ParameterValuesEditor: View {
    let parameter: TemplateParameter
    @Binding var values: [String]
    @Binding var newValue: String

    @State private var isExpanded = false
    @FocusState private var isFocused: Bool

    private var summary: String {
        let count = parameter.addingChoices(values).choices.count
        switch count {
        case 0: return "No values"
        case 1: return "1 value"
        default: return "\(count) values"
        }
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                let inlineChoices = parameter.choices.filter { !values.contains($0) }
                if !inlineChoices.isEmpty || !values.isEmpty {
                    FlowLayout {
                        // Choices written in the template itself can only be changed there.
                        ForEach(inlineChoices, id: \.self) { choice in
                            Chip(text: choice, monospaced: true)
                                .help("Defined in the template")
                        }
                        ForEach(values, id: \.self) { value in
                            Chip(text: value, monospaced: true, style: .accent) {
                                values.removeAll { $0 == value }
                            }
                        }
                    }
                }

                HStack {
                    TextField("New value", text: $newValue, prompt: Text("Add a value"))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .focused($isFocused)
                        .onSubmit(add)
                        .onChange(of: isFocused) {
                            if !isFocused { add() }
                        }
                    Button("Add", action: add)
                        .disabled(newValue.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(.top, 4)
        } label: {
            HStack {
                Text(parameter.name)
                    .font(.system(.body, design: .monospaced))
                Spacer()
                Text(summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func add() {
        values = Self.adding(newValue, to: values, for: parameter)
        newValue = ""
    }

    /// Adds `raw` to `values` unless it's empty or already a value or inline choice.
    static func adding(_ raw: String, to values: [String], for parameter: TemplateParameter) -> [String] {
        let value = TemplateParser.normalizingPunctuation(raw.trimmingCharacters(in: .whitespaces))
        guard !value.isEmpty, !values.contains(value), !parameter.choices.contains(value) else { return values }
        return values + [value]
    }
}
