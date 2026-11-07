import Foundation
import SwiftData

@Model
final class SavedCommand {
    var title: String = ""
    var template: String = ""
    var notes: String = ""
    var tags: [String] = []
    var isFavorite: Bool = false
    var useCount: Int = 0
    var lastUsed: Date?
    var createdAt: Date = Date.now
    /// Values currently entered for each parameter; empty means "use the default".
    var lastValues: [String: String] = [:]
    /// Saved values to pick from for each parameter, in addition to inline `{{name|a,b}}` choices.
    var parameterValues: [String: [String]] = [:]

    init(title: String, template: String, notes: String = "", tags: [String] = []) {
        self.title = title
        self.template = template
        self.notes = notes
        self.tags = tags
    }

    /// Parameters in the template, with their saved values merged into `choices`.
    var parameters: [TemplateParameter] {
        TemplateParser.parameters(in: template).map { $0.addingChoices(parameterValues[$0.name] ?? []) }
    }

    /// Everything views need to show or copy this command, computed in one pass.
    func resolve() -> ResolvedCommand {
        ResolvedCommand(template: template, parameters: parameters, enteredValues: lastValues)
    }

    /// Every whitespace-separated word in `query` must appear in the title, template, notes or tags.
    func matches(_ query: String) -> Bool {
        let words = query.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return true }
        let haystack = ([title, template, notes] + tags).joined(separator: " ")
        return words.allSatisfy { haystack.localizedCaseInsensitiveContains($0) }
    }

    func duplicate() -> SavedCommand {
        let copy = SavedCommand(title: String(localized: "\(title) Copy", comment: "Title of a duplicated command"), template: template, notes: notes, tags: tags)
        copy.parameterValues = parameterValues
        copy.lastValues = lastValues
        return copy
    }
}

/// A command's parameters and the values they'll be filled with.
struct ResolvedCommand {
    let template: String
    let parameters: [TemplateParameter]
    /// Each parameter's value: what the user entered, else its default. Empty if neither.
    let values: [String: String]

    init(template: String, parameters: [TemplateParameter], enteredValues: [String: String]) {
        self.template = template
        self.parameters = parameters
        self.values = Dictionary(uniqueKeysWithValues: parameters.map { parameter in
            let entered = enteredValues[parameter.name] ?? ""
            return (parameter.name, entered.isEmpty ? parameter.fallbackValue : entered)
        })
    }

    var rendered: String {
        TemplateParser.render(template, values: values)
    }

    /// The command with empty parameters shown as `<name>`, for display.
    var preview: String {
        TemplateParser.segments(in: template).map { segment in
            switch segment {
            case .text(let text): text
            case .placeholder(let parameter): values[parameter.name].flatMap { $0.isEmpty ? nil : $0 } ?? "<\(parameter.name)>"
            }
        }.joined()
    }

    /// Parameters that have neither a value nor a default.
    var missing: [String] {
        parameters.map(\.name).filter { values[$0, default: ""].isEmpty }
    }
}
