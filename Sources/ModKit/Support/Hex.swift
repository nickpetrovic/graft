import Foundation

extension FixedWidthInteger {
    init?(hex text: some StringProtocol) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let digits = trimmed.lowercased().hasPrefix("0x") ? trimmed.dropFirst(2) : Substring(trimmed)
        self.init(digits, radix: 16)
    }
}
