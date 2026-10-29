import Foundation

public enum JSONFile {
    public static func encode(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    static func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T? {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw GraftError("\(url.path) couldn't be read: it isn't valid JSON for Graft. Fix or delete it, then try again.")
        }
    }

    static func write(_ value: some Encodable, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encode(value).write(to: url, options: .atomic)
    }
}
