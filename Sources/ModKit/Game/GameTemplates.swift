import Foundation

public struct GameTemplate: Sendable, Hashable, Identifiable, Codable {
    private enum CodingKeys: String, CodingKey {
        case revision
    }

    public let revision: Int
    public let definition: GameDefinition

    public init(revision: Int = 1, definition: GameDefinition) {
        self.revision = revision
        self.definition = definition
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 1
        definition = try GameDefinition(from: decoder)
    }

    public func encode(to encoder: any Encoder) throws {
        var stripped = definition
        stripped.template = nil
        try stripped.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(revision, forKey: .revision)
    }

    public var id: String { definition.id }

    public var reference: GameDefinition.TemplateReference {
        GameDefinition.TemplateReference(id: id, revision: revision)
    }

    public func game() -> GameDefinition {
        var game = definition
        game.template = reference
        return game
    }

    public func isNewer(than game: GameDefinition) -> Bool {
        guard let reference = game.template, reference.id == id else { return false }
        return revision > reference.revision
    }
}

public struct GameTemplates: Sendable, Equatable {
    public let templates: [GameTemplate]
    public let problems: [String]

    public init(templates: [GameTemplate], problems: [String] = []) {
        self.templates = templates.sorted { $0.definition.name.localizedStandardCompare($1.definition.name) == .orderedAscending }
        self.problems = problems
    }

    public static var userFolder: URL {
        GraftPaths.standardRoot.appending(path: "Templates", directoryHint: .isDirectory)
    }

    static var bundledFolder: URL? {
        var candidates: [URL] = []
        if let resources = Bundle.main.resourceURL {
            candidates.append(resources.appending(path: "Templates"))
        }
        if let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() {
            candidates.append(executable.deletingLastPathComponent().appending(path: "../Resources/Templates").standardizedFileURL)
        }
        #if DEBUG
        candidates.append(URL(fileURLWithPath: #filePath).appending(path: "../../../../Resources/Templates").standardizedFileURL)
        #endif
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static let cache = StampedCache<GameTemplates>()

    public static var shared: GameTemplates {
        let folders = [bundledFolder, userFolder].compactMap { $0 }
        return cache.value(for: folders.flatMap(files(in:))) { load(from: folders) }
    }

    static func files(in folder: URL) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public static func load(from folders: [URL]) -> GameTemplates {
        var byId: [String: GameTemplate] = [:]
        var problems: [String] = []
        for file in folders.flatMap(files(in:)) {
            do {
                let template = try JSONDecoder().decode(GameTemplate.self, from: Data(contentsOf: file))
                byId[template.id] = template
            } catch {
                problems.append("The template \(file.path) couldn't be read: \(GameStore.describe(error)).")
            }
        }
        return GameTemplates(templates: Array(byId.values), problems: problems)
    }

    public func template(id: String) -> GameTemplate? {
        templates.first { $0.id == id }
    }

    public func template(bundleIdentifier: String) -> GameTemplate? {
        templates.first { $0.definition.bundleIdentifier == bundleIdentifier }
    }

    public func template(portFolder: String) -> GameTemplate? {
        templates.first { $0.definition.macNativeGamesFolder == portFolder }
    }

    public func update(for game: GameDefinition) -> GameTemplate? {
        guard let reference = game.template, let template = template(id: reference.id), template.isNewer(than: game) else { return nil }
        return template
    }
}
