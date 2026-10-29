import Foundation
import Testing
@testable import ModKit

struct ModSetupStoreTests {
    let folder: TemporaryFolder

    init() throws {
        folder = try TemporaryFolder()
    }

    func app(_ name: String, version: String) throws -> String {
        try folder.app(name, identifier: totk.bundleIdentifier, version: version)
    }

    func store(app: String) -> ModSetupStore {
        ModSetupStore(settings: GraftSettings(definition: totk, general: GeneralSettings(), game: GameSettings(gameApp: app)), paths: folder.paths)
    }

    @Test func changingTheModSupportKeepsEachEnginesLoadOrder() throws {
        let gameApp = try app("TotK", version: "1.2.1")
        let merging = store(app: gameApp)
        var replacing = totk
        replacing.mods = .files(FileModSettings(pakFolder: "P/~mods", manifestScript: "m.py"))
        let files = ModSetupStore(settings: GraftSettings(definition: replacing, general: GeneralSettings(), game: GameSettings(gameApp: gameApp)), paths: folder.paths)
        let library = [mod("a", position: 0), mod("b", position: 1)]
        var setup = try merging.current(library: library)
        setup.setEnabled("a", false)
        setup.move("b", to: 0)
        try merging.save(setup)

        #expect(try files.current(library: []).mods.isEmpty)

        let back = try merging.current(library: library).applied(to: library)
        #expect(back.map(\.id) == ["b", "a"])
        #expect(back.map(\.enabled) == [true, false])
        #expect(merging.folder.lastPathComponent == "tksharp")
        #expect(files.folder.lastPathComponent == "files")
    }

    @Test func eachVersionKeepsItsOwnOrderAndSwitches() throws {
        let library = [mod("a", position: 0), mod("b", position: 1), mod("c", position: 2)]
        let older = store(app: try app("TotK 1.2.1", version: "1.2.1"))
        let newer = store(app: try app("TotK 1.4.3", version: "1.4.3"))

        var first = try older.current(library: library)
        first.move("c", to: 0)
        first.setEnabled("b", false)
        try older.save(first)
        var second = try newer.current(library: library, comingFrom: first)
        #expect(second.mods.map(\.id) == ["c", "a", "b"])
        second.move("a", to: 0)
        second.setEnabled("b", true)
        try newer.save(second)

        #expect(try older.current(library: library).applied(to: library).map(\.id) == ["c", "a", "b"])
        #expect(try older.current(library: library).applied(to: library).map(\.enabled) == [true, true, false])
        #expect(try newer.current(library: library).applied(to: library).map(\.id) == ["a", "c", "b"])
        #expect(try newer.current(library: library).applied(to: library).map(\.enabled) == [true, true, true])
        #expect(older.key == "v121")
        #expect(FileManager.default.fileExists(atPath: folder.paths.setups.appending(path: "tksharp/v143.json").path))
    }

    @Test func theFirstSetupFollowsTheEngineAndChangesOutsideGraftAreKept() throws {
        let setups = store(app: try app("TotK", version: "1.2.1"))
        let first = try setups.current(library: [mod("b", position: 1, enabled: false), mod("a", position: 0)])
        #expect(first.mods.map(\.id) == ["a", "b"])
        #expect(first.mods.map(\.enabled) == [true, false])

        let later = try setups.current(library: [mod("a", position: 0), mod("new", position: 0)])
        #expect(later.mods.map(\.id) == ["new", "a"])
    }

    @Test func aNewCopyOfAModKeepsItsPlaceSwitchAndOptionsInEveryVersion() throws {
        let options = optionGroup("FPS", .singleRequired, ["30", "60"], selected: ["30"])
        let library = [mod("a", position: 0), mod("old", position: 1, groups: [options])]
        let older = store(app: try app("TotK 1.2.1", version: "1.2.1"))
        let newer = store(app: try app("TotK 1.4.3", version: "1.4.3"))
        _ = try newer.current(library: library)
        var first = try older.current(library: library)
        first.move("old", to: 0)
        first.setEnabled("old", false)
        try first.select(options.options[1], in: options, of: "old", selected: true)
        try older.save(first)

        let replacement = mod("new", position: 1, groups: [optionGroup("FPS", .singleRequired, ["30", "60"], selected: ["30"])])
        try older.recordAdded(AddedMod(id: "new", name: "Mod new", replacedIds: ["old"], keptCodeBuilds: [], warnings: [], mods: [library[0], replacement]))

        let shown = try older.current(library: [library[0], replacement]).applied(to: [library[0], replacement])
        #expect(shown.map(\.id) == ["new", "a"])
        #expect(shown.map(\.enabled) == [false, true])
        #expect(shown[0].optionGroups[0].options.filter(\.selected).map(\.name) == ["60"])
        #expect(try newer.current(library: [library[0], replacement]).mods.map(\.id) == ["a", "new"])
    }

    @Test func aNewVersionWithoutAPreviousOneStartsFromTheMostRecentSetup() throws {
        let library = [mod("a", position: 0), mod("b", position: 1)]
        let older = store(app: try app("TotK 1.2.1", version: "1.2.1"))
        var first = try older.current(library: library)
        first.move("b", to: 0)
        try older.save(first)

        let newer = try store(app: try app("TotK 1.4.3", version: "1.4.3")).current(library: library)

        #expect(newer.mods.map(\.id) == ["b", "a"])
        #expect(newer.version == "1.4.3")
    }

    @Test func removingAModRemovesItFromEveryVersion() throws {
        let library = [mod("a", position: 0), mod("b", position: 1)]
        let older = store(app: try app("TotK 1.2.1", version: "1.2.1"))
        let newer = store(app: try app("TotK 1.4.3", version: "1.4.3"))
        _ = try older.current(library: library)
        _ = try newer.current(library: library)

        try older.recordRemoved("a")

        #expect(try older.saved("v121")?.mods.map(\.id) == ["b"])
        #expect(try older.saved("v143")?.mods.map(\.id) == ["b"])
    }

    @Test func aNewModJoinsOnlyTheVersionYouAreOn() throws {
        let a = mod("a", position: 0)
        let older = store(app: try app("TotK 1.2.1", version: "1.2.1"))
        let newer = store(app: try app("TotK 1.4.3", version: "1.4.3"))
        _ = try older.current(library: [a])
        _ = try newer.current(library: [a])
        let b = mod("b", position: 1)

        try newer.recordAdded(AddedMod(id: "b", name: "Mod b", replacedIds: [], keptCodeBuilds: [], warnings: [], mods: [a, b]))

        #expect(try newer.current(library: [a, b]).mods.map(\.id) == ["a", "b"])
        #expect(try older.current(library: [a, b]).mods.map(\.id) == ["a"])
    }

    @Test func aModRemovedFromOneVersionStaysOutOfItAndInTheOther() throws {
        let library = [mod("a", position: 0), mod("b", position: 1)]
        let older = store(app: try app("TotK 1.2.1", version: "1.2.1"))
        let newer = store(app: try app("TotK 1.4.3", version: "1.4.3"))
        var first = try older.current(library: library)
        _ = try newer.current(library: library)

        first.remove("b")
        try older.save(first)

        #expect(try older.current(library: library).mods.map(\.id) == ["a"])
        #expect(try newer.current(library: library).mods.map(\.id) == ["a", "b"])
        #expect(older.otherVersionsByMod() == ["a": ["1.4.3"], "b": ["1.4.3"]])
        #expect(newer.otherVersionsByMod() == ["a": ["1.2.1"]])
    }

    @Test func aModNoVersionHasJoinsTheVersionYouAreOn() throws {
        let a = mod("a", position: 0)
        let older = store(app: try app("TotK 1.2.1", version: "1.2.1"))
        let newer = store(app: try app("TotK 1.4.3", version: "1.4.3"))
        _ = try older.current(library: [a])
        _ = try newer.current(library: [a])
        let library = [a, mod("outside", position: 1)]

        #expect(try newer.current(library: library).mods.map(\.id) == ["a", "outside"])
        #expect(try older.current(library: library).mods.map(\.id) == ["a"])
    }

    @Test func copyingAModToAnotherVersionKeepsItsSwitchAndOptionsOnce() throws {
        let fps = optionGroup("FPS", .singleRequired, ["30", "60"], selected: ["30"])
        let library = [mod("a", position: 0), mod("b", position: 1, groups: [fps])]
        let older = store(app: try app("TotK 1.2.1", version: "1.2.1"))
        var first = try older.current(library: library)
        first.setEnabled("b", false)
        try first.select(fps.options[1], in: fps, of: "b", selected: true)
        try older.save(first)
        try older.save(ModSetup(game: "totk", version: "1.4.3", mods: [first.mods[0]]), as: "v143")
        let entry = try #require(first.entry("b"))

        try older.copy(entry, from: first, toVersion: "1.4.3")
        try older.copy(entry, from: first, toVersion: "1.4.3")

        let copied = try #require(try older.saved("v143"))
        #expect(copied.mods.map(\.id) == ["a", "b"])
        #expect(copied.entry("b")?.enabled == false)
        #expect(copied.entry("b")?.options["FPS"] == ["60"])
        #expect(throws: GraftError.self) { try older.copy(entry, from: first, toVersion: "1.2.1") }
    }

    @Test func copyingToAVersionWithoutALoadOrderStartsItFromThisVersionsList() throws {
        let library = [mod("a", position: 0), mod("b", position: 1), mod("c", position: 2)]
        let older = store(app: try app("TotK 1.2.1", version: "1.2.1"))
        var first = try older.current(library: library)
        first.move("c", to: 0)
        first.setEnabled("a", false)
        try older.save(first)

        try older.copy(try #require(first.entry("b")), from: first, toVersion: "1.4.3")

        let newer = try store(app: try app("TotK 1.4.3", version: "1.4.3")).current(library: library)
        #expect(newer.mods.map(\.id) == ["c", "a", "b"])
        #expect(newer.mods.map(\.enabled) == [true, false, true])
        #expect(newer.version == "1.4.3")
    }

    @Test func copyingAnotherVersionsOrderKeepsModsNoOtherVersionHas() throws {
        let library = [mod("a", position: 0), mod("b", position: 1), mod("only", position: 2)]
        let older = store(app: try app("TotK 1.2.1", version: "1.2.1"))
        let newer = store(app: try app("TotK 1.4.3", version: "1.4.3"))
        let first = try older.current(library: library)
        var second = try newer.current(library: Array(library.prefix(2)))
        second.move("b", to: 0)
        second.setEnabled("a", false)
        try newer.save(second)

        let copied = older.copyingOrder(of: second, into: first, library: library)
        try older.save(copied)

        #expect(copied.mods.map(\.id) == ["b", "a", "only"])
        #expect(copied.mods.map(\.enabled) == [true, false, true])
        #expect(copied.version == "1.2.1")
        #expect(try older.current(library: library) == copied)
    }

    @Test func eachAppHasTheLoadOrderOfItsVersion() throws {
        let setups = store(app: try app("TotK 1.2.1", version: "1.2.1"))
        #expect(setups.key(forApp: try app("Copy of TotK", version: "1.2.1")) == setups.key)
        #expect(setups.key(forApp: try app("TotK 1.4.3", version: "1.4.3")) == "v143")
        #expect(setups.key(forApp: folder.path("Missing.app")) == nil)
    }

    @Test func aNewerCopyReplacesTheOldOneWhereverItIsUsed() throws {
        let a = mod("a", position: 0)
        let old = mod("old", position: 1)
        let older = store(app: try app("TotK 1.2.1", version: "1.2.1"))
        let newer = store(app: try app("TotK 1.4.3", version: "1.4.3"))
        _ = try older.current(library: [a, old])
        var second = try newer.current(library: [a, old])
        second.remove("old")
        try newer.save(second)
        let replacement = mod("new", position: 1)

        try older.recordAdded(AddedMod(id: "new", name: "Mod new", replacedIds: ["old"], keptCodeBuilds: [], warnings: [], mods: [a, replacement]))

        #expect(try older.saved("v121")?.mods.map(\.id) == ["a", "new"])
        #expect(try newer.saved("v143")?.mods.map(\.id) == ["a"])
    }
}
