import SwiftUI

/// Shows a template with its placeholders filled in. Filled values are tinted with the accent
/// and unfilled ones appear as amber `<name>`.
struct HighlightedCommand: View {
    let template: String
    let values: [String: String]
    var accent: Color = Theme.mint

    var body: some View {
        Text(attributed)
    }

    private var attributed: AttributedString {
        var result = AttributedString()
        for segment in TemplateParser.segments(in: template) {
            switch segment {
            case .text(let text):
                result += AttributedString(text)
            case .placeholder(let parameter):
                let value = values[parameter.name] ?? ""
                if value.isEmpty {
                    var missing = AttributedString("<\(parameter.name)>")
                    missing.foregroundColor = Theme.warning
                    missing.backgroundColor = Theme.warning.opacity(0.14)
                    result += missing
                } else {
                    var filled = AttributedString(value)
                    filled.foregroundColor = accent
                    filled.backgroundColor = accent.opacity(0.14)
                    result += filled
                }
            }
        }
        return result
    }
}
