import SwiftUI
import SwiftData

/// What an editor window is editing. Opening the same target twice brings its window to the front.
enum EditorTarget: Codable, Hashable {
    case new
    case edit(PersistentIdentifier)

    static let windowID = "editor"
}

/// Lets editor windows tell the main window about a newly added command so it can select it.
@MainActor
@Observable
final class EditorEvents {
    var addedCommandID: PersistentIdentifier?
}

struct CommandEditorWindow: View {
    let target: EditorTarget

    @Environment(\.modelContext) private var context

    var body: some View {
        switch target {
        case .new:
            CommandEditorView(command: nil)
        case .edit(let id):
            if let command = fetchCommand(id) {
                CommandEditorView(command: command)
            } else {
                ContentUnavailableView(
                    "Command Not Found",
                    systemImage: "questionmark.circle",
                    description: Text("It may have been deleted.")
                )
                .frame(minWidth: 320, minHeight: 200)
            }
        }
    }

    private func fetchCommand(_ id: PersistentIdentifier) -> SavedCommand? {
        var descriptor = FetchDescriptor<SavedCommand>(predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
