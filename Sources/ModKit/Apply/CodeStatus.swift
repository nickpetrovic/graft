import Foundation

public enum CodeStatus: Codable, Sendable, Equatable {
    case ok
    case fixed
    case unfixable(String)

    public init(_ outcome: CodeAnalysis.Outcome) {
        switch outcome {
        case .unchanged: self = .ok
        case .relocated: self = .fixed
        case .unfixable(let reason): self = .unfixable(reason)
        }
    }
}
