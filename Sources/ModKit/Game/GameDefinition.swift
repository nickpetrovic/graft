import Foundation

public struct GameDefinition: Sendable, Hashable, Identifiable, Codable {
    public struct App: Sendable, Hashable, Codable {
        public var bundleIdentifier: String
        public var fileName: String?
        public var workFolderKey: String?

        public init(bundleIdentifier: String, fileName: String? = nil, workFolderKey: String? = nil) {
            self.bundleIdentifier = bundleIdentifier
            self.fileName = fileName
            self.workFolderKey = workFolderKey
        }
    }

    public struct Log: Sendable, Hashable, Codable {
        public var file: String?
        public var linePrefix: String?
        public var enableVariable: String?

        public init(file: String? = nil, linePrefix: String? = nil, enableVariable: String? = nil) {
            self.file = file
            self.linePrefix = linePrefix
            self.enableVariable = enableVariable
        }
    }

    public struct VersionFolders: Sendable, Hashable, Codable {
        public var prefix: String
        public var exceptions: [String: String]

        public init(prefix: String = "v", exceptions: [String: String] = [:]) {
            self.prefix = prefix
            self.exceptions = exceptions
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            prefix = try container.decodeIfPresent(String.self, forKey: .prefix) ?? "v"
            exceptions = try container.decodeIfPresent([String: String].self, forKey: .exceptions) ?? [:]
        }

        public func folder(forDisplayVersion display: String) -> String {
            exceptions[display] ?? prefix + display.replacingOccurrences(of: ".", with: "")
        }
    }

    public struct ModSignatures: Sendable, Hashable, Codable {
        public var extensions: [String]
        public var folders: [String]

        public init(extensions: [String] = [], folders: [String] = []) {
            self.extensions = extensions
            self.folders = folders
        }

        public var isEmpty: Bool { extensions.isEmpty && folders.isEmpty }

        public func matches(_ path: String) -> Bool {
            let path = path.lowercased()
            return extensions.contains { path.hasSuffix($0.lowercased()) } || folders.contains { path.hasPrefix($0.lowercased()) }
        }
    }

    public struct FileSetting: Sendable, Hashable, Codable, Identifiable {
        public enum Role: String, Sendable, Hashable, Codable, CaseIterable, Identifiable {
            case gameApp, baseGame, update, workFolder

            public var id: Self { self }

            public var kind: Kind {
                switch self {
                case .gameApp: .application
                case .baseGame, .update: .file
                case .workFolder: .folder
                }
            }

            public var title: String {
                switch self {
                case .gameApp: "Game app"
                case .baseGame: "Base game"
                case .update: "Update"
                case .workFolder: "Work folder"
                }
            }
        }

        public enum Kind: String, Sendable, Hashable {
            case application, file, folder
        }

        public var role: Role
        public var label: String
        public var summary: String
        public var detail: String

        public init(role: Role, label: String? = nil, summary: String = "", detail: String = "") {
            self.role = role
            self.label = label ?? role.title
            self.summary = summary
            self.detail = detail
        }

        public var id: Role { role }
        public var kind: Kind { role.kind }
    }

    public struct TemplateReference: Sendable, Hashable, Codable {
        public var id: String
        public var revision: Int

        public init(id: String, revision: Int) {
            self.id = id
            self.revision = revision
        }
    }

    public var id: String
    public var name: String
    public var titleId: String
    public var updateTitleId: String?
    public var macNativeGamesFolder: String?
    public var app: App?
    public var dataFolder: String?
    public var workFolder: String?
    public var workTree: String?
    public var log: Log?
    public var versionFolders: VersionFolders?
    public var files: [FileSetting]
    public var modSignatures: ModSignatures?
    public var mods: ModSupport
    public var template: TemplateReference?

    public init(id: String, name: String, titleId: String, updateTitleId: String? = nil, macNativeGamesFolder: String? = nil,
                app: App? = nil, dataFolder: String? = nil, workFolder: String? = nil, workTree: String? = nil, log: Log? = nil,
                versionFolders: VersionFolders? = nil, files: [FileSetting] = [], modSignatures: ModSignatures? = nil,
                mods: ModSupport = .unsupported(reason: nil), template: TemplateReference? = nil) {
        self.id = id
        self.name = name
        self.titleId = titleId
        self.updateTitleId = updateTitleId
        self.macNativeGamesFolder = macNativeGamesFolder
        self.app = app
        self.dataFolder = dataFolder
        self.workFolder = workFolder
        self.workTree = workTree
        self.log = log
        self.versionFolders = versionFolders
        self.files = files
        self.modSignatures = modSignatures
        self.mods = mods
        self.template = template
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            titleId: try container.decode(String.self, forKey: .titleId),
            updateTitleId: try container.decodeIfPresent(String.self, forKey: .updateTitleId),
            macNativeGamesFolder: try container.decodeIfPresent(String.self, forKey: .macNativeGamesFolder),
            app: try container.decodeIfPresent(App.self, forKey: .app),
            dataFolder: try container.decodeIfPresent(String.self, forKey: .dataFolder),
            workFolder: try container.decodeIfPresent(String.self, forKey: .workFolder),
            workTree: try container.decodeIfPresent(String.self, forKey: .workTree),
            log: try container.decodeIfPresent(Log.self, forKey: .log),
            versionFolders: try container.decodeIfPresent(VersionFolders.self, forKey: .versionFolders),
            files: try container.decodeIfPresent([FileSetting].self, forKey: .files) ?? [],
            modSignatures: try container.decodeIfPresent(ModSignatures.self, forKey: .modSignatures),
            mods: try container.decodeIfPresent(ModSupport.self, forKey: .mods) ?? .unsupported(reason: nil),
            template: try container.decodeIfPresent(TemplateReference.self, forKey: .template))
    }

    public var bundleIdentifier: String? { app?.bundleIdentifier }
    public var appFileName: String? { app.map { $0.fileName ?? "\(name).app" } }
    public var workFolderName: String { workFolder ?? "\(id)_build" }
    public var workTreeName: String { workTree ?? "" }
    public var logFileName: String { log?.file ?? id }
    public var logLinePrefix: String { log?.linePrefix ?? "[\(id)]" }
    public var tkSharp: TkSharpSettings? { if case .tksharp(let settings) = mods { settings } else { nil } }
    public var fileMods: FileModSettings? { if case .files(let settings) = mods { settings } else { nil } }
    public var supportsTitleText: Bool { tkSharp?.titleText ?? false }

    public var unsupportedReason: String? {
        guard case .unsupported(let reason) = mods else { return nil }
        return reason ?? "Graft can't manage \(name) mods yet."
    }

    public func languages(inVersion version: String?) -> [TkSharpSettings.Language] {
        (tkSharp?.languages ?? []).filter { $0.isAvailable(inVersion: version) }
    }

    public func versionFolder(forDisplayVersion display: String) -> String {
        (versionFolders ?? VersionFolders()).folder(forDisplayVersion: display)
    }
}
