import SwiftUI
import SwiftData

enum AppSection: Hashable {
    case commands, passwords, utils
}

/// Opens on the home screen; picking a card switches the window to that section.
struct ContentView: View {
    @State private var section: AppSection?

    var body: some View {
        Group {
            switch section {
            case nil:
                HomeView { section = $0 }
            case .commands:
                CommandsView(onHome: goHome)
            case .passwords:
                PasswordsView(onHome: goHome)
            case .utils:
                UtilsView(onHome: goHome)
            }
        }
        .focusedSceneValue(\.sectionNavigation, SectionNavigation(current: section) { section = $0 })
    }

    private func goHome() { section = nil }
}

/// Lets the Go menu switch sections in the main window.
struct SectionNavigation {
    let current: AppSection?
    let go: @MainActor (AppSection?) -> Void
}

extension FocusedValues {
    @Entry var sectionNavigation: SectionNavigation?
}

/// A toolbar button that returns to the home screen.
struct HomeToolbarButton: ToolbarContent {
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button("Home", systemImage: "square.grid.2x2", action: action)
                .help("Back to Home (⌘0)")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SavedCommand.self, SavedPassword.self], inMemory: true)
        .environment(EditorEvents())
}
