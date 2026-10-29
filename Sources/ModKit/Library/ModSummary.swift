import Foundation

extension InstalledMod {
    public var displayName: String { name.isEmpty ? "Unnamed mod" : name }

    public var credit: String? {
        let version = version.isEmpty || version == "1.0.0" ? nil : version
        let author = author.isEmpty ? nil : author
        switch (version, author) {
        case let (version?, author?): return "Version \(version) by \(author)"
        case let (version?, nil): return "Version \(version)"
        case let (nil, author?): return "By \(author)"
        default: return nil
        }
    }

    public func changesCode(buildId: String?) -> Bool {
        buildId.map { codePatchBuilds.contains($0) } ?? !codePatchBuilds.isEmpty
    }

    public func contentSummary(buildId: String?) -> String? {
        let files = dataFiles + textFiles
        let count = counted(files, "file")
        switch (changesCode(buildId: buildId), files > 0) {
        case (true, true): return "Game code and \(count)"
        case (true, false): return "Game code"
        case (false, true): return counted(files, "game file")
        case (false, false): return nil
        }
    }

    public func summaryLine(buildId: String?) -> String {
        [credit, contentSummary(buildId: buildId)].compactMap { $0 }.joined(separator: " · ")
    }
}
