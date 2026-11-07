import SwiftUI
import SwiftData

@main
struct PocketknifeApp: App {
    // One container shared by every window, so edits show up everywhere immediately.
    private let container: ModelContainer
    @State private var editorEvents = EditorEvents()

    init() {
        do {
            container = try ModelContainer(for: SavedCommand.self, SavedPassword.self)
        } catch {
            fatalError("Couldn't open the command database: \(error)")
        }
    }

    var body: some Scene {
        Window("Pocketknife", id: "main") {
            ContentView()
                .frame(minWidth: 900, minHeight: 560)
                .containerBackground(Theme.canvas, for: .window)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 740)
        .commands { CommandMenuCommands() }
        .modelContainer(container)
        .environment(editorEvents)

        WindowGroup("Command", id: EditorTarget.windowID, for: EditorTarget.self) { $target in
            if let target {
                CommandEditorWindow(target: target)
                    .containerBackground(Theme.canvas, for: .window)
            }
        }
        .defaultSize(width: 480, height: 540)
        .defaultPosition(.center)
        .windowResizability(.contentMinSize)
        .restorationBehavior(.disabled)
        .modelContainer(container)
        .environment(editorEvents)

        WindowGroup("Output", id: ExpandedOutput.windowID, for: ExpandedOutput.self) { $output in
            if let output {
                OutputWindow(output: output)
                    .containerBackground(Theme.canvas, for: .window)
            }
        }
        .defaultSize(width: 1000, height: 720)
        .defaultPosition(.center)
        .restorationBehavior(.disabled)
    }
}
