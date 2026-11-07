import Foundation
import Synchronization

/// A placeholder found in a command template.
///
/// Supported syntax:
/// - `{{name}}`               required value
/// - `{{name:default}}`       pre-filled default
/// - `{{name|a,b,c}}`         pick from a list of choices
/// - `{{name:b|a,b,c}}`       choices with a default
struct TemplateParameter: Equatable, Identifiable, Sendable {
    let name: String
    let defaultValue: String?
    let choices: [String]

    var id: String { name }

    /// The value used when the user hasn't entered anything.
    var fallbackValue: String { defaultValue ?? choices.first ?? "" }

    /// Appends `extra` to `choices`, skipping duplicates.
    func addingChoices(_ extra: [String]) -> TemplateParameter {
        var merged = choices
        for value in extra where !merged.contains(value) {
            merged.append(value)
        }
        return TemplateParameter(name: name, defaultValue: defaultValue, choices: merged)
    }
}

enum TemplateSegment: Equatable, Sendable {
    case text(String)
    case placeholder(TemplateParameter)
}

enum TemplateParser {
    /// Parsed templates, keyed by template text. Views ask for the same few templates on every
    /// redraw, so this turns repeated parsing into a dictionary lookup.
    private static let cache = Mutex<[String: [TemplateSegment]]>([:])
    private static let cacheLimit = 512

    /// Splits a template into literal text and placeholders, in order.
    static func segments(in template: String) -> [TemplateSegment] {
        if let cached = cache.withLock({ $0[template] }) {
            return cached
        }
        let parsed = parse(template)
        cache.withLock { cache in
            if cache.count >= cacheLimit { cache.removeAll(keepingCapacity: true) }
            cache[template] = parsed
        }
        return parsed
    }

    /// Hand-written scanner; much faster than `Regex` for this simple grammar.
    private static func parse(_ template: String) -> [TemplateSegment] {
        var result: [TemplateSegment] = []
        var textStart = template.startIndex
        var searchFrom = template.startIndex
        while let open = template[searchFrom...].firstRange(of: "{{") {
            guard let close = template[open.upperBound...].firstRange(of: "}}") else { break }
            if let parameter = makeParameter(from: template[open.upperBound..<close.lowerBound]) {
                if textStart < open.lowerBound {
                    result.append(.text(String(template[textStart..<open.lowerBound])))
                }
                result.append(.placeholder(parameter))
                textStart = close.upperBound
                searchFrom = close.upperBound
            } else {
                // Not a valid placeholder (e.g. `{{{x}}}`); retry one character later.
                searchFrom = template.index(after: open.lowerBound)
            }
        }
        if textStart < template.endIndex {
            result.append(.text(String(template[textStart...])))
        }
        return result
    }

    /// Unique parameters in order of first appearance.
    static func parameters(in template: String) -> [TemplateParameter] {
        var seen = Set<String>()
        return segments(in: template).compactMap { segment in
            guard case .placeholder(let parameter) = segment, seen.insert(parameter.name).inserted else { return nil }
            return parameter
        }
    }

    /// Replaces every placeholder with its value from `values`, falling back to the default.
    static func render(_ template: String, values: [String: String]) -> String {
        segments(in: template).map { segment in
            switch segment {
            case .text(let text):
                return text
            case .placeholder(let parameter):
                if let value = values[parameter.name], !value.isEmpty {
                    return value
                }
                return parameter.fallbackValue
            }
        }.joined()
    }

    /// True when the template contains a `{{` that doesn't form a valid placeholder.
    static func hasUnclosedPlaceholder(in template: String) -> Bool {
        let opened = template.components(separatedBy: "{{").count - 1
        let parsed = segments(in: template).filter { if case .placeholder = $0 { true } else { false } }.count
        return opened > parsed
    }

    /// Undoes macOS smart quotes and dashes, which break shell commands.
    static func normalizingPunctuation(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2014}", with: "--")
            .replacingOccurrences(of: "\u{2013}", with: "-")
    }

    /// Parses the text between `{{` and `}}`: `name`, `name:default`, `name|a,b` or `name:default|a,b`.
    private static func makeParameter(from inner: Substring) -> TemplateParameter? {
        guard !inner.contains(where: { $0 == "{" || $0 == "}" }) else { return nil }

        let separator = inner.firstIndex { $0 == ":" || $0 == "|" }
        let name = (separator.map { inner[..<$0] } ?? inner).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        var defaultValue: String?
        var choicesText: Substring?
        if let separator {
            let rest = inner[inner.index(after: separator)...]
            if inner[separator] == ":" {
                let bar = rest.firstIndex(of: "|")
                defaultValue = (bar.map { rest[..<$0] } ?? rest).trimmingCharacters(in: .whitespacesAndNewlines)
                choicesText = bar.map { rest[rest.index(after: $0)...] }
            } else {
                choicesText = rest
            }
        }
        let choices = choicesText?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        return TemplateParameter(name: name, defaultValue: defaultValue, choices: choices)
    }
}
