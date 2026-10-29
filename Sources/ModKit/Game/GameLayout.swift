import Foundation

public struct GameLayout: Sendable, Equatable {
    public let version: String
    public let displayVersion: String
    public let buildId: String
    public let dataStart: UInt32
    public let imageEnd: UInt32
    public let keyPageStart: UInt32

    public init(version: String, displayVersion: String, buildId: String, dataStart: UInt32, imageEnd: UInt32, keyPageStart: UInt32) {
        self.version = version
        self.displayVersion = displayVersion
        self.buildId = buildId
        self.dataStart = dataStart
        self.imageEnd = imageEnd
        self.keyPageStart = keyPageStart
    }

    public var freeStart: UInt32 { (imageEnd + 0xfff) & ~0xfff }

    public var freeEnd: UInt32 { keyPageStart }

    public func isWritable(_ address: UInt64) -> Bool {
        address >= UInt64(dataStart) && address < UInt64(freeEnd)
    }

    public func isInsideMain(_ address: UInt64) -> Bool {
        address < UInt64(keyPageStart)
    }

    public static func load(for settings: GraftSettings) throws -> GameLayout {
        try load(workFolder: URL(fileURLWithPath: settings.game.workFolder), gameApp: settings.game.gameApp, game: settings.definition)
    }

    public static func load(workFolder: URL, gameApp: String, game: GameDefinition) throws -> GameLayout {
        let display = try AppBundle.requireShortVersion(at: gameApp)
        let version = game.versionFolder(forDisplayVersion: display)
        let tree = workFolder.appending(path: game.workTreeName)

        func missing(_ file: URL) -> GraftError {
            GraftError("The work folder has no \(file.path), so Graft can't read how the \(display) game code is laid out. Build the \(display) game app with MacNativeGames in this work folder.")
        }

        let nso = tree.appending(path: "extracted/\(version)/exefs/main")
        guard let handle = try? FileHandle(forReadingFrom: nso) else { throw missing(nso) }
        defer { try? handle.close() }
        guard let header = try handle.read(upToCount: 0x100), header.count == 0x100 else {
            throw GraftError("Graft couldn't read \(nso.path).")
        }
        func word(_ offset: Int) -> UInt32 {
            header.subdata(in: offset..<offset + 4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        }
        let dataMemoryOffset = word(0x34)
        let dataSize = word(0x38)
        let bssSize = word(0x3c)
        let buildId = header.subdata(in: 0x40..<0x54).map { String(format: "%02x", $0) }.joined()

        let fixups = tree.appending(path: "rewritten/\(version)/main.fixups.tsv")
        guard let text = try? String(contentsOf: fixups, encoding: .utf8) else { throw missing(fixups) }
        var values: [String: UInt32] = [:]
        for line in text.split(separator: "\n") where line.hasPrefix("# ") {
            let parts = line.dropFirst(2).split(separator: "\t")
            if parts.count == 2, let value = UInt32(hex: parts[1]) {
                values[String(parts[0])] = value
            }
        }
        guard let data = values["DATA_OFF"],
              let keyPage = values["KEY_PAGE_OFF"] else {
            throw GraftError("Graft couldn't read the memory layout in \(fixups.path).")
        }

        let imageEnd = UInt64(dataMemoryOffset) + UInt64(dataSize) + UInt64(bssSize)
        guard imageEnd <= UInt64(UInt32.max - 0xfff) else {
            throw GraftError("Graft couldn't read \(nso.path): its sizes don't fit in the game's address space.")
        }

        return GameLayout(
            version: version,
            displayVersion: display,
            buildId: buildId,
            dataStart: data,
            imageEnd: UInt32(imageEnd),
            keyPageStart: keyPage
        )
    }
}
