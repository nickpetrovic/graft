import Foundation
import Testing
@testable import ModKit

struct ModSetupTests {
    @Test func optionRulesFollowTheGroupType() throws {
        let single = optionGroup("Bloom", .singleRequired, ["Off", "On"], selected: ["Off"])
        let multi = optionGroup("Extras", .multi, ["Hats", "Capes"])
        var setup = ModSetup(game: "totk", version: "1.2.1", seed: [mod("m", position: 0, groups: [single, multi])])

        try setup.select(single.options[1], in: single, of: "m", selected: true)
        #expect(setup.mods[0].options["Bloom"] == ["On"])
        #expect(throws: GraftError.self) { try setup.select(single.options[1], in: single, of: "m", selected: false) }
        try setup.select(multi.options[0], in: multi, of: "m", selected: true)
        try setup.select(multi.options[1], in: multi, of: "m", selected: true)
        #expect(setup.mods[0].options["Extras"] == ["Hats", "Capes"])
        try setup.select(multi.options[0], in: multi, of: "m", selected: false)
        #expect(setup.mods[0].options["Extras"] == ["Capes"])
    }

    @Test func anImportedSetupMatchesModsByIdThenNameAndListsWhatIsMissing() throws {
        let library = [mod("a", position: 0), mod("b", position: 1), mod("c", position: 2)]
        let current = ModSetup(game: "totk", version: "1.4.3", seed: library)
        let file = ModSetup(game: "totk", version: "1.2.1", mods: [
            ModSetup.Entry(id: "elsewhere", name: "Mod c", enabled: false),
            ModSetup.Entry(id: "a", name: "Renamed", enabled: true),
            ModSetup.Entry(id: "gone", name: "Gone Mod", enabled: true),
        ])

        let (imported, missing) = current.importing(file, library: library)

        #expect(imported.mods.map(\.id) == ["c", "a", "b"])
        #expect(imported.mods.map(\.enabled) == [false, true, false])
        #expect(imported.version == "1.4.3")
        #expect(missing == ["Gone Mod"])
    }

    @Test func reconcilingDropsRemovedModsAndKeepsValidChoices() {
        let fps = optionGroup("FPS", .singleRequired, ["30", "60"], selected: ["30"])
        let setup = ModSetup(game: "totk", version: "1.2.1", mods: [
            ModSetup.Entry(id: "gone", name: "Gone", enabled: true),
            ModSetup.Entry(id: "a", name: "Old name", enabled: false, options: ["FPS": ["60", "120"], "Removed": ["x"]]),
        ])

        let reconciled = setup.reconciled(with: [mod("a", name: "New name", position: 1, groups: [fps]), mod("b", position: 0)])

        #expect(reconciled.mods.map(\.id) == ["b", "a"])
        #expect(reconciled.mods[1].name == "New name")
        #expect(reconciled.mods[1].enabled == false)
        #expect(reconciled.mods[1].options == ["FPS": ["60"]])
    }

    @Test func requiredGroupsAlwaysHaveAChoiceAndSingleGroupsOnlyOne() {
        let required = mod("m", groups: [optionGroup("Required", .multiRequired, ["a", "b"]), optionGroup("Single", .single, ["x", "y"])])
        #expect(ModSetup.validOptions([:], for: required) == ["Required": ["a"]])
        #expect(ModSetup.validOptions(["Single": ["x", "y"], "Required": ["b"]], for: required) == ["Single": ["x"], "Required": ["b"]])
    }

    @Test func aModMovesToAPositionInsideTheList() {
        var setup = ModSetup(game: "totk", version: "1.2.1", seed: [mod("a", position: 0), mod("b", position: 1), mod("c", position: 2)])
        setup.move("c", to: 0)
        #expect(setup.mods.map(\.id) == ["c", "a", "b"])
        setup.move("c", to: 2)
        #expect(setup.mods.map(\.id) == ["a", "b", "c"])
        setup.move("a", to: 99)
        #expect(setup.mods.map(\.id) == ["b", "c", "a"])
        setup.move("a", to: -1)
        #expect(setup.mods.map(\.id) == ["a", "b", "c"])
        setup.move("missing", to: 0)
        #expect(setup.mods.map(\.id) == ["a", "b", "c"])
    }

    @Test func aSingleChoiceCanBeClearedUnlessItIsRequired() throws {
        let single = optionGroup("Look", .single, ["Dark", "Light"])
        var setup = ModSetup(game: "totk", version: "1.2.1", seed: [mod("m", groups: [single])])
        try setup.select(single.options[0], in: single, of: "m", selected: true)
        try setup.select(single.options[1], in: single, of: "m", selected: true)
        #expect(setup.mods[0].options["Look"] == ["Light"])
        try setup.select(single.options[1], in: single, of: "m", selected: false)
        #expect(setup.mods[0].options["Look"] == [])
    }

    @Test func aClearedOptionalGroupStaysClearedInsteadOfFallingBackToTheLibrarysChoice() throws {
        let extras = optionGroup("Extras", .multi, ["Hats", "Capes"], selected: ["Hats"])
        let library = [mod("m", groups: [extras])]
        var setup = ModSetup(game: "totk", version: "1.2.1", seed: library)
        try setup.select(extras.options[0], in: extras, of: "m", selected: false)

        let reconciled = setup.reconciled(with: library)

        #expect(reconciled.mods[0].options["Extras"] == [])
        #expect(reconciled.applied(to: library)[0].optionGroups[0].options.filter(\.selected).isEmpty)
        #expect(ModSetup.validOptions([:], for: library[0]) == ["Extras": ["Hats"]])
    }

    @Test func anExportedSetupReadsBack() throws {
        let folder = try TemporaryFolder()
        let setup = ModSetup(game: "totk", version: "1.2.1", seed: [mod("a", groups: [optionGroup("FPS", .single, ["60"], selected: ["60"])])])
        let file = folder.url.appending(path: "export.json")
        try JSONFile.encode(setup).write(to: file)
        #expect(try ModSetup.read(from: file) == setup)
        #expect(throws: GraftError.self) { try ModSetup.read(from: folder.url.appending(path: "missing.json")) }
    }
}
