import Foundation

public struct ReservedSite: Decodable, Sendable, Hashable {
    public let label: String
    public let offset: UInt32
    public let size: UInt32

    public init(label: String, offset: UInt32, size: UInt32) {
        self.label = label
        self.offset = offset
        self.size = size
    }

    enum CodingKeys: String, CodingKey {
        case label, offset, size
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let text = try container.decode(String.self, forKey: .offset)
        guard let offset = UInt32(hex: text) else {
            throw DecodingError.dataCorruptedError(forKey: .offset, in: container, debugDescription: "Not a hex offset: \(text)")
        }
        self.init(label: try container.decode(String.self, forKey: .label), offset: offset,
                  size: try container.decodeIfPresent(UInt32.self, forKey: .size) ?? 4)
    }

    public func overlaps(address: UInt32, length: UInt32) -> Bool {
        UInt64(address) < UInt64(offset) + UInt64(size) && UInt64(offset) < UInt64(address) + UInt64(length)
    }
}
