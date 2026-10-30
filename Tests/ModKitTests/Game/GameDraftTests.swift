import Foundation
import Testing
@testable import ModKit

struct GameDraftTests {
    let folder: TemporaryFolder
    let macNativeGames: URL
    let noTemplates = GameTemplates(templates: [])
    let empty = GameCatalog(games: [])

    init() throws {
        folder = try TemporaryFolder()
        macNativeGames = folder.url.appending(path: "mng")
        try folder.write("mng/build_app.py")
        try folder.write("mng/games/myport/README.md", "# My Port — native macOS target\n\nText.\n")
        try folder.write("mng/games/myport/assets/expected-v1.0.0.json", #"{"title_id": "0100abcd12340000", "version": 0}"#)
        try folder.write("mng/games/myport/scripts/make_mod_manifest.py")
        try folder.write("mng/games/myport/app/launcher.m", #"NSString *data = [home stringByAppendingPathComponent:@"Library/Application Support/MacNativeGames/MYP"];"#)
        try folder.write("mng/games/myport/MyPort_build/venv/bin/python")
    }

    func app(_ identifier: String, name: String) throws -> String {
        try folder.app("Apps/\(name)", identifier: identifier, info: ["CFBundleName": name])
    }

    @Test func aNewGameIsFilledInFromItsAppAndItsPort() throws {
        let draft = GameDraft.make(app: try app("org.macnativegames.myport", name: "My Port"), portFolder: nil, macNativeGames: macNativeGames, templates: noTemplates)
        let game = draft.definition

        #expect(draft.origin == .detected)
        #expect(draft.isNew)
        #expect(game.id == "myport")
        #expect(game.name == "My Port")
        #expect(game.macNativeGamesFolder == "myport")
        #expect(game.titleId == "0100ABCD12340000")
        #expect(game.updateTitleId == "0100ABCD12340800")
        #expect(game.dataFolder == "MYP")
        #expect(game.workFolder == "MyPort_build")
        #expect(game.fileMods?.manifestScript == "games/myport/scripts/make_mod_manifest.py")
        #expect(game.files.map(\.role) == [.gameApp, .workFolder])
        #expect(game.fileMods?.pakFolder == nil)
        #expect(draft.problems(in: empty, macNativeGames: macNativeGames).isEmpty)
    }

    @Test func anAppWithATemplateStartsFromIt() throws {
        let draft = GameDraft.make(app: try app("org.macnativegames.totk", name: "TotK"), portFolder: nil, macNativeGames: macNativeGames, templates: bundledTemplates)

        #expect(draft.origin == .template("totk"))
        #expect(draft.definition.tkSharp == totk.tkSharp)
        #expect(draft.definition.template?.id == "totk")
    }

    @Test func aPortWithoutAnAppIsFoundByItsFolder() {
        let draft = GameDraft.make(app: nil, portFolder: "myport", macNativeGames: macNativeGames, templates: noTemplates)
        #expect(draft.definition.name == "My Port")
        #expect(draft.definition.bundleIdentifier == "org.macnativegames.myport")
    }

    @Test func aPortIsFoundByTheIdentifierInItsSources() throws {
        try folder.write("mng/games/other/Makefile", "BUNDLE_ID = com.example.other\n")
        let draft = GameDraft.make(app: try app("com.example.other", name: "Other"), portFolder: nil, macNativeGames: macNativeGames, templates: noTemplates)
        #expect(draft.definition.macNativeGamesFolder == "other")
        #expect(draft.definition.id == "other")
    }

    @Test func onlyFoldersThatLookLikePortsAreOffered() throws {
        try folder.write("mng/games/notes.txt")
        try folder.write("mng/games/empty/.keep")
        #expect(GameDraft.portFolders(in: macNativeGames) == ["myport"])
        #expect(GameDraft.portFolders(in: nil).isEmpty)
    }

    @Test func draftsCatchClashesAndBadTitleIds() throws {
        var draft = GameDraft.make(app: try app("org.macnativegames.totk", name: "Copy"), portFolder: nil, macNativeGames: macNativeGames, templates: noTemplates)
        draft.definition.id = "copy"
        draft.definition.titleId = "12"
        draft.definition.updateTitleId = "nope"
        let catalog = GameCatalog(games: [totk])

        let problems = draft.fieldProblems(in: catalog)
        draft.definition.id = "totk"

        #expect(problems.contains("Tears of the Kingdom already uses the app identifier org.macnativegames.totk."))
        #expect(draft.fieldProblems(in: catalog).contains("Another game already uses the short name totk."))
        #expect(problems.contains { $0.hasPrefix("The title ID is 16 hexadecimal digits") })
        #expect(problems.contains { $0.hasPrefix("The update's title ID is 16 hexadecimal digits") })
    }

    @Test func editingAGameDoesNotClashWithItself() {
        #expect(GameDraft.editing(totk).fieldProblems(in: GameCatalog(games: [totk, ot0])).isEmpty)
        #expect(!GameDraft.editing(totk).isNew)
    }

    @Test func shortNamesAreLowercaseAsciiWithHyphens() {
        #expect(GameDraft.slug("Octopath Traveler 0") == "octopath-traveler-0")
        #expect(GameDraft.slug("Pokémon: Legends ½") == "pok-mon-legends")
        var draft = GameDraft(definition: GameDefinition(id: "", name: "Port", titleId: "0100000000000000"), origin: .detected)
        #expect(draft.fieldProblems(in: empty) == ["Give the game a short name."])
        draft.definition.id = "My Port"
        #expect(draft.fieldProblems(in: empty) == ["The short name can only use lowercase letters, digits and hyphens."])
    }

    @Test func titleIdsAreSixteenAsciiHexDigits() {
        #expect(GameDraft.updateTitleId(for: "0100abcd12340000") == "0100ABCD12340800")
        #expect(GameDraft.updateTitleId(for: "0100ABCD12340001") == nil)
        #expect(GameDraft.updateTitleId(for: "０１００ABCD12340000") == nil)
    }

    @Test func aSupportedGameNeedsAnAppIdentifierAndEachFileOnce() {
        var game = GameDefinition(id: "port", name: "Port", titleId: "0100000000000000",
                                  mods: .files(FileModSettings(pakFolder: "P/~mods", manifestScript: "m.py")))
        game.files = [GameDefinition.FileSetting(role: .gameApp), GameDefinition.FileSetting(role: .gameApp, label: " ")]
        game.versionFolders = GameDefinition.VersionFolders(exceptions: ["": "v0"])

        let problems = GameDraft(definition: game, origin: .detected).fieldProblems(in: empty)

        #expect(problems == [
            "Enter the app identifier, so Graft can find and start the game.",
            "Each kind of file can only be listed once.",
            "Replace game files needs the work folder. Turn it on in Files.",
            "Every file needs a label.",
            "Every version folder exception needs a version and a folder.",
        ])
    }

    @Test func switchingModSupportKeepsWhatYouEnteredForEachKind() {
        var draft = GameDraft.editing(ot0)
        let files = ot0.mods

        draft.modKind = .tksharp
        #expect(draft.definition.tkSharp == TkSharpSettings())
        draft.modKind = .unsupported
        draft.modKind = .files
        #expect(draft.definition.mods == files)
    }

    @Test func anEmptyFilesEngineStartsWithThePortsManifestScript() {
        var draft = GameDraft.editing(botw)
        draft.modKind = .files
        #expect(draft.definition.fileMods?.manifestScript == "games/botw/scripts/make_mod_manifest.py")
    }

    @Test func applyingANewerTemplateKeepsTheGamesShortName() throws {
        let bundled = try #require(bundledTemplates.template(id: "ot0"))
        let template = GameTemplate(revision: bundled.revision + 1, definition: bundled.definition)
        var game = bundled.game()
        game.id = "octopath"

        let draft = GameDraft.applying(template, to: game)

        #expect(draft.definition.id == "octopath")
        #expect(draft.originalId == "octopath")
        #expect(draft.definition.template == GameDefinition.TemplateReference(id: "ot0", revision: bundled.revision + 1))
        #expect(draft.origin == .template("ot0"))
        #expect(!draft.isNew)
        #expect(draft.fieldProblems(in: GameCatalog(games: [game])).isEmpty)
    }

    @Test func anImportedGameReplacesTheOneWithItsShortName() {
        let file = URL(fileURLWithPath: "/tmp/ot0.json")
        #expect(!GameDraft.importing(ot0, from: file, catalog: GameCatalog(games: [ot0])).isNew)
        #expect(GameDraft.importing(ot0, from: file, catalog: empty).isNew)
        #expect(GameDraft.importing(ot0, from: file, catalog: empty).origin == .imported("ot0.json"))
    }
}

struct GameDraftFilesTests {
    @Test func choosingModSupportAddsTheFilesItNeeds() {
        var draft = GameDraft(definition: GameDefinition(id: "port", name: "Port", titleId: "0100000000000000",
                                                         files: [GameDefinition.FileSetting(role: .gameApp, label: "Mine")]), origin: .detected)

        draft.modKind = .files
        #expect(draft.definition.files.map(\.role) == [.gameApp, .workFolder])
        #expect(draft.definition.files.first?.label == "Mine")

        draft.modKind = .tksharp
        #expect(draft.definition.files.map(\.role) == [.gameApp, .baseGame, .update, .workFolder])
    }

    @Test func aFileTheModSupportNeedsCanNotBeLeftOut() {
        var game = ot0
        game.files.removeAll { $0.role == .workFolder }

        let problems = GameDraft.editing(game).fieldProblems(in: GameCatalog(games: [ot0]))

        #expect(problems == ["Replace game files needs the work folder. Turn it on in Files."])
    }
}
