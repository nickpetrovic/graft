import Foundation
import Testing
@testable import ModKit

struct KnownGameTests {
    @Test func modsForOtherGamesAreRecognizedFromYourGamesAndTheTemplates() {
        let others = KnownGame.others(than: totk, catalog: GameCatalog(games: [totk, ot0]), templates: bundledTemplates)
        let names = others.map(\.name)

        #expect(names.contains("Breath of the Wild"))
        #expect(names.contains("Octopath Traveler 0"))
        #expect(!names.contains("Tears of the Kingdom"))
        #expect(Set(names).count == names.count)
    }
}

struct KnownGameOwnerTests {
    let botwMods = KnownGame(name: "Breath of the Wild", signatures: botw.modSignatures!)

    @Test func aModMostlyMadeOfAnotherGamesFilesBelongsToThatGame() {
        let paths = ["Actor/Pack/Weapon_Sword_070.sbactorpack", "Actor/Pack/Weapon_Sword_071.sbactorpack", "readme.txt"]
        #expect(KnownGame.owner(of: paths, addedTo: ot0, among: [botwMods])?.name == "Breath of the Wild")
    }

    @Test func aModWithOneOfThisGamesFilesOrFewMatchesIsKept() {
        #expect(KnownGame.owner(of: ["Actor/Pack/Sword.sbactorpack", "Octopath_Traveler0/Content/Paks/~mods/a.pak"], addedTo: ot0, among: [botwMods]) == nil)
        #expect(KnownGame.owner(of: ["Actor/Pack/Sword.sbactorpack", "a.txt", "b.txt"], addedTo: ot0, among: [botwMods]) == nil)
        #expect(KnownGame.owner(of: [], addedTo: ot0, among: [botwMods]) == nil)
    }

    @Test func pathsAreComparedWithoutCaseOrALeadingSlash() {
        #expect(KnownGame.owner(of: ["/actor/pack/Sword.SBACTORPACK"], addedTo: ot0, among: [botwMods]) != nil)
        #expect(KnownGame.owner(of: ["\\Actor\\Pack\\Sword.sbactorpack"], addedTo: ot0, among: [botwMods]) != nil)
    }
}
