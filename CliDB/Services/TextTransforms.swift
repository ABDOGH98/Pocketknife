import Foundation

struct TransformError: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}

/// Pure text conversions used by the Utilities section.
enum TextTransforms {
    // MARK: JSON

    /// Re-indents JSON without reordering keys or rewriting numbers.
    static func formatJSON(_ input: String, indent: String = "  ") throws -> String {
        try validateJSON(input)
        return reindentJSON(input, indent: indent)
    }

    static func minifyJSON(_ input: String) throws -> String {
        try validateJSON(input)
        return reindentJSON(input, indent: nil)
    }

    private static func validateJSON(_ input: String) throws {
        let data = Data(input.utf8)
        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            let detail = (error as NSError).userInfo[NSDebugDescriptionErrorKey] as? String
            throw TransformError(message: detail.map { String(localized: "Invalid JSON: \($0)") } ?? String(localized: "Invalid JSON."))
        }
    }

    /// Walks already-valid JSON and rewrites the whitespace between tokens.
    /// A `nil` indent produces minified output.
    private static func reindentJSON(_ input: String, indent: String?) -> String {
        let chars = Array(input)
        var output = ""
        output.reserveCapacity(chars.count)
        var depth = 0
        var inString = false
        var escaped = false

        func newline() {
            guard let indent else { return }
            output.append("\n")
            output.append(String(repeating: indent, count: depth))
        }

        var i = 0
        while i < chars.count {
            let c = chars[i]
            defer { i += 1 }

            if inString {
                output.append(c)
                if escaped { escaped = false }
                else if c == "\\" { escaped = true }
                else if c == "\"" { inString = false }
                continue
            }

            switch c {
            case "\"":
                inString = true
                output.append(c)
            case "{", "[":
                output.append(c)
                // Keep empty containers on one line: {} and [].
                var j = i + 1
                while j < chars.count, chars[j].isWhitespace { j += 1 }
                if j < chars.count, chars[j] == "}" || chars[j] == "]" {
                    output.append(chars[j])
                    i = j
                } else {
                    depth += 1
                    newline()
                }
            case "}", "]":
                depth -= 1
                newline()
                output.append(c)
            case ",":
                output.append(c)
                newline()
            case ":":
                output.append(indent == nil ? ":" : ": ")
            case _ where c.isWhitespace:
                break
            default:
                output.append(c)
            }
        }
        return output
    }

    // MARK: XML

    static func formatXML(_ input: String) throws -> String {
        try serializeXML(parseXML(input), input: input, options: [.nodePrettyPrint, .nodeCompactEmptyElement])
    }

    static func minifyXML(_ input: String) throws -> String {
        let document = try parseXML(input)
        if let root = document.rootElement() { removeWhitespaceText(in: root) }
        return serializeXML(document, input: input, options: [.nodeCompactEmptyElement])
    }

    /// Only includes an `<?xml …?>` declaration when the input had one.
    private static func serializeXML(_ document: XMLDocument, input: String, options: XMLNode.Options) -> String {
        let hasDeclaration = input.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<?xml")
        guard !hasDeclaration, let root = document.rootElement() else {
            return document.xmlString(options: options)
        }
        return root.xmlString(options: options)
    }

    /// Drops the indentation-only text nodes left over from pretty-printed input.
    private static func removeWhitespaceText(in element: XMLElement) {
        for child in (element.children ?? []).reversed() {
            if child.kind == .text,
               child.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                element.removeChild(at: child.index)
            } else if let childElement = child as? XMLElement {
                removeWhitespaceText(in: childElement)
            }
        }
    }

    private static func parseXML(_ input: String) throws -> XMLDocument {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TransformError(message: String(localized: "Invalid XML: the document is empty."))
        }
        do {
            // Never fetch external entities or DTDs referenced by pasted XML.
            return try XMLDocument(xmlString: input, options: [.nodeLoadExternalEntitiesNever])
        } catch {
            throw TransformError(message: String(localized: "Invalid XML: \(error.localizedDescription)"))
        }
    }

    // MARK: Base64

    static func encodeBase64(_ input: String, urlSafe: Bool = false) -> String {
        let encoded = Data(input.utf8).base64EncodedString()
        guard urlSafe else { return encoded }
        return encoded
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Decodes standard or URL-safe Base64, ignoring whitespace and missing padding.
    static func decodeBase64(_ input: String) throws -> String {
        var normalized = String(input.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) })
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        if remainder != 0 { normalized += String(repeating: "=", count: 4 - remainder) }

        guard let data = Data(base64Encoded: normalized) else {
            throw TransformError(message: String(localized: "Invalid Base64: the input contains characters or padding that can’t be decoded."))
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw TransformError(message: String(localized: "Decoded \(data.count) bytes, but they aren’t UTF-8 text."))
        }
        return text
    }

    // MARK: JWT

    /// Decodes a JWT into its header, payload and signature. The signature is shown, never verified.
    static func decodeJWT(_ input: String, now: Date = Date()) throws -> String {
        var token = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if token.range(of: "bearer ", options: [.caseInsensitive, .anchored]) != nil {
            token = String(token.dropFirst("bearer ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let parts = token.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3 else {
            throw TransformError(message: String(localized: "Invalid JWT: expected 3 dot-separated parts, found \(parts.count)."))
        }

        let header = try decodeJWTSegment(parts[0], name: String(localized: "header", comment: "Part of a JWT"))
        let payload = try decodeJWTSegment(parts[1], name: String(localized: "payload", comment: "Part of a JWT"))

        var sections = [
            String(localized: "Header") + "\n" + (try formatJSON(header)),
            String(localized: "Payload") + "\n" + (try formatJSON(payload)),
        ]
        if let claims = jwtTimeClaims(payload: payload, now: now) {
            sections.append(String(localized: "Time claims") + "\n" + claims)
        }
        let signature = parts[2].isEmpty
            ? String(localized: "(none — unsecured token)")
            : parts[2] + "\n" + String(localized: "(not verified)")
        sections.append(String(localized: "Signature") + "\n" + signature)
        return sections.joined(separator: "\n\n")
    }

    private static func decodeJWTSegment(_ segment: String, name: String) throws -> String {
        let text: String
        do {
            text = try decodeBase64(segment)
        } catch let error as TransformError {
            throw TransformError(message: String(localized: "Invalid JWT \(name): \(error.message)"))
        }
        do {
            try validateJSON(text)
        } catch {
            throw TransformError(message: String(localized: "Invalid JWT \(name): it isn’t valid JSON."))
        }
        return text
    }

    /// Lists `iat`, `nbf` and `exp` as UTC dates, flagging whether the token is expired.
    private static func jwtTimeClaims(payload: String, now: Date) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any] else { return nil }
        let formatter = ISO8601DateFormatter()
        var lines: [String] = []
        let claims = [
            ("iat", String(localized: "Issued at")),
            ("nbf", String(localized: "Not before")),
            ("exp", String(localized: "Expires")),
        ]
        // Pad to the longest label so the dates line up in every language.
        let width = claims.map(\.1.count).max() ?? 10
        for (key, label) in claims {
            guard let seconds = (object[key] as? NSNumber)?.doubleValue else { continue }
            let date = Date(timeIntervalSince1970: seconds)
            var line = "\(label.padding(toLength: width, withPad: " ", startingAt: 0))  \(formatter.string(from: date))"
            if key == "exp" { line += "  " + (date < now ? String(localized: "(expired)") : String(localized: "(valid)")) }
            if key == "nbf", date > now { line += "  " + String(localized: "(not yet valid)") }
            lines.append(line)
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}
