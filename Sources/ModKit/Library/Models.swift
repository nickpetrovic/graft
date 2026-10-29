import Foundation

public struct ModOption: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let selected: Bool
}

public struct ModOptionGroup: Codable, Sendable, Hashable {
    public enum Kind: String, Codable, Sendable {
        case single = "Single"
        case singleRequired = "SingleRequired"
        case multi = "Multi"
        case multiRequired = "MultiRequired"
    }

    public let name: String
    public let description: String
    public let type: Kind
    public let options: [ModOption]

    public var allowsMultiple: Bool { type == .multi || type == .multiRequired }
    public var isRequired: Bool { type == .singleRequired || type == .multiRequired }
}

public struct InstalledMod: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let version: String
    public let author: String
    public let description: String
    public let enabled: Bool
    public let position: Int
    public let dataFiles: Int
    public let textFiles: Int
    public let subSdkFiles: Int
    public let cheatFiles: Int
    public let codePatchBuilds: [String]
    public let optionGroups: [ModOptionGroup]

    public var hasData: Bool { dataFiles > 0 || textFiles > 0 }
    public var hasOptions: Bool { !optionGroups.isEmpty }

    public var selectedOptions: [String: [String]] {
        Dictionary(optionGroups.map { group in (group.name, group.options.filter(\.selected).map(\.name)) }, uniquingKeysWith: { first, _ in first })
    }
}

public struct ModList: Decodable, Sendable {
    public let mods: [InstalledMod]
}

public struct InstallResult: Decodable, Sendable {
    public let installed: String
    public let replacedIds: [String]
    public let keptCodeBuilds: [String]
    public let mods: [InstalledMod]
    public let warnings: [String]
}

public struct UpdateList: Decodable, Sendable {
    public let updates: [UpdateFile]
}

public struct UpdateFile: Decodable, Sendable, Equatable {
    public let path: String
    public let titleId: String
    public let displayVersion: String

    public init(path: String, titleId: String, displayVersion: String) {
        self.path = path
        self.titleId = titleId
        self.displayVersion = displayVersion
    }
}

public struct AddedMod: Sendable {
    public let id: String
    public let name: String
    public let replacedIds: [String]
    public let keptCodeBuilds: [String]
    public let warnings: [String]
    public let mods: [InstalledMod]
}

public struct PatchEntry: Decodable, Sendable, Hashable {
    public let address: UInt32
    public let data: [UInt8]

    public init(address: UInt32, data: [UInt8]) {
        self.address = address
        self.data = data
    }

    public init?(address: UInt32, hex: String) {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var data: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self.init(address: address, data: data)
    }

    enum CodingKeys: String, CodingKey {
        case address, bytes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let hex = try container.decode(String.self, forKey: .bytes)
        guard let entry = PatchEntry(address: try container.decode(UInt32.self, forKey: .address), hex: hex) else {
            throw DecodingError.dataCorruptedError(forKey: .bytes, in: container, debugDescription: "Not whole hex bytes: \(hex)")
        }
        self = entry
    }
}

public struct ModCodePatch: Decodable, Sendable, Hashable {
    public let modId: String
    public let modName: String
    public let entries: [PatchEntry]

    public init(modId: String, modName: String, entries: [PatchEntry]) {
        self.modId = modId
        self.modName = modName
        self.entries = entries
    }
}

public struct IgnoredCode: Decodable, Sendable, Hashable {
    public let modId: String
    public let modName: String
    public let subSdkFiles: Int
    public let patchesForOtherBuilds: Int
}

public struct MergeReport: Decodable, Sendable {
    public let buildId: String
    public let defaultPatches: [PatchEntry]
    public let codePatches: [ModCodePatch]
    public let ignoredCode: [IgnoredCode]

    public init(buildId: String, defaultPatches: [PatchEntry], codePatches: [ModCodePatch], ignoredCode: [IgnoredCode]) {
        self.buildId = buildId
        self.defaultPatches = defaultPatches
        self.codePatches = codePatches
        self.ignoredCode = ignoredCode
    }
}

public struct CodePatchFile: Decodable, Sendable {
    public let buildId: String
    public let entries: [PatchEntry]
    public let warnings: [String]
}
