import Foundation
import Testing
@testable import ModKit

let layout121 = GameLayout(
    version: "v121",
    displayVersion: "1.2.1",
    buildId: "9b4e43650501a4d4489b4bbfdb740f26af3cf850",
    dataStart: 0x41aa000,
    imageEnd: 0x472b000,
    keyPageStart: 0x472c000
)

let templatesFolder = URL(fileURLWithPath: #filePath).appending(path: "../../../Resources/Templates").standardizedFileURL
let bundledTemplates = GameTemplates.load(from: [templatesFolder])
let totk = bundledTemplates.template(id: "totk")!.definition
let botw = bundledTemplates.template(id: "botw")!.definition
let ot0 = bundledTemplates.template(id: "ot0")!.definition

func fixture(_ name: String) throws -> String {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
    return try String(contentsOf: url, encoding: .utf8)
}

func codePatch(_ name: String) throws -> CodePatchFile {
    try JSONDecoder().decode(CodePatchFile.self, from: Data(try fixture("\(name).json").utf8))
}

func adrp(_ register: UInt32, at address: UInt32, page: UInt64) -> PatchEntry {
    PatchEntry(address: address, data: PatchAnalyzer.encodeAdrp(register: register, at: UInt64(address), target: page))
}

func instruction(_ address: UInt32, _ word: UInt32) -> PatchEntry {
    PatchEntry(address: address, data: [word, word >> 8, word >> 16, word >> 24].map { UInt8(truncatingIfNeeded: $0) })
}

func strX(_ rt: UInt32, base rn: UInt32, offset: UInt32) -> UInt32 { 0xF900_0000 | (offset / 8) << 10 | rn << 5 | rt }

func strW(_ rt: UInt32, base rn: UInt32, offset: UInt32) -> UInt32 { 0xB900_0000 | (offset / 4) << 10 | rn << 5 | rt }

func ldrX(_ rt: UInt32, base rn: UInt32, offset: UInt32) -> UInt32 { 0xF940_0000 | (offset / 8) << 10 | rn << 5 | rt }

func ldrW(_ rt: UInt32, base rn: UInt32, offset: UInt32) -> UInt32 { 0xB940_0000 | (offset / 4) << 10 | rn << 5 | rt }

func addX(_ rd: UInt32, _ rn: UInt32, _ immediate: UInt32) -> UInt32 { 0x9100_0000 | immediate << 10 | rn << 5 | rd }

let codePage: UInt64 = 0xf0000

func mod(_ id: String, name: String? = nil, position: Int = 0, enabled: Bool = true, dataFiles: Int = 1, textFiles: Int = 0,
         subSdkFiles: Int = 0, cheatFiles: Int = 0, codePatchBuilds: [String] = [], groups: [ModOptionGroup] = [],
         version: String = "", author: String = "", description: String = "") -> InstalledMod {
    InstalledMod(id: id, name: name ?? "Mod \(id)", version: version, author: author, description: description, enabled: enabled,
                 position: position, dataFiles: dataFiles, textFiles: textFiles, subSdkFiles: subSdkFiles, cheatFiles: cheatFiles,
                 codePatchBuilds: codePatchBuilds, optionGroups: groups)
}

func optionGroup(_ name: String, _ type: ModOptionGroup.Kind, _ options: [String], selected: [String] = []) -> ModOptionGroup {
    ModOptionGroup(name: name, description: "", type: type,
                   options: options.map { ModOption(id: "\(name)-\($0)", name: $0, description: "", selected: selected.contains($0)) })
}

final class TemporaryFolder {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory.appending(path: "ModKitTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    var paths: GraftPaths {
        GraftPaths(root: url.appending(path: "support"), support: url.appending(path: "support"),
                   gameData: url.appending(path: "game"), gameLog: url.appending(path: "totk.log"))
    }

    func path(_ relativePath: String) -> String {
        url.appending(path: relativePath).path
    }

    @discardableResult
    func write(_ relativePath: String, _ text: String = "", executable: Bool = false) throws -> URL {
        let file = url.appending(path: relativePath)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: file, atomically: true, encoding: .utf8)
        if executable {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        }
        return file
    }

    @discardableResult
    func app(_ relativePath: String, identifier: String? = nil, version: String? = nil, info: [String: String] = [:]) throws -> String {
        var plist = info
        plist["CFBundleIdentifier"] = identifier
        plist["CFBundleShortVersionString"] = version
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        return try write("\(relativePath).app/Contents/Info.plist", String(decoding: data, as: UTF8.self))
            .deletingLastPathComponent().deletingLastPathComponent().path
    }

    func contents(of relativePath: String) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: url.appending(path: relativePath).path).filter { !$0.hasPrefix(".") }.sorted()
    }
}

func backgroundSleep(in folder: TemporaryFolder) -> [String] {
    ["-c", "sleep 30 & echo $! > '\(folder.path("sleeper.pid"))'; wait"]
}

func backgroundPid(in folder: TemporaryFolder) async throws -> pid_t {
    let file = folder.url.appending(path: "sleeper.pid")
    for _ in 0..<100 {
        if let text = try? String(contentsOf: file, encoding: .utf8), let pid = pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return pid
        }
        try await Task.sleep(for: .milliseconds(50))
    }
    throw GraftError("The background process never started.")
}

func hasExited(_ pid: pid_t) async -> Bool {
    for _ in 0..<60 {
        if kill(pid, 0) != 0 { return true }
        try? await Task.sleep(for: .milliseconds(50))
    }
    return false
}
