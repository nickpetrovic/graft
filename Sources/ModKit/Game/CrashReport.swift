import Foundation

public struct CrashReport: Sendable, Equatable {
    public let programCounter: UInt64?
    public let frames: [UInt64]
    public let signal: Int

    public var place: String {
        programCounter.map { String(format: "main+0x%llx", $0) } ?? "an unknown place"
    }

    public static func read(log: URL, since: Date, prefix: String) -> CrashReport? {
        GameLog.text(of: log, changedSince: since).flatMap { parse($0, prefix: prefix) }
    }

    public static func parse(_ text: String, prefix: String) -> CrashReport? {
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        let signalMarker = prefix + MacNativeGames.crashSignal
        guard let start = lines.lastIndex(where: { $0.hasPrefix(signalMarker) }) else { return nil }
        func hex(_ line: String, after marker: String) -> UInt64? {
            guard let range = line.range(of: marker) else { return nil }
            return UInt64(hex: line[range.upperBound...])
        }
        let mainOffset = "main" + MacNativeGames.moduleOffset
        let signal = hex(lines[start], after: signalMarker).flatMap { Int(exactly: $0) } ?? 0
        var programCounter: UInt64?
        var frames: [UInt64] = []
        var expectFrame = false
        for line in lines[(start + 1)...] {
            if line.hasPrefix("[") && !line.hasPrefix(prefix) { break }
            if line.hasPrefix(MacNativeGames.crashFrame) { expectFrame = true; continue }
            if line.hasPrefix(mainOffset), let value = hex(line, after: mainOffset) {
                if expectFrame { frames.append(value); expectFrame = false } else if programCounter == nil { programCounter = value }
            }
        }
        return CrashReport(programCounter: programCounter, frames: frames, signal: signal)
    }
}
