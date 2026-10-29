import Foundation

public struct ModCodeStatus: Sendable, Equatable {
    public let modId: String
    public let modName: String
    public let analysis: CodeAnalysis
}

public struct ComposedCode: Sendable {
    public let pchtxt: String
    public let entryCount: Int
    public let owners: [UInt32: String]
    public let statuses: [ModCodeStatus]

    public var isEmpty: Bool { entryCount == 0 }

    public var digest: String {
        Hashing.sha256(Data(pchtxt.utf8))
    }
}

public enum PatchComposer {
    public static func compose(report: MergeReport, layout: GameLayout, reserved: [ReservedSite] = []) throws -> ComposedCode {
        var combined: [UInt32: UInt8] = [:]
        var owners: [UInt32: String] = [:]

        func apply(_ entries: [PatchEntry], owner: String?) {
            for entry in entries {
                for (offset, byte) in entry.data.enumerated() {
                    let (address, overflow) = entry.address.addingReportingOverflow(UInt32(offset))
                    if overflow { break }
                    combined[address] = byte
                    if let owner { owners[address] = owner } else { owners.removeValue(forKey: address) }
                }
            }
        }

        apply(report.defaultPatches, owner: nil)

        var order: [String] = []
        var grouped: [String: (name: String, entries: [PatchEntry])] = [:]
        for patch in report.codePatches {
            if grouped[patch.modId] == nil {
                order.append(patch.modId)
                grouped[patch.modId] = (patch.modName, [])
            }
            grouped[patch.modId]!.entries.append(contentsOf: patch.entries)
        }

        var statuses: [ModCodeStatus] = []
        var occupied: [FreeRange] = []
        for modId in order {
            guard let group = grouped[modId] else { continue }
            let analysis = try check(group.entries, name: group.name, layout: layout, reserved: reserved, occupied: occupied)
            statuses.append(ModCodeStatus(modId: modId, modName: group.name, analysis: analysis))
            if case .unfixable = analysis.outcome { continue }
            occupied += analysis.freeRanges
            apply(analysis.entries, owner: modId)
        }

        var lines = ["@nsobid-\(layout.buildId.uppercased())", "", "@flag offset_shift 0x100", "", "@enabled"]
        let words = Dictionary(grouping: combined.keys, by: { $0 & ~3 })
        var entryCount = 0
        for word in words.keys.sorted() {
            var offset: UInt32 = 0
            while offset < 4 {
                guard combined[word | offset] != nil else {
                    offset += 1
                    continue
                }
                let start = word | offset
                var run: [UInt8] = []
                var owner: String?
                while offset < 4, let byte = combined[word | offset] {
                    run.append(byte)
                    owner = owner ?? owners[word | offset]
                    offset += 1
                }
                lines.append(String(format: "%08x %@%@", start, run.map { String(format: "%02X", $0) }.joined(),
                                    owner.map { " // \($0)" } ?? ""))
                entryCount += 1
            }
        }
        lines.append("@stop")

        return ComposedCode(pchtxt: lines.joined(separator: "\n") + "\n", entryCount: entryCount, owners: owners,
                            statuses: statuses)
    }

    public static func check(_ entries: [PatchEntry], name: String, layout: GameLayout, reserved: [ReservedSite],
                             occupied: [FreeRange] = []) throws -> CodeAnalysis {
        let analysis = try PatchAnalyzer.analyze(entries: entries, layout: layout, owner: name, occupied: occupied)
        if case .unfixable = analysis.outcome { return analysis }
        guard let clash = clash(analysis.entries, reserved) else { return analysis }
        return CodeAnalysis(outcome: .unfixable("It changes code the Mac app patches itself (\(clash.label), main+0x\(String(clash.offset, radix: 16)))."),
                            entries: analysis.entries, notes: [], unsupportedInstructions: analysis.unsupportedInstructions,
                            freeRanges: [])
    }

    static func clash(_ entries: [PatchEntry], _ reserved: [ReservedSite]) -> ReservedSite? {
        for entry in entries {
            let length = UInt32(entry.data.count)
            if let site = reserved.first(where: { $0.overlaps(address: entry.address, length: length) }) {
                return site
            }
        }
        return nil
    }
}
