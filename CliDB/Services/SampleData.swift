import SwiftData

@MainActor
enum SampleData {
    static func insert(into context: ModelContext) {
        let samples = [
            SavedCommand(
                title: "Kill process on port",
                template: "lsof -ti :{{port:3000}} | xargs kill -9",
                tags: ["network", "process"]
            ),
            SavedCommand(
                title: "Shell into Docker container",
                template: "docker exec -it {{container}} /bin/{{shell:bash|bash,sh,zsh}}",
                tags: ["docker"]
            ),
            SavedCommand(
                title: "Follow pod logs",
                template: "kubectl -n {{namespace:default}} logs -f {{pod}}",
                tags: ["kubernetes"]
            ),
            SavedCommand(
                title: "New git branch",
                template: "git checkout -b {{type|feature,fix,chore}}/{{name}}",
                tags: ["git"]
            ),
        ]
        samples.forEach(context.insert)
    }
}
