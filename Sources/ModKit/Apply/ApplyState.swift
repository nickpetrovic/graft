import Foundation

public struct ApplyState: Codable, Sendable, Equatable {
    public var builtCode: [String: String] = [:]
    public var appliedModsDigest: String?
    public var owners: [String: String] = [:]
    public var codeStatus: [String: CodeStatus] = [:]
    public var codeAtLaunch = false

    public init() {}

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func field<T: Decodable>(_ key: CodingKeys) -> T? {
            try? container.decodeIfPresent(T.self, forKey: key)
        }
        builtCode = field(.builtCode) ?? [:]
        appliedModsDigest = field(.appliedModsDigest)
        owners = field(.owners) ?? [:]
        codeStatus = field(.codeStatus) ?? [:]
        codeAtLaunch = field(.codeAtLaunch) ?? false
    }

    public static func load(from paths: GraftPaths) -> ApplyState {
        (try? JSONFile.read(ApplyState.self, from: paths.stateFile)) ?? ApplyState()
    }

    public func save(to paths: GraftPaths) throws {
        try JSONFile.write(self, to: paths.stateFile)
    }

    public mutating func recordOwners(_ addresses: [UInt32: String]) {
        owners = Dictionary(uniqueKeysWithValues: addresses.map { (String(format: "%08x", $0.key), $0.value) })
    }

    public func owner(of address: UInt64) -> String? {
        let word = UInt32(truncatingIfNeeded: address & ~3)
        return (0..<4).lazy.compactMap { self.owners[String(format: "%08x", word &+ $0)] }.first
    }

    public func crashOwner(_ report: CrashReport) -> String? {
        let candidates = [report.programCounter].compactMap { $0 } + report.frames.filter { $0 >= 4 }.map { $0 - 4 }
        return candidates.lazy.compactMap(owner(of:)).first
    }
}
