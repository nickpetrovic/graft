import Foundation

public struct LibraryImport: Sendable {
    public let paths: GraftPaths
    let home: URL

    public init(paths: GraftPaths, home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.paths = paths
        self.home = home
    }

    public var tkmmCandidates: [URL] {
        [
            home.appending(path: "Library/Application Support/tkmm2/.data2"),
            home.appending(path: "Games/TOTK Mods/TKMM/.data2"),
        ]
    }

    public func findTKMMLibrary() -> URL? {
        tkmmCandidates.first { FileManager.default.fileExists(atPath: $0.appending(path: "state.db").path) }
    }

    public var libraryIsEmpty: Bool {
        !FileManager.default.fileExists(atPath: paths.library.appending(path: "state.db").path)
    }

    @discardableResult
    public func importTKMM(from source: URL) throws -> URL? {
        let fm = FileManager.default
        try fm.createDirectory(at: paths.support, withIntermediateDirectories: true)
        let staging = paths.support.appending(path: "library.importing", directoryHint: .isDirectory)
        try? fm.removeItem(at: staging)
        try fm.copyItem(at: source, to: staging)
        defer { try? fm.removeItem(at: staging) }
        guard fm.fileExists(atPath: paths.library.path) else {
            try fm.moveItem(at: staging, to: paths.library)
            return nil
        }
        let backup = BackupName.unused(in: paths.support, prefix: "library.before-import")
        _ = try fm.replaceItemAt(paths.library, withItemAt: staging, backupItemName: backup.lastPathComponent,
                                 options: .withoutDeletingBackupItem)
        return backup
    }
}
