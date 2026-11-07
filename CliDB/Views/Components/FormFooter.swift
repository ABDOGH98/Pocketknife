import SwiftUI

/// The bottom bar shared by every editor: what's still needed on the left, Cancel and the
/// main action on the right. Keeping it identical everywhere means people learn it once.
struct FormFooter: View {
    /// What's still missing before the form can be saved, or nil when it's ready.
    let missing: String?
    let saveTitle: LocalizedStringResource
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let missing {
                    Label(missing, systemImage: "info.circle")  // already localized by the caller
                        .foregroundStyle(.secondary)
                } else {
                    Label("Ready to save", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .font(.callout)
            .contentTransition(.opacity)
            .animation(.snappy, value: missing)

            Spacer()

            Button("Cancel", role: .cancel, action: onCancel)
                .keyboardShortcut(.cancelAction)
                .help("Close without saving (Esc)")

            Button(action: onSave) {
                Text(saveTitle).frame(minWidth: 56)
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
            .disabled(missing != nil)
            .help(Text(verbatim: "\(String(localized: saveTitle)) (⌘↩)"))
        }
        .controlSize(.large)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

/// A short explanation under a form section, styled the same everywhere.
struct FormHint: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
