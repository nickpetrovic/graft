import Foundation
import ModKit

enum Command: String, CaseIterable {
    case game
    case version
    case setup
    case settings
    case detect
    case checkCode = "check-code"
    case importTKMM = "import-tkmm"
    case list
    case install
    case apply
    case play
    case crash

    var synopsis: String {
        switch self {
        case .game: "game [id]"
        case .version: "version [game app]"
        case .setup: "setup [export|import <file>]"
        case .checkCode: "check-code <file.pchtxt>"
        case .install: "install <path>"
        case .apply: "apply [--rebuild]"
        default: rawValue
        }
    }

    var summary: String {
        switch self {
        case .game: "list your games, or switch to one"
        case .version: "list the versions of this game, or switch to one and its matching update"
        case .setup: "show this version's load order file, or export or import it"
        case .settings: "show the settings and any problems"
        case .detect: "search for paths, also in Downloads and Documents, without saving"
        case .checkCode: "check whether a code mod works on the Mac"
        case .importTKMM: "copy TKMM's mod library"
        case .list: "list the mods in load order"
        case .install: "add a mod from a file or folder"
        case .apply: "merge mods, check code, rebuild if needed, install data mods"
        case .play: "start the game with the mods last applied"
        case .crash: "explain why the game last stopped"
        }
    }

    var arguments: ClosedRange<Int> {
        switch self {
        case .game, .version: 0...1
        case .setup: 0...2
        case .checkCode, .install: 1...1
        default: 0...0
        }
    }

    var flags: Set<String> { self == .apply ? ["--rebuild"] : [] }

    var needsEngine: Bool { [.checkCode, .importTKMM, .list, .install, .apply, .setup].contains(self) }

    var needsSetup: Bool { [.apply, .play].contains(self) }
}

func usageLine(_ synopsis: String, _ summary: String) -> String {
    "  " + synopsis.padding(toLength: 31, withPad: " ", startingAt: 0) + summary
}

let usage = (["usage: graft <command>", ""] + Command.allCases.flatMap { command -> [String] in
    let actions = command == .game ? GameAction.allCases.map { usageLine($0.synopsis, $0.summary) } : []
    return [usageLine(command.synopsis, command.summary)] + actions
}).joined(separator: "\n")

func fail(_ message: String, status: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(status)
}

func printJSON(_ value: some Encodable) throws {
    print(String(decoding: try JSONFile.encode(value), as: UTF8.self))
}

struct PrintedSettings: Encodable {
    let game: String
    let general: GeneralSettings
    let gameSettings: GameSettings
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let name = arguments.first else { fail(usage, status: 2) }
if ["help", "-h", "--help"].contains(name) {
    print(usage)
    exit(0)
}
guard let command = Command(rawValue: name) else { fail("unknown command '\(name)'\n\n\(usage)", status: 2) }
let positional = arguments.dropFirst().filter { !$0.hasPrefix("--") }
let flags = Set(arguments.dropFirst().filter { $0.hasPrefix("--") })
let action = command == .game ? positional.first.flatMap(GameAction.init(rawValue:)) : nil
guard action.map({ $0.arguments == positional.count - 1 }) ?? command.arguments.contains(positional.count), flags.isSubset(of: command.flags) else {
    fail("wrong arguments for '\(name)'\n\n\(usage)", status: 2)
}

let stopSignals = [SIGINT, SIGTERM, SIGHUP].map { number in
    signal(number, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: number, queue: .global())
    source.setEventHandler {
        ChildProcesses.shared.terminateAll()
        signal(number, SIG_DFL)
        raise(number)
    }
    source.resume()
    return source
}

do {
    let root = GraftPaths.standardRoot
    if let action {
        try await action.run(Array(positional.dropFirst()), root: root)
        exit(0)
    }
    let game: GameDefinition
    switch SettingsStore.selection(root: root) {
    case .game(let selected):
        game = selected
    case _ where command == .game:
        try await GameAction.listOrSwitch(to: positional.first, root: root)
        exit(0)
    case .unreadable(_, let problem):
        fail("\(problem)\nFix the file, or switch to another game with graft game <id>.")
    case .none:
        fail((GameCatalog.shared.problems.map { "problem: \($0)" } + [GameAction.noGames]).joined(separator: "\n"))
    }
    let paths = GraftPaths.standard(for: game)
    let settings = try await SettingsStore(paths: paths, game: game).loadSavingDetected()
    if command.needsEngine, let reason = game.unsupportedReason {
        fail(reason)
    }
    if command.needsSetup {
        let problems = SetupCheck(settings).problems
        guard problems.isEmpty else {
            fail((["\(game.name) isn't set up yet:"] + problems.map { "  \($0)" } + ["Fix them in Graft (Settings, and Game Info for this game's files), or list them again with graft settings."]).joined(separator: "\n"))
        }
    }
    func engine() throws -> any ModEngine { try ModEngines.make(settings: settings, paths: paths) }
    let setups = ModSetupStore(settings: settings, paths: paths)
    func currentMods() async throws -> [InstalledMod] {
        let library = try await engine().list()
        return try setups.current(library: library).applied(to: library)
    }

    switch command {
    case .game:
        try await GameAction.listOrSwitch(to: positional.first, root: root)
    case .version:
        var current = settings
        let found = SettingsDetector(game: game).findGameApps(near: [settings.game.baseGame, settings.game.update])
        if let wanted = positional.first {
            let path = URL(fileURLWithPath: wanted).standardizedFileURL.path
            guard AppBundle.bundleIdentifier(at: path) == game.bundleIdentifier else {
                fail("\(wanted) isn't a \(game.name) game app")
            }
            let previous = current.game
            let leaving = try setups.saved(setups.key)
            current.game.gameApp = path
            current.game.remember(previous)
            let engine = try ModEngines.make(settings: current, paths: paths)
            if let version = AppBundle.shortVersion(at: path),
               try await UpdateMatch.version(of: current.game.update, settings: current, engine: engine) != version,
               let match = try await UpdateMatch.find(for: current, engine: engine) {
                current.game.update = match
            }
            try SettingsStore(paths: paths, game: game).save(current.game)
            _ = try ModSetupStore(settings: current, paths: paths).current(library: try await engine.list(), comingFrom: leaving)
        }
        for version in GameVersion.all(for: current, found: found) {
            print("\(version.app == current.game.gameApp ? "*" : " ") \(version.title)\t\(version.app)")
        }
        if !current.game.update.isEmpty { print("update: \(current.game.update)") }
        if let problem = SetupCheck(current).problem(for: .update) { print("problem: \(problem)") }
    case .setup:
        let library = try await engine().list()
        let current = try setups.current(library: library)
        switch (positional.first, positional.dropFirst().first) {
        case (nil, nil):
            print(setups.file(for: setups.key).path)
            try printJSON(current)
        case ("export", let file?):
            try JSONFile.encode(current).write(to: URL(fileURLWithPath: file), options: .atomic)
            print("exported the load order for \(game.name) \(current.version) to \(file)")
        case ("import", let file?):
            let other = try ModSetup.read(from: URL(fileURLWithPath: file))
            let (imported, missing) = current.importing(other, library: library)
            try setups.save(imported)
            print("imported \(counted(other.mods.count - missing.count, "mod")) into the load order for \(game.name) \(current.version)")
            for name in missing { print("not in the library, left out: \(name)") }
        default:
            fail("wrong arguments for 'setup'\n\n\(usage)", status: 2)
        }
    case .settings:
        try printJSON(PrintedSettings(game: game.id, general: settings.general, gameSettings: settings.game))
        let check = SetupCheck(settings)
        for problem in check.problems { print("problem: \(problem)") }
        for notice in GameCatalog.shared.problems + GameTemplates.shared.problems { print("notice: \(notice)") }
    case .detect:
        let found = await SettingsDetector(game: game, includeProtectedFolders: true).detect()
        try printJSON(PrintedSettings(game: game.id, general: found.general, gameSettings: found.game))
    case .checkCode:
        let file = URL(fileURLWithPath: positional[0])
        let layout = try GameLayout.load(for: settings)
        let patch = try await engine().readCodePatch(file)
        for warning in patch.warnings { print("warning: \(warning)") }
        guard patch.buildId == layout.buildId else {
            fail("not for this game: the file is for build \(patch.buildId), the game app is \(layout.displayVersion) (\(layout.buildId))")
        }
        let reserved = try await GameEnvironment.reservedSites(settings: settings, layout: layout)
        let analysis = try PatchComposer.check(patch.entries, name: file.lastPathComponent, layout: layout, reserved: reserved)
        print("\(patch.entries.count) patch values")
        switch analysis.outcome {
        case .unchanged: print("works on the Mac as written")
        case .relocated(let moved, let dropped): print("works after Graft's fix for Mac (\(moved) instructions moved, \(dropped) initializers dropped)")
        case .unfixable(let reason): print("won't work: \(reason)")
        }
        for instruction in analysis.unsupportedInstructions { print("needs the rewriter, so it is built into the game app: \(instruction)") }
        for note in analysis.notes { print(note) }
    case .importTKMM:
        let engine = try engine()
        guard let library = engine.importableLibrary() else {
            fail("No TKMM library found, or Graft's library already has mods.")
        }
        if let previous = try await engine.importLibrary(library) { print("earlier library kept at \(previous.path)") }
        print("imported \(library.location.path)")
    case .list:
        print("load order for \(game.name) \(setups.displayVersion ?? "(no game app)"): \(setups.file(for: setups.key).path)")
        for (position, mod) in try await currentMods().enumerated() {
            print("\(position + 1)\t\(mod.enabled ? "on " : "off")\t\(mod.displayName)\tdata=\(mod.dataFiles) code=\(mod.codePatchBuilds.count) subsdk=\(mod.subSdkFiles) options=\(mod.optionGroups.count)")
        }
    case .install:
        _ = try await currentMods()
        let added = try await engine().add(URL(fileURLWithPath: positional[0])) { print("  \($0)") }
        try setups.recordAdded(added)
        for warning in added.warnings { print("warning: \(warning)") }
        print("installed \(added.name)\(added.replacedIds.isEmpty ? "" : ", replacing the other copy"); \(added.mods.count) mods in the library")
        if !added.keptCodeBuilds.isEmpty {
            print("kept the older copy's code for \(counted(added.keptCodeBuilds.count, "other game version"))")
        }
    case .apply:
        let outcome = try await engine().apply(try await currentMods(), force: flags.contains("--rebuild")) { stage in
            switch stage {
            case .merging(let message): print("merge: \(message)")
            case .checkingCode: print("checking code mods")
            case .rebuilding(let plan): print(plan.message)
            case .building(let line): print("build: \(line)")
            case .installingData: print("installing data mods")
            }
        }
        for status in outcome.statuses {
            switch status.analysis.outcome {
            case .unchanged: print("code ok: \(status.modName)")
            case .relocated(let moved, let dropped): print("code fixed for Mac: \(status.modName) (\(moved) moved, \(dropped) dropped)")
            case .unfixable(let reason): print("code left out: \(status.modName): \(reason)")
            }
        }
        for ignored in outcome.ignored {
            print("ignored code: \(ignored.modName) (subsdk files: \(ignored.subSdkFiles), patches for other versions: \(ignored.patchesForOtherBuilds))")
        }
        if settings.definition.tkSharp?.codeMods != nil {
            print("rebuilt game app: \(outcome.rebuilt ? "yes" : "no")")
            print("code patches: \(outcome.codeAtLaunch ? "applied when the game starts" : "built into the game app")")
        }
        print("data: \(outcome.dataSummary)")
    case .play:
        try await GameLauncher.launch(settings: settings, paths: paths)
        print("started: open \(GameLauncher.launchArguments(settings: settings, paths: paths).joined(separator: " "))")
    case .crash:
        switch GameExit.read(log: paths.gameLog, since: .distantPast, game: game, state: ApplyState.load(from: paths)) {
        case .crashed(let report, let modId)?:
            print("signal \(report.signal) at \(report.place)")
            if let modId {
                let name = try await engine().list().first { $0.id == modId }?.displayName
                print("mod: \(name ?? "a mod that is no longer in the list (\(modId))")")
            } else {
                print("mod: none of the code mods")
            }
        case .stopped(let stop)?:
            print("stopped: \(stop.reason)")
            switch stop.hint {
            case .wakeDisplay: print("wake the Mac's display, then run graft play again")
            case .rebuildForCodeMods: print("run graft apply --rebuild, then graft play")
            case .reinstallMods: print("run graft apply, then graft play")
            case nil: break
            }
        case nil:
            print("No crash or stop in the game log.")
        }
    }
} catch {
    fail(error.localizedDescription)
}
