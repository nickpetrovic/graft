import Foundation

enum GameLog {
    static func text(of log: URL, changedSince date: Date) -> String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: log.path),
              let modified = attributes[.modificationDate] as? Date, modified >= date else { return nil }
        return try? String(contentsOf: log, encoding: .utf8)
    }
}
