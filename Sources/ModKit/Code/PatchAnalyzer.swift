import Foundation

public struct FreeRange: Sendable, Equatable {
    public let start: UInt64
    public let end: UInt64
    public let owner: String

    public init(start: UInt64, end: UInt64, owner: String) {
        self.start = start
        self.end = end
        self.owner = owner
    }

    func overlaps(_ other: FreeRange) -> Bool { start < other.end && other.start < end }
}

public struct CodeAnalysis: Sendable, Equatable {
    public enum Outcome: Sendable, Equatable {
        case unchanged
        case relocated(movedInstructions: Int, droppedInitializers: Int)
        case unfixable(String)
    }

    public let outcome: Outcome
    public let entries: [PatchEntry]
    public let notes: [String]
    public let unsupportedInstructions: [String]
    public let freeRanges: [FreeRange]
}

public enum PatchAnalyzer {
    struct Access {
        let adrp: UInt64
        let page: UInt64
        let offset: Int64
        let size: Int
        let isWrite: Bool

        var location: Int64 { Int64(page) + offset }
        var address: UInt64 { UInt64(location) }
    }

    struct Trace {
        var accesses: [Access] = []
        var complete = true
    }

    static let argumentRegisters: Set<String> = Set((0...7).map { "x\($0)" })
    static let calleeSavedRegisters: Set<String> = Set((19...29).map { "x\($0)" }).union(["sp"])
    static let traceLimit = 1024

    public static func analyze(entries: [PatchEntry], layout: GameLayout, owner: String = "",
                               occupied: [FreeRange] = []) throws -> CodeAnalysis {
        let disassembler = try Disassembler()
        var bytesByAddress: [UInt64: [UInt8]] = [:]
        for entry in entries {
            let data = entry.data
            for offset in stride(from: 0, to: data.count, by: 4) where offset + 4 <= data.count {
                bytesByAddress[UInt64(entry.address) + UInt64(offset)] = Array(data[offset..<offset + 4])
            }
        }

        var instructions: [UInt64: Instruction] = [:]
        for (address, bytes) in bytesByAddress {
            if let instruction = disassembler.decode(bytes, at: address) {
                instructions[address] = instruction
            }
        }

        let unsupported = instructions.values
            .compactMap { instruction in instruction.unsupportedReason.map { String(format: "main+0x%llx ", instruction.address) + $0 } }
            .sorted()

        func result(_ outcome: CodeAnalysis.Outcome, _ entries: [PatchEntry], _ notes: [String] = [],
                    _ ranges: [FreeRange] = []) -> CodeAnalysis {
            CodeAnalysis(outcome: outcome, entries: entries, notes: notes, unsupportedInstructions: unsupported, freeRanges: ranges)
        }
        func unfixable(_ reason: String) -> CodeAnalysis {
            result(.unfixable("It writes into the game's read-only code memory, and \(reason)."), entries)
        }

        var traces: [UInt64: Trace] = [:]
        var adrpPages: [UInt64: UInt64] = [:]
        for instruction in instructions.values where instruction.isAdrp {
            guard case .register(let register)? = instruction.operands.first,
                  case .immediate(let page)? = instruction.operands.dropFirst().first else { continue }
            let target = UInt64(bitPattern: page)
            guard layout.isInsideMain(target) else { continue }
            adrpPages[instruction.address] = target
            traces[instruction.address] = follow(from: instruction.address, register: register, page: target, instructions: instructions)
        }

        let ownPages = Set(bytesByAddress.keys.map { $0 & ~0xfff })
        for (adrp, page) in adrpPages.sorted(by: { $0.key < $1.key })
        where traces[adrp]?.complete == false && ownPages.contains(page) && !layout.isWritable(page) {
            return result(.unfixable(String(format: "Graft can't follow every use of the address computed at main+0x%llx, so it can't confirm that the mod leaves the game's read-only code memory alone.", adrp)), entries)
        }

        let accesses = traces.keys.sorted().flatMap { traces[$0]?.accesses ?? [] }
        if let outside = accesses.first(where: { $0.location < 0 }) {
            return unfixable(String(format: "the instruction at main+0x%llx points before the start of the game's code", outside.adrp))
        }
        let freeStart = UInt64(layout.freeStart)
        let freeEnd = UInt64(layout.freeEnd)
        let alreadyFree = accesses
            .filter { $0.address >= freeStart && $0.address < freeEnd }
            .map { FreeRange(start: $0.address, end: $0.address + UInt64($0.size), owner: owner) }
        if let clash = alreadyFree.first(where: { range in occupied.contains { $0.overlaps(range) } }),
           let other = occupied.first(where: { $0.overlaps(clash) }) {
            return result(.unfixable("Its values in writable memory overlap \(other.owner)'s."), entries)
        }

        let codeWrites = accesses.filter { $0.isWrite && layout.isInsideMain($0.address) && !layout.isWritable($0.address) }
        if codeWrites.isEmpty {
            return result(.unchanged, entries, [], alreadyFree)
        }

        if let foreign = codeWrites.first(where: { !ownPages.contains($0.page) }) {
            return unfixable(String(format: "the value at main+0x%llx belongs to the game, so moving it would leave the game reading the old value", foreign.address))
        }

        let movedPages = Set(codeWrites.map(\.page))
        for (adrp, page) in adrpPages.sorted(by: { $0.key < $1.key }) where movedPages.contains(page) && (traces[adrp]?.accesses ?? []).isEmpty {
            return unfixable(String(format: "an instruction at main+0x%llx points at a page it writes to without a load or store this tool can follow", adrp))
        }

        let movedAccesses = accesses.filter { movedPages.contains($0.page) }
        struct Slot: Hashable { let page: UInt64; let offset: Int64 }
        var slotSizes: [Slot: Int] = [:]
        for access in movedAccesses {
            let slot = Slot(page: access.page, offset: access.offset)
            slotSizes[slot] = max(slotSizes[slot] ?? 0, access.size)
        }
        let writtenSlots = Set(movedAccesses.filter(\.isWrite).map { Slot(page: $0.page, offset: $0.offset) })
        func initialized(_ slot: Slot, size: Int) -> Bool {
            let start = Int64(slot.page) + slot.offset
            return stride(from: start & ~3, to: start + Int64(size), by: 4).allSatisfy { bytesByAddress[UInt64($0)] != nil }
        }
        for (slot, size) in slotSizes.sorted(by: { $0.key.offset < $1.key.offset }) where !writtenSlots.contains(slot) && !initialized(slot, size: size) {
            return unfixable(String(format: "it also reads main+0x%llx on that page, a value it never sets, so moving it would lose the game's data",
                                    Int64(slot.page) + slot.offset))
        }

        var ranges: [FreeRange] = []
        for (slot, size) in slotSizes.sorted(by: { $0.key.offset < $1.key.offset }) {
            guard slot.offset >= 0 else {
                return unfixable("one of its values sits before the page its instructions point at")
            }
            let start = freeStart + UInt64(slot.offset)
            let range = FreeRange(start: start, end: start + UInt64(size), owner: owner)
            if range.end > freeEnd {
                return unfixable(String(format: "its value at main+0x%llx does not fit in the free writable memory", Int64(slot.page) + slot.offset))
            }
            if ranges.contains(where: { $0.overlaps(range) }) {
                return unfixable("two of its values would share the same place in the free writable memory")
            }
            if let other = (occupied + alreadyFree).first(where: { $0.overlaps(range) }) {
                return unfixable("its values would share writable memory with \(other.owner == owner ? "values it already uses" : other.owner)")
            }
            ranges.append(range)
        }

        var rewritten = bytesByAddress
        var moved = 0
        for (adrp, page) in adrpPages where movedPages.contains(page) {
            guard let instruction = instructions[adrp] else { continue }
            rewritten[adrp] = encodeAdrp(register: instruction.word & 0x1f, at: adrp, target: freeStart)
            moved += 1
        }

        var dropped = 0
        for (slot, size) in slotSizes {
            let start = Int64(slot.page) + slot.offset
            for word in stride(from: start & ~3, to: start + Int64(size), by: 4) {
                guard let bytes = rewritten[UInt64(word)] else { continue }
                if bytes.contains(where: { $0 != 0 }) {
                    return unfixable(String(format: "it gives its value at main+0x%llx a starting value other than zero", word))
                }
                rewritten.removeValue(forKey: UInt64(word))
                dropped += 1
            }
        }

        let newEntries = rewritten.keys.sorted().map { address in
            PatchEntry(address: UInt32(address), data: rewritten[address]!)
        }
        let notes = [String(format: "Moved %d address calculations from game code to the free writable memory at main+0x%x, and dropped %d lines that set those values to zero inside game code.",
                            moved, layout.freeStart, dropped)]
        return result(.relocated(movedInstructions: moved, droppedInitializers: dropped), newEntries, notes, ranges + alreadyFree)
    }

    static func follow(from start: UInt64, register: String, page: UInt64, instructions: [UInt64: Instruction]) -> Trace {
        struct Visit: Hashable {
            let address: UInt64
            let tracked: [String: Int64]
        }
        var trace = Trace()
        var pending = [Visit(address: start + 4, tracked: [register: 0])]
        var seen: Set<Visit> = []
        while let visit = pending.popLast() {
            guard !visit.tracked.isEmpty, seen.insert(visit).inserted else { continue }
            guard seen.count <= traceLimit else {
                trace.complete = false
                break
            }
            guard let instruction = instructions[visit.address] else { continue }

            var tracked = visit.tracked
            var handled: Set<String> = []
            let memory = instruction.memoryOperand
            let pointerReads = instruction.registersRead.filter { $0 != memory?.base && tracked[$0] != nil }
            var passesPointerOn = !pointerReads.isEmpty && (instruction.writesGeneralRegister || instruction.writesMemory)
            if let memory, let base = tracked[memory.base] {
                trace.accesses.append(Access(adrp: start, page: page, offset: base + Int64(memory.displacement),
                                             size: instruction.accessSize, isWrite: instruction.writesMemory))
                if !memory.index.isEmpty || instruction.writeback {
                    trace.complete = false
                }
            } else if let add = instruction.addImmediate, let base = tracked[add.source] {
                tracked[add.destination] = base + add.value
                handled.insert(add.destination)
                passesPointerOn = false
            } else if let move = instruction.registerMove, let base = tracked[move.source] {
                tracked[move.destination] = base
                handled.insert(move.destination)
                passesPointerOn = false
            }
            if passesPointerOn {
                trace.complete = false
            }
            for written in instruction.registersWritten where !handled.contains(written) {
                tracked.removeValue(forKey: written)
            }

            switch instruction.flow {
            case .next:
                pending.append(Visit(address: visit.address + 4, tracked: tracked))
            case .jump(let target):
                pending.append(Visit(address: target, tracked: tracked))
            case .either(let target):
                pending.append(Visit(address: target, tracked: tracked))
                pending.append(Visit(address: visit.address + 4, tracked: tracked))
            case .call:
                if tracked.keys.contains(where: argumentRegisters.contains) {
                    trace.complete = false
                }
                pending.append(Visit(address: visit.address + 4, tracked: tracked.filter { calleeSavedRegisters.contains($0.key) }))
            case .leave:
                break
            }
        }
        return trace
    }

    public static func encodeAdrp(register: UInt32, at address: UInt64, target: UInt64) -> [UInt8] {
        let delta = Int64(target & ~0xfff) - Int64(address & ~0xfff)
        let immediate = UInt32(truncatingIfNeeded: delta >> 12) & 0x1fffff
        let word: UInt32 = 0x9000_0000 | ((immediate & 3) << 29) | ((immediate >> 2) << 5) | (register & 0x1f)
        return [UInt8(word & 0xff), UInt8((word >> 8) & 0xff), UInt8((word >> 16) & 0xff), UInt8(word >> 24)]
    }
}
