import Foundation
import Synchronization

struct FileStamp: Equatable, Sendable {
    let modified: Date?
    let size: UInt64?
    let inode: UInt64?

    init?(_ url: URL) {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.resolvingSymlinksInPath().path) else { return nil }
        modified = attributes[.modificationDate] as? Date
        size = (attributes[.size] as? NSNumber)?.uint64Value
        inode = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value
    }

    static func of(_ files: [URL]) -> [String: FileStamp] {
        var stamps: [String: FileStamp] = [:]
        for file in files {
            stamps[file.path] = FileStamp(file)
        }
        return stamps
    }
}

final class StampedCache<Value: Sendable>: Sendable {
    private let cached = Mutex<(stamps: [String: FileStamp], value: Value)?>(nil)

    func value(for files: [URL], load: () -> Value) -> Value {
        let stamps = FileStamp.of(files)
        return cached.withLock { cached in
            if let cached, cached.stamps == stamps { return cached.value }
            let value = load()
            cached = (stamps, value)
            return value
        }
    }
}
