import Foundation
import Testing
@testable import ModKit

struct GameTemplatesTests {
    @Test func theTemplatesDescribeTheMacNativeGamesPorts() throws {
        let definitions = bundledTemplates.templates.map(\.definition)
        let ids = definitions.map(\.id)
        let identifiers = definitions.compactMap(\.bundleIdentifier)

        #expect(bundledTemplates.problems.isEmpty)
        #expect(Set(ids) == ["totk", "ot0", "botw", "odyssey", "by3", "ssbu", "acnh", "dread", "eow", "jamboree", "mvdk", "ori", "unicorn", "wonder", "aoc", "mk8d", "alc", "xc3"])
        #expect(Set(identifiers).count == identifiers.count)
        #expect(definitions.filter { $0.unsupportedReason == nil }.map(\.id).sorted() == ["ot0", "totk"])
        #expect(definitions.allSatisfy { if case .unsupported(let reason) = $0.mods { reason != nil } else { true } })
        let files = try FileManager.default.contentsOfDirectory(atPath: templatesFolder.path).filter { $0.hasSuffix(".json") }
        #expect(Set(files) == Set(ids.map { "\($0).json" }))
        #expect(definitions.allSatisfy { $0.template == nil })
    }

    @Test func everyTemplateIsAGameThatCanBeAdded() {
        for template in bundledTemplates.templates {
            let problems = GameDraft(definition: template.game(), origin: .template(template.id)).fieldProblems(in: GameCatalog(games: []))
            #expect(problems.isEmpty, "\(template.id): \(problems)")
        }
    }

    @Test func aTemplateIsFoundByAppIdentifierOrPortFolder() {
        #expect(bundledTemplates.template(bundleIdentifier: "org.macnativegames.totk")?.id == "totk")
        #expect(bundledTemplates.template(portFolder: "ot0")?.id == "ot0")
        #expect(bundledTemplates.template(bundleIdentifier: "com.example.other") == nil)
        #expect(bundledTemplates.template(id: "eow")?.definition.appFileName == nil)
        #expect(bundledTemplates.template(id: "ori")?.definition.appFileName == "Ori and the Blind Forest.app")
    }

    @Test func aGameAddedFromATemplateRemembersItsRevision() throws {
        let template = try #require(bundledTemplates.template(id: "totk"))
        #expect(template.game().template == GameDefinition.TemplateReference(id: "totk", revision: template.revision))
    }

    @Test func aUserTemplateReplacesTheBundledOneWithTheSameId() throws {
        let folder = try TemporaryFolder()
        var mine = ot0
        mine.name = "My Octopath"
        try JSONFile.encode(GameTemplate(revision: 7, definition: mine)).write(to: folder.url.appending(path: "mine.json"))

        let templates = GameTemplates.load(from: [templatesFolder, folder.url])

        #expect(templates.template(id: "ot0")?.definition.name == "My Octopath")
        #expect(templates.template(id: "ot0")?.revision == 7)
        #expect(templates.templates.count == bundledTemplates.templates.count)
    }

    @Test func anUnreadableTemplateIsReportedAndTheOthersStillLoad() throws {
        let folder = try TemporaryFolder()
        try folder.write("broken.json", "{")
        try JSONFile.encode(GameTemplate(definition: ot0)).write(to: folder.url.appending(path: "ot0.json"))

        let templates = GameTemplates.load(from: [folder.url])

        #expect(templates.templates.map(\.id) == ["ot0"])
        #expect(templates.problems.count == 1)
    }

    @Test func aNewerRevisionIsOfferedOnlyForGamesStartedFromThatTemplate() throws {
        let folder = try TemporaryFolder()
        try JSONFile.encode(GameTemplate(revision: 2, definition: ot0)).write(to: folder.url.appending(path: "ot0.json"))
        let templates = GameTemplates.load(from: [folder.url])
        var game = ot0

        #expect(templates.update(for: game) == nil)
        game.template = GameDefinition.TemplateReference(id: "ot0", revision: 1)
        #expect(templates.update(for: game)?.revision == 2)
        game.template = GameDefinition.TemplateReference(id: "ot0", revision: 2)
        #expect(templates.update(for: game) == nil)
    }
}
