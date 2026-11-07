import SwiftUI

/// Shows a template with its placeholders filled in. Filled values are tinted and
/// unfilled ones appear as orange `<name>`.
struct HighlightedCommand: View {
    let template: String
    let values: [String: String]

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
                    missing.foregroundColor = .orange
                    result += missing
                } else {
                    var filled = AttributedString(value)
                    filled.foregroundColor = .accentColor
                    filled.backgroundColor = Color.accentColor.opacity(0.12)
                    result += filled
                }
            }
        }
        return result
    }
}
