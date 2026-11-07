import Testing
@testable import Pocketknife

struct TemplateParserTests {
    @Test func parsesPlainParameter() {
        let parameters = TemplateParser.parameters(in: "ssh {{host}}")
        #expect(parameters == [TemplateParameter(name: "host", defaultValue: nil, choices: [])])
    }

    @Test func parsesDefaultValue() {
        let parameters = TemplateParser.parameters(in: "lsof -ti :{{port:3000}}")
        #expect(parameters.first?.defaultValue == "3000")
    }

    @Test func parsesChoicesWithAndWithoutDefault() {
        let parameters = TemplateParser.parameters(in: "{{env|dev, staging ,prod}} {{shell:zsh|bash,zsh}}")
        #expect(parameters[0].choices == ["dev", "staging", "prod"])
        #expect(parameters[0].fallbackValue == "dev")
        #expect(parameters[1].defaultValue == "zsh")
        #expect(parameters[1].choices == ["bash", "zsh"])
    }

    @Test func deduplicatesRepeatedParameters() {
        let parameters = TemplateParser.parameters(in: "cp {{file}} {{file}}.bak && echo {{dest}}")
        #expect(parameters.map(\.name) == ["file", "dest"])
    }

    @Test func toleratesWhitespaceInsideBraces() {
        let parameters = TemplateParser.parameters(in: "echo {{ name : World }}")
        #expect(parameters.first?.name == "name")
        #expect(parameters.first?.defaultValue == "World")
    }

    @Test func rendersValuesAndFallbacks() {
        let template = "docker exec -it {{container}} /bin/{{shell:bash}} # {{container}}"
        let rendered = TemplateParser.render(template, values: ["container": "web"])
        #expect(rendered == "docker exec -it web /bin/bash # web")
    }

    @Test func emptyValueFallsBackToDefault() {
        let rendered = TemplateParser.render("kill {{port:3000}}", values: ["port": ""])
        #expect(rendered == "kill 3000")
    }

    @Test func mergesSavedValuesAfterInlineChoices() {
        let parameter = TemplateParameter(name: "env", defaultValue: nil, choices: ["dev", "prod"])
            .addingChoices(["prod", "staging"])
        #expect(parameter.choices == ["dev", "prod", "staging"])
        #expect(parameter.fallbackValue == "dev")
    }

    @Test func savedValuesBecomeChoicesForPlainParameter() {
        let parameter = TemplateParameter(name: "host", defaultValue: nil, choices: [])
            .addingChoices(["web-1", "web-2"])
        #expect(parameter.choices == ["web-1", "web-2"])
        #expect(parameter.fallbackValue == "web-1")
    }

    @Test func splitsTemplateIntoSegments() {
        let segments = TemplateParser.segments(in: "ssh {{user:root}}@{{host}}")
        #expect(segments == [
            .text("ssh "),
            .placeholder(TemplateParameter(name: "user", defaultValue: "root", choices: [])),
            .text("@"),
            .placeholder(TemplateParameter(name: "host", defaultValue: nil, choices: [])),
        ])
    }

    @Test func detectsUnclosedPlaceholder() {
        #expect(TemplateParser.hasUnclosedPlaceholder(in: "echo {{name"))
        #expect(!TemplateParser.hasUnclosedPlaceholder(in: "echo {{name}}"))
    }

    @Test func normalizesSmartPunctuation() {
        let typed = "echo \u{201C}hi\u{201D} \u{2018}x\u{2019} \u{2014}force"
        #expect(TemplateParser.normalizingPunctuation(typed) == "echo \"hi\" 'x' --force")
    }

    @Test func handlesBraceEdgeCasesLikeTheOriginalRegex() {
        #expect(TemplateParser.render("{{{x}}}", values: ["x": "1"]) == "{1}")
        #expect(TemplateParser.render("{{a{{b}}", values: ["b": "2"]) == "{{a2")
        #expect(TemplateParser.parameters(in: "{{ }} {{:x}} {{|a}}").isEmpty)
        #expect(TemplateParser.parameters(in: "{{env:dev|dev,prod}}").first?.choices == ["dev", "prod"])
    }

    @Test func leavesTemplateWithoutPlaceholdersUntouched() {
        let template = "echo ${HOME} && awk '{print $1}'"
        #expect(TemplateParser.parameters(in: template).isEmpty)
        #expect(TemplateParser.render(template, values: [:]) == template)
    }
}
