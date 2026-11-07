import SwiftUI

/// Tag entry: type and press Return (or a comma) to add, click a suggestion to reuse an existing tag.
/// `text` is owned by the caller so text that was typed but not yet added can still be saved.
struct TagField: View {
    @Binding var tags: [String]
    @Binding var text: String
    let suggestions: [String]

    @FocusState private var isFocused: Bool

    private var matchingSuggestions: [String] {
        let query = Self.normalize(text)
        return Array(
            suggestions
                .filter { !tags.contains($0) && (query.isEmpty || $0.hasPrefix(query)) }
                .prefix(8)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Tags", text: $text, prompt: Text("Type a tag and press Return"))
                .focused($isFocused)
                .onSubmit(commit)
                .onChange(of: text) {
                    if text.contains(",") { commit() }
                }
                .onChange(of: isFocused) {
                    if !isFocused { commit() }
                }

            if !tags.isEmpty {
                FlowLayout {
                    ForEach(tags, id: \.self) { tag in
                        Chip(text: tag, systemImage: "tag", style: .accent) {
                            tags.removeAll { $0 == tag }
                        }
                    }
                }
            }

            if !matchingSuggestions.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Suggestions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FlowLayout {
                        ForEach(matchingSuggestions, id: \.self) { suggestion in
                            Button {
                                tags = Self.adding(suggestion, to: tags)
                                text = ""
                            } label: {
                                Chip(text: suggestion, systemImage: "plus")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add tag \(suggestion)")
                        }
                    }
                }
            }
        }
    }

    private func commit() {
        tags = Self.adding(text, to: tags)
        text = ""
    }

    /// Adds each comma-separated tag in `raw` to `tags`, normalized and without duplicates.
    static func adding(_ raw: String, to tags: [String]) -> [String] {
        var result = tags
        for part in raw.split(separator: ",") {
            let tag = normalize(String(part))
            if !tag.isEmpty, !result.contains(tag) {
                result.append(tag)
            }
        }
        return result
    }

    /// Tags are lowercase with dashes instead of spaces, so "Docker Compose" and "docker-compose" match.
    private static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespaces)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: "-")
    }
}
