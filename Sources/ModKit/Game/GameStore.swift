import Foundation

public struct GameStore: Sendable {
    public static let fileName = "game.json"

    public let folder: URL

    public init(folder: URL) {
        self.folder = folder
    }

    public static var standard: GameStore {
        GameStore(folder: GraftPaths.standardRoot.appending(path: "games", directoryHint: .isDirectory))
    }

    public func file(for id: String) -> URL {
        folder.appending(path: "\(id)/\(Self.fileName)")
    }

    func gameFolders() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
            .filter { !$0.hasPrefix(".") && FileManager.default.fileExists(atPath: file(for: $0).path) }
            .sorted()
    }

    func definitionFiles() -> [URL] {
        gameFolders().map(file(for:))
    }

    public func load() -> GameCatalog {
        var games: [GameDefinition] = []
        var unreadable: [String: String] = [:]
        for id in gameFolders() {
            let url = file(for: id)
            do {
                let game = try Self.read(from: url)
                if game.id == id {
                    games.append(game)
                } else {
                    unreadable[id] = "\(url.path) describes \(game.id), but it is in the folder for \(id), so Graft left it out."
                }
            } catch {
                unreadable[id] = "\(url.path) couldn't be read: \(Self.describe(error))."
            }
        }
        return GameCatalog(games: games, unreadable: unreadable)
    }

    public func save(_ game: GameDefinition) throws {
        try JSONFile.write(game, to: file(for: game.id))
    }

    public func remove(id: String) throws {
        let url = file(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    public static func read(from url: URL) throws -> GameDefinition {
        try JSONDecoder().decode(GameDefinition.self, from: Data(contentsOf: url))
    }

    public static func export(_ game: GameDefinition, to url: URL) throws {
        var exported = game
        exported.template = nil
        try JSONFile.encode(exported).write(to: url, options: .atomic)
    }

    static func describe(_ error: any Error) -> String {
        var text = explanation(of: error)
        while text.hasSuffix(".") { text.removeLast() }
        return text
    }

    private static func explanation(of error: any Error) -> String {
        func path(_ keys: [any CodingKey]) -> String {
            keys.map { $0.intValue.map { "[\($0)]" } ?? ".\($0.stringValue)" }.joined().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }
        switch error as? DecodingError {
        case .keyNotFound(let key, let context)?:
            return "\(path(context.codingPath + [key])) is missing"
        case .typeMismatch(_, let context)?, .valueNotFound(_, let context)?:
            return "\(path(context.codingPath)): \(context.debugDescription)"
        case .dataCorrupted(let context)?:
            let underlying = (context.underlyingError as NSError?)?.userInfo[NSDebugDescriptionErrorKey] as? String
            let detail = [context.debugDescription, underlying].compactMap { $0 }.joined(separator: " ")
            return context.codingPath.isEmpty ? detail : "\(path(context.codingPath)): \(detail)"
        default:
            return error.localizedDescription
        }
    }
}
