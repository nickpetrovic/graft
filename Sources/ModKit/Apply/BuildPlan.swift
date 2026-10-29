import Foundation

public struct BuildPlan: Sendable, Equatable {
    public enum Reason: Sendable, Equatable {
        case requested
        case buildInCode
        case removeBuiltInCode
        case memorySizes

        var text: String {
            switch self {
            case .requested: "as you asked"
            case .buildInCode: "to build in code mods"
            case .removeBuiltInCode: "to remove built-in code mods"
            case .memorySizes: "because the memory sizes changed"
            }
        }
    }

    public let codeAtLaunch: Bool
    public let bakedCode: String?
    public let reasons: [Reason]

    public init(codeAtLaunch: Bool, bakedCode: String?, reasons: [Reason]) {
        self.codeAtLaunch = codeAtLaunch
        self.bakedCode = bakedCode
        self.reasons = reasons
    }

    public var needsBuild: Bool { !reasons.isEmpty }

    public var message: String { "Rebuilding the game app " + reasons.map(\.text).joined(separator: ", ") }

    public static func decide(codeDigest: String?, needsRewriter: Bool, appSupportsCodeAtLaunch: Bool,
                              builtCodeDigest: String?, heapDigest: String?, appHeapDigest: String?,
                              force: Bool) -> BuildPlan {
        let alreadyBuiltIn = codeDigest != nil && codeDigest == builtCodeDigest
        let codeAtLaunch = codeDigest != nil && !needsRewriter && !alreadyBuiltIn && appSupportsCodeAtLaunch
        let bakedCode = codeAtLaunch ? nil : codeDigest
        var reasons: [Reason] = []
        if force { reasons.append(.requested) }
        if bakedCode != builtCodeDigest { reasons.append(bakedCode == nil ? .removeBuiltInCode : .buildInCode) }
        if heapDigest != appHeapDigest { reasons.append(.memorySizes) }
        return BuildPlan(codeAtLaunch: codeAtLaunch, bakedCode: bakedCode, reasons: reasons)
    }
}
