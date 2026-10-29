import Foundation

public struct GameScript: Sendable, Hashable {
    public let path: String
    public let purpose: String

    public init(path: String, purpose: String) {
        self.path = path
        self.purpose = purpose
    }
}

public protocol ModEngineSettings: Sendable, Hashable, Codable {
    var requiredFiles: [GameDefinition.FileSetting.Role] { get }
    var scripts: [GameScript] { get }
    func problems() -> [String]
    func makeEngine(settings: GraftSettings, paths: GraftPaths) throws -> any ModEngine
}

public enum ModSupport: Sendable, Hashable {
    case tksharp(TkSharpSettings)
    case files(FileModSettings)
    case unsupported(reason: String?)

    public enum Kind: String, Sendable, Hashable, Codable, CaseIterable, Identifiable {
        case tksharp
        case files
        case unsupported

        public var id: Self { self }

        public var title: String {
            switch self {
            case .tksharp: "Merge with TkSharp"
            case .files: "Replace game files"
            case .unsupported: "Not supported yet"
            }
        }

        public var summary: String {
            switch self {
            case .tksharp: "Merges mods file by file with TkSharp, the library TKMM uses, checks and fixes code mods, and can import a TKMM library. Tears of the Kingdom works this way."
            case .files: "Copies the mods that are on into the port's mod folder, with higher mods winning when two have the same file. For ports that load one folder of replacement game files."
            case .unsupported: "The game appears in Graft, but its mods can't be managed until Graft has an engine for them."
            }
        }

        public var modFormats: String? {
            switch self {
            case .tksharp: "zip, 7z, rar or tkcl files, or folders with romfs or exefs inside"
            case .files: ".pak files, zip, 7z or rar files, or folders with romfs or .pak files inside"
            case .unsupported: nil
            }
        }
    }

    public var kind: Kind {
        switch self {
        case .tksharp: .tksharp
        case .files: .files
        case .unsupported: .unsupported
        }
    }

    public var engineSettings: (any ModEngineSettings)? {
        switch self {
        case .tksharp(let settings): settings
        case .files(let settings): settings
        case .unsupported: nil
        }
    }

    public static func empty(_ kind: Kind) -> ModSupport {
        switch kind {
        case .tksharp: .tksharp(TkSharpSettings())
        case .files: .files(FileModSettings())
        case .unsupported: .unsupported(reason: nil)
        }
    }
}

extension ModSupport: Codable {
    private enum CodingKeys: String, CodingKey {
        case engine
        case reason
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .engine) {
        case .tksharp: self = .tksharp(try TkSharpSettings(from: decoder))
        case .files: self = .files(try FileModSettings(from: decoder))
        case .unsupported: self = .unsupported(reason: try container.decodeIfPresent(String.self, forKey: .reason))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .tksharp(let settings): try settings.encode(to: encoder)
        case .files(let settings): try settings.encode(to: encoder)
        case .unsupported(let reason):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(reason, forKey: .reason)
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .engine)
    }
}

public struct TkSharpSettings: ModEngineSettings {
    public struct CodeMods: Sendable, Hashable, Codable {
        public var launchVariable: String
        public var heapTable: String?
        public var heapRecord: String?
        public var buildIdFile: String?

        public init(launchVariable: String = "", heapTable: String? = nil, heapRecord: String? = nil, buildIdFile: String? = nil) {
            self.launchVariable = launchVariable
            self.heapTable = heapTable
            self.heapRecord = heapRecord
            self.buildIdFile = buildIdFile
        }
    }

    public struct Language: Sendable, Hashable, Codable, Identifiable {
        public var code: String
        public var name: String
        public var versions: [String]?

        public init(code: String, name: String, versions: [String]? = nil) {
            self.code = code
            self.name = name
            self.versions = versions
        }

        public var id: String { code }

        public func isAvailable(inVersion version: String?) -> Bool {
            guard let versions, !versions.isEmpty else { return true }
            return version.map(versions.contains) ?? false
        }
    }

    public var buildScript: String
    public var manifestScript: String
    public var patchSitesScript: String?
    public var codeMods: CodeMods?
    public var languages: [Language]
    public var titleText: Bool

    public init(buildScript: String = "", manifestScript: String = "", patchSitesScript: String? = nil, codeMods: CodeMods? = nil,
                languages: [Language] = [], titleText: Bool = false) {
        self.buildScript = buildScript
        self.manifestScript = manifestScript
        self.patchSitesScript = patchSitesScript
        self.codeMods = codeMods
        self.languages = languages
        self.titleText = titleText
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(buildScript: try container.decode(String.self, forKey: .buildScript),
                  manifestScript: try container.decode(String.self, forKey: .manifestScript),
                  patchSitesScript: try container.decodeIfPresent(String.self, forKey: .patchSitesScript),
                  codeMods: try container.decodeIfPresent(CodeMods.self, forKey: .codeMods),
                  languages: try container.decodeIfPresent([Language].self, forKey: .languages) ?? [],
                  titleText: try container.decodeIfPresent(Bool.self, forKey: .titleText) ?? false)
    }

    public var requiredFiles: [GameDefinition.FileSetting.Role] { [.gameApp, .baseGame, .update, .workFolder] }

    public var scripts: [GameScript] {
        [GameScript(path: buildScript, purpose: "rebuild the game app"),
         GameScript(path: manifestScript, purpose: "install data mods")]
            + (patchSitesScript.map { [GameScript(path: $0, purpose: "check code mods")] } ?? [])
    }

    public func problems() -> [String] {
        var problems: [String] = []
        if buildScript.isEmpty { problems.append("Enter the script that rebuilds the game app.") }
        if manifestScript.isEmpty { problems.append("Enter the script that writes the mod folder's manifest.") }
        if let codeMods, codeMods.launchVariable.isEmpty { problems.append("Enter the variable that passes code mods to the game, or turn code mods off.") }
        let codes = languages.map(\.code)
        if codes.contains(where: \.isEmpty) || languages.contains(where: { $0.name.isEmpty }) {
            problems.append("Every text language needs a code and a name.")
        }
        if Set(codes).count != codes.count { problems.append("Two text languages have the same code.") }
        return problems
    }

    public func makeEngine(settings: GraftSettings, paths: GraftPaths) throws -> any ModEngine {
        guard let executable = TkSharpEngine.locate() else {
            throw GraftError("This copy of Graft is incomplete: its merge helper (\(TkSharpEngine.executableName)) is missing. Build it again with make build.")
        }
        return TkSharpEngine(executable: executable, settings: settings, paths: paths)
    }
}

public struct FileModSettings: ModEngineSettings {
    public static let defaultPython = "venv/bin/python"
    public static let defaultAppGameFolder = "Contents/Resources/game"

    public var pakFolder: String
    public var manifestScript: String
    public var python: String
    public var appGameFolder: String

    public init(pakFolder: String = "", manifestScript: String = "", python: String = Self.defaultPython,
                appGameFolder: String = Self.defaultAppGameFolder) {
        self.pakFolder = pakFolder
        self.manifestScript = manifestScript
        self.python = python
        self.appGameFolder = appGameFolder
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(pakFolder: try container.decode(String.self, forKey: .pakFolder),
                  manifestScript: try container.decode(String.self, forKey: .manifestScript),
                  python: try container.decodeIfPresent(String.self, forKey: .python) ?? Self.defaultPython,
                  appGameFolder: try container.decodeIfPresent(String.self, forKey: .appGameFolder) ?? Self.defaultAppGameFolder)
    }

    public var requiredFiles: [GameDefinition.FileSetting.Role] { [.gameApp, .workFolder] }

    public var scripts: [GameScript] {
        [GameScript(path: manifestScript, purpose: "install data mods")]
    }

    public func problems() -> [String] {
        var problems: [String] = []
        if pakFolder.isEmpty { problems.append("Choose where loose .pak files go, so mods that are only .pak files can be added.") }
        if manifestScript.isEmpty { problems.append("Enter the port's manifest script.") }
        if python.isEmpty { problems.append("Enter the Python environment the port's build makes.") }
        if appGameFolder.isEmpty { problems.append("Enter the folder inside the game app that holds the game's files.") }
        return problems
    }

    public func makeEngine(settings: GraftSettings, paths: GraftPaths) throws -> any ModEngine {
        FileModEngine(settings: settings, paths: paths, fileMods: self,
                      otherGames: KnownGame.others(than: settings.definition, catalog: .shared, templates: .shared))
    }
}
