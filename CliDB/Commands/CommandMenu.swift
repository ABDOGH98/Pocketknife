import SwiftUI

enum CommandAction {
    case new, copy, edit, duplicate, toggleFavorite, delete
}

/// Published by the main window so the menu bar can act on the selected command.
struct CommandActionHandler {
    let selected: SavedCommand?
    let perform: @MainActor (CommandAction) -> Void
}

extension FocusedValues {
    @Entry var commandActions: CommandActionHandler?
    /// Published by the Passwords section so ⌘N adds a password there.
    @Entry var newPasswordAction: NewPasswordAction?
}

struct NewPasswordAction {
    let perform: @MainActor () -> Void
}

struct CommandMenuCommands: Commands {
    @FocusedValue(\.commandActions) private var actions
    @FocusedValue(\.newPasswordAction) private var newPassword
    @FocusedValue(\.sectionNavigation) private var navigation

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            if let newPassword {
                Button("New Password") { newPassword.perform() }
                    .keyboardShortcut("n")
            } else {
                Button("New Command") { actions?.perform(.new) }
                    .keyboardShortcut("n")
                    .disabled(actions == nil)
            }
        }

        CommandMenu("Go") {
            Button("Home") { navigation?.go(nil) }
                .keyboardShortcut("0")
                .disabled(navigation == nil || navigation?.current == nil)
            Button("CLI Commands") { navigation?.go(.commands) }
                .keyboardShortcut("1")
                .disabled(navigation == nil || navigation?.current == .commands)
            Button("Passwords") { navigation?.go(.passwords) }
                .keyboardShortcut("2")
                .disabled(navigation == nil || navigation?.current == .passwords)
            Button("Utilities") { navigation?.go(.utils) }
                .keyboardShortcut("3")
                .disabled(navigation == nil || navigation?.current == .utils)
        }

        CommandMenu("Command") {
            let selected = actions?.selected
            Button("Copy to Clipboard") { actions?.perform(.copy) }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(selected == nil)
            Divider()
            Button("Edit…") { actions?.perform(.edit) }
                .keyboardShortcut("e")
                .disabled(selected == nil)
            Button("Duplicate") { actions?.perform(.duplicate) }
                .keyboardShortcut("d")
                .disabled(selected == nil)
            Button(selected?.isFavorite == true ? "Remove from Favorites" : "Add to Favorites") {
                actions?.perform(.toggleFavorite)
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(selected == nil)
            Divider()
            Button("Delete…") { actions?.perform(.delete) }
                .keyboardShortcut(.delete)
                .disabled(selected == nil)
        }
    }
}
