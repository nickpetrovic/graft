import Foundation

enum BackupName {
    static func unused(in folder: URL, prefix: String, date: Date = Date()) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stem = "\(prefix)-\(formatter.string(from: date))"
        var candidate = folder.appending(path: stem, directoryHint: .isDirectory)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appending(path: "\(stem)-\(counter)", directoryHint: .isDirectory)
            counter += 1
        }
        return candidate
    }
}
