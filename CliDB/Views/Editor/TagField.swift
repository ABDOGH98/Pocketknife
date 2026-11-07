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
        VStack(alignment: .leading, spacing: 10) {
            FieldBox(label: String(localized: "Tags"), hint: String(localized: "Press Return or comma to add")) {
                TextField("Tags", text: $text, prompt: Text("docker, git, network…"))
                    .focused($isFocused)
                    .onSubmit(commit)
                    .onChange(of: text) {
                        if text.contains(",") { commit() }
                    }
                    .onChange(of: isFocused) {
                        if !isFocused { commit() }
                    }
            }

            if !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(tag: tag) {
                            withAnimation(Theme.motion(.ui)) { tags.removeAll { $0 == tag } }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }

            if !matchingSuggestions.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Add:")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                    FlowLayout(spacing: 6) {
                        ForEach(matchingSuggestions, id: \.self) { suggestion in
                            FilterChip(title: suggestion, systemImage: "plus", tint: Theme.swatch(for: suggestion), isSelected: false) {
                                withAnimation(Theme.motion(.lively)) { tags = Self.adding(suggestion, to: tags) }
                                text = ""
                            }
                            .accessibilityLabel("Add tag \(suggestion)")
                        }
                    }
                }
            }
        }
    }

    private func commit() {
        withAnimation(Theme.motion(.lively)) { tags = Self.adding(text, to: tags) }
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
