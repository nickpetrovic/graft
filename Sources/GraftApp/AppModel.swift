import AppKit
import ModKit
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class AppModel {
    enum Activity: Equatable {
        case idle
        case working(String)
        case reading(String)

        var message: String? {
            switch self {
            case .idle: nil
            case .working(let message), .reading(let message): message
            }
        }
    }

    private(set) var paths: GraftPaths
    private(set) var game: GameDefinition
    private(set) var settings: GraftSettings
    private(set) var setup: SetupCheck
    private(set) var engine: (any ModEngine)?
    private(set) var engineProblem: String?
    private(set) var definitionProblems: [String] = []
    private(set) var templateUpdate: GameTemplate?
    private(set) var settingsError: String?
    private(set) var setupProblems: [String] = []
    private(set) var needsApply = false
    var showsInspector = UserDefaults.standard.bool(forKey: "showInspector") {
        didSet { UserDefaults.standard.set(showsInspector, forKey: "showInspector") }
    }
    private(set) var versions: [GameVersion] = []
    private(set) var versionTargets: [GameVersion] = []
    private(set) var copyableVersions: [GameVersion] = []
    private(set) var versionMods: [String: Set<String>] = [:]
    private(set) var otherVersionsByMod: [String: [String]] = [:]
    private(set) var layout: GameLayout?
    private(set) var codeAtLaunchSupported = false
    private(set) var importable: ImportableLibrary?
    private(set) var gameRunning = false
    private(set) var hasLoaded = false
    var mods: [InstalledMod] = [] { didSet { updateNeedsApply() } }
    private(set) var modsLoaded = false
    var state: ApplyState { didSet { updateNeedsApply() } }
    var activity: Activity = .idle { didSet { showActivity(after: oldValue) } }
    private(set) var shownActivity: Activity = .idle
    var errorMessage: String?
    var crash: CrashNotice?
    var notice: String?
    var optionsMod: InstalledMod?

    @ObservationIgnored private var terminationObserver: NotificationCenter.ObservationToken?
    @ObservationIgnored private var queue: Task<Bool, Never>?
    @ObservationIgnored private var dismissedImports: Set<String>
    @ObservationIgnored private var foundApps: [String] = []
    @ObservationIgnored private var identifiedUpdate: UpdateFile?
    @ObservationIgnored private var pendingApp: String?
    @ObservationIgnored private var queuedTasks = 0
    @ObservationIgnored private var libraryCache: [String: [InstalledMod]] = [:]
    @ObservationIgnored private var rawLibrary: [InstalledMod] = []
    @ObservationIgnored private var modSetup: (key: String, setup: ModSetup)?
    @ObservationIgnored private var activityStart = 0
    @ObservationIgnored var onGameAppChange: @MainActor () -> Void = {}
    @ObservationIgnored var onIdle: @MainActor () -> Void = {}

    init(game: GameDefinition, app: String? = nil) {
        let paths = GraftPaths.standard(for: game)
        let store = SettingsStore(paths: paths, game: game)
        let settings = GraftSettings(definition: game, general: (try? store.savedGeneral()) ?? GeneralSettings(),
                                     game: (try? store.savedGame()) ?? GameSettings())
        self.game = game
        self.paths = paths
        self.settings = settings
        setup = SetupCheck(settings)
        state = ApplyState.load(from: paths)
        dismissedImports = SettingsStore.dismissedImports(root: paths.root)
        pendingApp = app
        terminationObserver = NSWorkspace.shared.notificationCenter.addObserver(of: NSWorkspace.shared, for: .didTerminateApplication) { [weak self] message in
            guard let self, let identifier = message.application.bundleIdentifier, identifier == self.game.bundleIdentifier else { return }
            self.gameDidExit()
        }
    }

    isolated deinit {
        if let terminationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(terminationObserver)
        }
    }

    var isWorking: Bool {
        if case .working = activity { return true }
        return false
    }

    var locksControls: Bool {
        if case .working = shownActivity { return true }
        return false
    }

    private func showActivity(after previous: Activity) {
        if activity == .idle {
            shownActivity = .idle
        } else if shownActivity != .idle {
            shownActivity = activity
        } else if previous == .idle {
            activityStart += 1
            let start = activityStart
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard start == activityStart, activity != .idle else { return }
                shownActivity = activity
            }
        }
    }

    var enabledCount: Int { mods.filter(\.enabled).count }

    var modFormats: String { game.mods.modFormats ?? "files or folders" }

    private var store: SettingsStore { SettingsStore(paths: paths, game: game) }

    func load() async {
        let id = game.id
        let store = store
        var loadProblem: String?
        do {
            let loaded = try await store.loadSavingDetected()
            guard game.id == id else { return }
            settings = loaded
        } catch {
            guard game.id == id else { return }
            loadProblem = error.localizedDescription
        }
        checkSettingsFiles()
        onGameAppChange()
        foundApps = SettingsDetector(game: game).findGameApps(near: [settings.game.baseGame, settings.game.update])
        evaluate()
        gameRunning = GameEnvironment.isGameRunning(settings)
        if !gameRunning, LaunchRecord.load(from: paths) != nil {
            gameDidExit()
        }
        await refresh()
        if settingsError == nil, let loadProblem {
            errorMessage = loadProblem
        }
        guard game.id == id else { return }
        let firstLoad = !hasLoaded
        hasLoaded = true
        if firstLoad { preloadOtherGames() }
        if let app = pendingApp {
            pendingApp = nil
            selectVersion(app)
        } else {
            await checkUpdate(replacing: true)
        }
    }

    func update(definition: GameDefinition) {
        guard definition.id == game.id, definition != game else { return }
        let appChanged = definition.bundleIdentifier != game.bundleIdentifier
        game = definition
        paths = .standard(for: definition)
        settings = GraftSettings(definition: definition, general: settings.general, game: settings.game)
        if appChanged {
            foundApps = SettingsDetector(game: definition).findGameApps(near: [settings.game.baseGame, settings.game.update])
        }
        evaluate()
        Task { await refresh() }
    }

    func select(_ next: GameDefinition, app: String? = nil) {
        guard next.id != game.id else {
            update(definition: next)
            if let app { selectVersion(app) }
            return
        }
        guard !isWorking else { return }
        do {
            try SettingsStore.select(next, root: paths.root)
        } catch {
            errorMessage = "Could not switch to \(next.name): \(error.localizedDescription)"
            return
        }
        pendingApp = app
        game = next
        paths = .standard(for: next)
        let saved = try? store.savedGame()
        settings = GraftSettings(definition: next, general: settings.general, game: saved ?? GameSettings())
        if let app = pendingApp, let saved {
            pendingApp = nil
            var files = saved
            files.gameApp = app
            files.remember(saved)
            if files != saved, (try? store.save(files)) != nil {
                settings.game = files
            }
        }
        state = ApplyState.load(from: paths)
        rawLibrary = []
        modSetup = nil
        if let cached = libraryCache[next.id] {
            try? show(cached)
        } else {
            modsLoaded = false
            mods = []
        }
        crash = nil
        notice = nil
        errorMessage = nil
        identifiedUpdate = nil
        foundApps = SettingsDetector(game: next).findGameApps(near: [settings.game.baseGame, settings.game.update])
        evaluate()
        if engine == nil {
            modsLoaded = true
            mods = []
        }
        Task { await load() }
    }

    func selectVersion(_ app: String) {
        guard !isWorking, app != settings.game.gameApp else { return }
        updateGame { $0.gameApp = app }
    }

    private func updateVersionTargets() {
        let store = setups
        let others = store.otherSetups()
        var membership: [String: Set<String>] = [:]
        versionTargets = versions.filter { version in
            guard let key = store.key(forApp: version.app), key != store.key else { return false }
            if let saved = others[key] { membership[version.app] = Set(saved.mods.map(\.id)) }
            return true
        }
        copyableVersions = versionTargets.filter { membership[$0.app] != nil }
        versionMods = membership
        otherVersionsByMod = ModSetupStore.versionsByMod(others.values)
    }

    var currentVersionTitle: String? {
        versions.first { $0.app == settings.game.gameApp }?.title
    }

    func version(_ version: GameVersion, has mod: InstalledMod) -> Bool {
        versionMods[version.app]?.contains(mod.id) == true
    }

    func otherVersions(using mod: InstalledMod) -> [String] {
        otherVersionsByMod[mod.id] ?? []
    }

    func copy(_ mod: InstalledMod, to version: GameVersion, moving: Bool) {
        guard !isWorking, let current = modSetup, let entry = current.setup.entry(mod.id),
              let target = AppBundle.shortVersion(at: version.app) else { return }
        do {
            try setups.copy(entry, from: current.setup, toVersion: target)
        } catch {
            errorMessage = "Could not \(moving ? "move" : "copy") \(mod.displayName) to \(version.title): \(error.localizedDescription)"
            return
        }
        if moving { changeSetup { $0.remove(mod.id) } }
        updateVersionTargets()
        notice = "\(moving ? "Moved" : "Copied") \(mod.displayName) to \(version.title)."
    }

    func copySetup(from version: GameVersion) {
        let store = setups
        guard let key = store.key(forApp: version.app) else { return }
        do {
            guard let other = try store.saved(key) else { return }
            changeSetup { setup in
                setup = store.copyingOrder(of: other, into: setup, library: rawLibrary)
            }
            notice = "Copied the load order from \(version.title)."
        } catch {
            errorMessage = "Could not copy the load order from \(version.title): \(error.localizedDescription)"
        }
    }

    func chooseOtherVersion(of other: GameDefinition? = nil, startingAt otherApp: String? = nil) {
        let target = other ?? game
        let start = target.id == game.id ? settings.game.gameApp : otherApp ?? ""
        guard !isWorking, let app = FilePicker.choose(.application, startingAt: start) else { return }
        guard AppBundle.bundleIdentifier(at: app) == target.bundleIdentifier else {
            errorMessage = "\(URL(fileURLWithPath: app).lastPathComponent) isn't a game app for \(target.name)."
            return
        }
        select(target, app: app)
    }

    private func checkUpdate(replacing: Bool) async {
        guard let engine, setup.keysFolder == nil, game.files.contains(where: { $0.role == .update }),
              let appVersion = AppBundle.shortVersion(at: settings.game.gameApp) else { return }
        let checked = settings
        let current = try? await UpdateMatch.version(of: checked.game.update, settings: checked, engine: engine)
        guard settings == checked else { return }
        identifiedUpdate = current.map { UpdateFile(path: checked.game.update, titleId: game.titleId, displayVersion: $0) }
        evaluate()
        guard replacing, current != appVersion else { return }
        await run("Looking for the \(appVersion) update") {
            guard let match = try await UpdateMatch.find(for: checked, engine: engine), self.settings == checked else { return }
            self.updateGame { $0.update = match }
            if let current {
                self.notice = "The update file for this game was \(current), so Graft chose the \(appVersion) update to match the game app."
            }
        }
    }

    func updateGeneral(_ change: (inout GeneralSettings) -> Void) {
        let previous = settings.general
        var general = previous
        change(&general)
        guard general != previous, saveGeneral(general) else { return }
        evaluate()
        if general.keysFolder != previous.keysFolder || general.macNativeGames != previous.macNativeGames {
            Task { await refresh() }
        }
    }

    func updateGame(_ change: (inout GameSettings) -> Void) {
        let previous = settings.game
        var game = previous
        change(&game)
        game.remember(previous)
        guard game != previous, saveGame(game) else { return }
        if game.gameApp != previous.gameApp {
            onGameAppChange()
            if let leaving = modSetup?.setup { try? show(rawLibrary, comingFrom: leaving) }
        }
        evaluate()
        if GameDefinition.FileSetting.Role.allCases.contains(where: { game[$0] != previous[$0] }) {
            Task { await refresh() }
        }
        if game.gameApp != previous.gameApp || game.update != previous.update {
            let replacing = game.gameApp != previous.gameApp
            Task { await checkUpdate(replacing: replacing) }
        }
    }

    @discardableResult
    private func saveGeneral(_ general: GeneralSettings) -> Bool {
        do {
            try store.save(general)
            settings.general = general
            checkSettingsFiles()
            return true
        } catch {
            errorMessage = "Could not save the settings: \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    private func saveGame(_ game: GameSettings) -> Bool {
        do {
            try store.save(game)
            settings.game = game
            checkSettingsFiles()
            return true
        } catch {
            errorMessage = "Could not save the settings for \(self.game.name): \(error.localizedDescription)"
            return false
        }
    }

    private func checkSettingsFiles() {
        do {
            _ = try store.savedGeneral()
            _ = try store.savedGame()
            settingsError = nil
        } catch {
            settingsError = error.localizedDescription
        }
    }

    private func evaluate() {
        versions = GameVersion.all(for: settings, found: foundApps)
        updateVersionTargets()
        layout = try? GameLayout.load(for: settings)
        codeAtLaunchSupported = Applier.supportsCodeAtLaunch(settings: settings)
        setup = SetupCheck(settings, updateVersion: identifiedUpdate?.path == settings.game.update ? identifiedUpdate?.displayVersion : nil)
        do {
            engine = try ModEngines.make(settings: settings, paths: paths)
            engineProblem = nil
        } catch {
            engine = nil
            engineProblem = error.localizedDescription
        }
        setupProblems = [settingsError, engineProblem].compactMap { $0 } + setup.problems
        definitionProblems = GameDraft.editing(game).problems(in: .shared, macNativeGames: MacNativeGames(settings).presentFolder)
            .filter { !setup.definition.contains($0) }
        templateUpdate = GameTemplates.shared.update(for: game)
        importable = dismissedImports.contains(game.id) ? nil : engine?.importableLibrary()
        updateNeedsApply()
    }

    private func updateNeedsApply() {
        needsApply = Applier.digest(of: mods, settings: settings, buildId: layout?.buildId) != state.appliedModsDigest
    }

    private var setups: ModSetupStore { ModSetupStore(settings: settings, paths: paths) }

    private func show(_ library: [InstalledMod], comingFrom previous: ModSetup? = nil) throws {
        let store = setups
        let setup = try store.current(library: library, comingFrom: previous)
        rawLibrary = library
        libraryCache[game.id] = library
        modSetup = (store.key, setup)
        modsLoaded = true
        mods = setup.applied(to: library)
        if let shown = optionsMod { optionsMod = mods.first { $0.id == shown.id } }
        updateVersionTargets()
    }

    private func changeSetup(_ change: (inout ModSetup) throws -> Void) {
        guard var current = modSetup else { return }
        do {
            try change(&current.setup)
            try setups.save(current.setup, as: current.key)
            modSetup = current
            mods = current.setup.applied(to: rawLibrary)
            if let shown = optionsMod { optionsMod = mods.first { $0.id == shown.id } }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        let id = game.id
        guard let engine else {
            await run(nil) {
                guard self.game.id == id else { return }
                self.rawLibrary = []
                self.modSetup = nil
                self.modsLoaded = true
                self.mods = []
            }
            return
        }
        await run(libraryCache[id] == nil ? "Reading your mods" : nil, reading: true) {
            let list = try await engine.list()
            guard self.game.id == id else {
                self.libraryCache[id] = list
                return
            }
            try self.show(list)
        }
    }

    private func preloadOtherGames() {
        for other in GameCatalog.shared.games where other.id != game.id && other.unsupportedReason == nil && libraryCache[other.id] == nil {
            let paths = GraftPaths.standard(for: other)
            guard let saved = try? SettingsStore(paths: paths, game: other).savedGame(), FileManager.default.fileExists(atPath: saved.gameApp),
                  let engine = try? ModEngines.make(settings: GraftSettings(definition: other, general: settings.general, game: saved), paths: paths)
            else { continue }
            Task {
                guard let list = try? await engine.list(), libraryCache[other.id] == nil else { return }
                libraryCache[other.id] = list
            }
        }
    }

    func refreshQuietly() async {
        gameRunning = GameEnvironment.isGameRunning(settings)
        guard let engine, activity == .idle else { return }
        let id = game.id
        await run(nil) {
            let current = try await engine.list()
            guard self.game.id == id else { return }
            try self.show(current)
            self.state = ApplyState.load(from: self.paths)
        }
    }

    func badges(for mod: InstalledMod) -> [ModBadge] {
        ModBadge.badges(for: mod, layout: layout, status: state.codeStatus[mod.id])
    }

    func summaryHelp(for mod: InstalledMod) -> String {
        guard mod.changesCode(buildId: layout?.buildId) else { return "" }
        return codeAtLaunchSupported
            ? "Changes the game's code. Turning it on or off takes effect at the next Play."
            : "Changes the game's code. Turning it on or off rebuilds the game app once, which takes about a minute."
    }

    func importLibrary() {
        guard let library = importable, let engine = requireEngine() else { return }
        importable = nil
        Task {
            await run("Importing your mods from \(library.manager)") {
                let previous = try await engine.importLibrary(library)
                self.notice = "Imported your mods from \(library.manager)."
                    + (previous.map { " Graft's earlier library is kept at \($0.path)." } ?? "")
                try self.show(try await engine.list())
            }
            importable = engine.importableLibrary()
        }
    }

    func dismissImport() {
        do {
            try SettingsStore.dismissImport(for: game, root: paths.root)
        } catch {
            errorMessage = "Could not save the settings: \(error.localizedDescription)"
        }
        dismissedImports.insert(game.id)
        importable = nil
    }

    func add(_ urls: [URL]) {
        guard !urls.isEmpty, let engine = requireEngine() else { return }
        Task {
            for url in urls {
                await run("Adding \(url.lastPathComponent)") {
                    let added = try await self.withProgress { progress in try await engine.add(url, progress: progress) }
                    try self.setups.recordAdded(added)
                    try self.show(added.mods)
                    if !added.warnings.isEmpty {
                        self.notice = "Part of \(added.name)'s code couldn't be stored and is left out: "
                            + added.warnings.prefix(3).joined(separator: "; ")
                            + (added.warnings.count > 3 ? "; and \(added.warnings.count - 3) more." : ".")
                    }
                }
            }
        }
    }

    func remove(_ mod: InstalledMod) {
        guard !isWorking else { return }
        if setups.otherVersionsByMod()[mod.id] != nil {
            changeSetup { $0.remove(mod.id) }
            updateVersionTargets()
            return
        }
        guard let engine = requireEngine() else { return }
        Task {
            await run("Removing \(mod.displayName)") {
                let library = try await engine.remove(mod.id)
                try self.setups.recordRemoved(mod.id)
                try self.show(library)
            }
        }
    }

    func setEnabled(_ mod: InstalledMod, _ enabled: Bool) {
        changeSetup { $0.setEnabled(mod.id, enabled) }
    }

    func move(_ mod: InstalledMod, to position: Int) {
        guard position >= 0, position < mods.count else { return }
        changeSetup { $0.move(mod.id, to: position) }
    }

    func setOption(_ mod: InstalledMod, group: Int, option: ModOption, selected: Bool) {
        guard group < mod.optionGroups.count else { return }
        changeSetup { try $0.select(option, in: mod.optionGroups[group], of: mod.id, selected: selected) }
    }

    func exportSetup() {
        guard let current = modSetup else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(game.name) \(current.setup.version) load order.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try JSONFile.encode(current.setup).write(to: url, options: .atomic)
        } catch {
            errorMessage = "Could not export the load order: \(error.localizedDescription)"
        }
    }

    func importSetup() {
        guard let current = modSetup else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let (imported, missing) = current.setup.importing(try ModSetup.read(from: url), library: rawLibrary)
            changeSetup { $0 = imported }
            notice = missing.isEmpty ? "Imported the load order from \(url.lastPathComponent)."
                : "Imported the load order from \(url.lastPathComponent). Not in your library, so left out: \(missing.joined(separator: ", "))."
        } catch {
            errorMessage = "Could not import the load order: \(error.localizedDescription)"
        }
    }

    func play(force: Bool = false) {
        guard !isWorking else { return }
        crash = nil
        notice = nil
        if gameRunning {
            if let identifier = game.bundleIdentifier {
                NSRunningApplication.runningApplications(withBundleIdentifier: identifier).first?.activate()
            }
            return
        }
        Task {
            if force || needsApply {
                guard await apply(force: force) else { return }
            }
            await launch()
        }
    }

    func apply(force: Bool = false) async -> Bool {
        guard let engine = requireEngine() else { return false }
        return await run("Preparing mods") {
            let mods = self.mods
            let outcome = try await self.withProgress { progress in
                try await engine.apply(mods, force: force) { progress(Self.message(for: $0)) }
            }
            self.state = ApplyState.load(from: self.paths)
            self.codeAtLaunchSupported = Applier.supportsCodeAtLaunch(settings: self.settings)
            let unfixable = outcome.statuses.filter { if case .unfixable = $0.analysis.outcome { true } else { false } }
            if !unfixable.isEmpty {
                self.notice = "Left out the code of " + unfixable.map(\.modName).joined(separator: ", ") + ": it can't run on the Mac."
            }
        }
    }

    nonisolated static func message(for stage: ApplyStage) -> String {
        switch stage {
        case .merging(let message): message
        case .checkingCode: "Checking code mods"
        case .rebuilding(let plan): plan.message
        case .building(let line): GameBuilder.status(forLine: line)
        case .installingData: "Installing data mods"
        }
    }

    private func launch() async {
        gameRunning = true
        do {
            try await GameLauncher.launch(settings: settings, paths: paths)
        } catch {
            gameRunning = false
            errorMessage = error.localizedDescription
        }
    }

    func gameDidExit() {
        gameRunning = false
        guard let launchDate = LaunchRecord.load(from: paths) else { return }
        LaunchRecord.save(nil, to: paths)
        switch GameExit.read(log: paths.gameLog, since: launchDate, game: game, state: state) {
        case .crashed(let report, let modId?):
            if let mod = mods.first(where: { $0.id == modId }) {
                crash = CrashNotice(modId: modId, modName: mod.displayName, detail: "The game crashed in code from \(mod.displayName) (at \(report.place)).")
            } else {
                crash = CrashNotice(modId: nil, modName: nil, detail: "The game crashed in code from a mod that is no longer in your list (at \(report.place)).")
            }
        case .crashed(let report, nil):
            crash = CrashNotice(modId: nil, modName: nil,
                                detail: "The game crashed at \(report.place), outside any mod's code. It may be a mod's data, or a problem in the game app itself.")
        case .stopped(let stop):
            errorMessage = "The game stopped: \(stop.reason)." + (stop.hint.map { " \(Self.text(for: $0))" } ?? "")
        case nil:
            break
        }
    }

    static func text(for hint: GameStop.Hint) -> String {
        switch hint {
        case .wakeDisplay: "The display was asleep or locked when the game started. Wake the Mac and press Play again."
        case .rebuildForCodeMods: "The code mods' patch file didn't match this game app. Choose Rebuild Game App in the File menu."
        case .reinstallMods: "A mod file changed after it was installed. Choose Apply Mod Changes in the File menu, then press Play."
        }
    }

    func disableCrashedModAndPlay() {
        guard let modId = crash?.modId, mods.contains(where: { $0.id == modId }) else { return }
        crash = nil
        changeSetup { $0.setEnabled(modId, false) }
        play()
    }

    func openLog() {
        NSWorkspace.shared.open(paths.gameLog)
    }

    private func requireEngine() -> (any ModEngine)? {
        if engine == nil { errorMessage = engineProblem }
        return engine
    }

    private func withProgress<T>(_ work: (@escaping @Sendable (String) -> Void) async throws -> T) async throws -> T {
        let (messages, continuation) = AsyncStream.makeStream(of: String.self, bufferingPolicy: .bufferingNewest(1))
        let display = Task {
            for await message in messages { activity = .working(message) }
        }
        do {
            let result = try await work { continuation.yield($0) }
            continuation.finish()
            await display.value
            return result
        } catch {
            continuation.finish()
            await display.value
            throw error
        }
    }

    @discardableResult
    private func run(_ message: String?, reading: Bool = false, _ work: @escaping @MainActor () async throws -> Void) async -> Bool {
        let previous = queue
        queuedTasks += 1
        let task = Task {
            _ = await previous?.value
            if let message {
                activity = reading ? .reading(message) : .working(message)
                errorMessage = nil
            }
            var succeeded = true
            do {
                try await work()
            } catch {
                succeeded = false
                errorMessage = error.localizedDescription
                state = ApplyState.load(from: paths)
                if let current = try? await engine?.list() {
                    try? show(current)
                }
            }
            if message != nil {
                activity = .idle
            }
            queuedTasks -= 1
            if queuedTasks == 0 { onIdle() }
            return succeeded
        }
        queue = task
        return await task.value
    }
}

