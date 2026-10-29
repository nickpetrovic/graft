import CryptoKit
import Foundation

enum Hashing {
    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func sha256(of file: URL) throws -> String {
        sha256(try Data(contentsOf: file))
    }
}
