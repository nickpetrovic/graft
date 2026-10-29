import Foundation

public struct GraftError: LocalizedError, CustomStringConvertible, Sendable {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? { message }

    public var description: String { message }
}
