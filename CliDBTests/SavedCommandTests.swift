import Foundation
import SwiftData
import Testing
@testable import Pocketknife

@MainActor
struct SavedCommandTests {
    @Test func editedTagsPersist() throws {
        let container = try ModelContainer(
            for: SavedCommand.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let command = SavedCommand(title: "List", template: "ls", tags: ["shell"])
        container.mainContext.insert(command)
        try container.mainContext.save()

        command.tags = ["shell", "files"]
        try container.mainContext.save()

        let freshContext = ModelContext(container)
        let fetched = try freshContext.fetch(FetchDescriptor<SavedCommand>())
        #expect(fetched.first?.tags == ["shell", "files"])
    }

    @Test func addingTagNormalizesAndSkipsDuplicates() {
        #expect(TagField.adding("Docker Compose", to: ["git"]) == ["git", "docker-compose"])
        #expect(TagField.adding("a, B ,a", to: []) == ["a", "b"])
        #expect(TagField.adding("git", to: ["git"]) == ["git"])
        #expect(TagField.adding("   ", to: ["git"]) == ["git"])
    }

    @Test func addingParameterValueSkipsInlineChoices() {
        let parameter = TemplateParameter(name: "env", defaultValue: nil, choices: ["dev"])
        #expect(ParameterValuesEditor.adding("dev", to: [], for: parameter) == [])
        #expect(ParameterValuesEditor.adding(" prod ", to: [], for: parameter) == ["prod"])
    }
}
