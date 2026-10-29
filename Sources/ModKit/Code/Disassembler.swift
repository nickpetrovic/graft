import Foundation
internal import CCapstone

struct Instruction: Sendable {
    enum Operand: Sendable {
        case register(String)
        case immediate(Int64)
        case memory(base: String, index: String, displacement: Int32)
        case other
    }

    let address: UInt64
    let word: UInt32
    let id: UInt32
    let mnemonic: String
    let operandText: String
    let condition: UInt32
    let writeback: Bool
    let operands: [Operand]
    let registersRead: Set<String>
    let registersWritten: Set<String>

    var text: String { operandText.isEmpty ? mnemonic : "\(mnemonic) \(operandText)" }

    var isAdrp: Bool { id == ARM64_INS_ADRP.rawValue }

    enum Flow: Equatable {
        case next
        case jump(UInt64)
        case either(UInt64)
        case call
        case leave
    }

    var flow: Flow {
        let target = operands.reversed().lazy.compactMap { operand -> UInt64? in
            if case .immediate(let value) = operand { return UInt64(bitPattern: value) }
            return nil
        }.first
        switch arm64_insn(rawValue: id) {
        case ARM64_INS_B:
            guard let target else { return .leave }
            return condition == ARM64_CC_INVALID.rawValue || condition == ARM64_CC_AL.rawValue ? .jump(target) : .either(target)
        case ARM64_INS_CBZ, ARM64_INS_CBNZ, ARM64_INS_TBZ, ARM64_INS_TBNZ:
            return target.map(Flow.either) ?? .leave
        case ARM64_INS_BL, ARM64_INS_BLR:
            return .call
        case ARM64_INS_BR, ARM64_INS_RET:
            return .leave
        default:
            return .next
        }
    }

    var memoryOperand: (base: String, index: String, displacement: Int32)? {
        for case .memory(let base, let index, let displacement) in operands { return (base, index, displacement) }
        return nil
    }

    var registerMove: (destination: String, source: String)? {
        guard mnemonic == "mov", operands.count == 2,
              case .register(let destination) = operands[0], case .register(let source) = operands[1] else { return nil }
        return (destination, source)
    }

    var addImmediate: (destination: String, source: String, value: Int64)? {
        guard id == ARM64_INS_ADD.rawValue || id == ARM64_INS_SUB.rawValue, operands.count == 3,
              case .register(let destination) = operands[0], case .register(let source) = operands[1],
              case .immediate(let value) = operands[2] else { return nil }
        return (destination, source, id == ARM64_INS_SUB.rawValue ? -value : value)
    }

    var writesMemory: Bool {
        let atomics = ["swp", "cas", "ldadd", "ldclr", "ldeor", "ldset", "ldsmax", "ldsmin", "ldumax", "ldumin"]
        return mnemonic.hasPrefix("st") || atomics.contains { mnemonic.hasPrefix($0) }
    }

    var writesGeneralRegister: Bool {
        registersWritten.contains { $0 == "sp" || ($0.first == "x" && Int($0.dropFirst()) != nil) }
    }

    var accessSize: Int {
        let byteForms: Set<String> = ["ldrb", "strb", "ldrsb", "ldurb", "sturb", "ldursb", "ldarb", "stlrb", "ldaxrb", "stlxrb", "ldxrb", "stxrb"]
        let halfForms: Set<String> = ["ldrh", "strh", "ldrsh", "ldurh", "sturh", "ldursh", "ldarh", "stlrh", "ldaxrh", "stlxrh", "ldxrh", "stxrh"]
        if byteForms.contains(mnemonic) { return 1 }
        if halfForms.contains(mnemonic) { return 2 }
        if mnemonic == "ldrsw" || mnemonic == "ldursw" { return 4 }
        let first = operandText.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        let size: Int = switch first.first {
        case "x": 8
        case "w": 4
        case "q": 16
        case "d": 8
        case "s": 4
        case "h": 2
        case "b": 1
        default: 8
        }
        let pair = mnemonic.hasPrefix("ldp") || mnemonic.hasPrefix("stp") || mnemonic.hasPrefix("ldnp") || mnemonic.hasPrefix("stnp")
        return pair ? size * 2 : size
    }

    var unsupportedReason: String? {
        let calls: [arm64_insn] = [ARM64_INS_SVC, ARM64_INS_HVC, ARM64_INS_SMC]
        if calls.contains(where: { $0.rawValue == id }) { return "makes a system call (\(text))" }
        if id == ARM64_INS_MRS.rawValue || id == ARM64_INS_MSR.rawValue {
            let lowered = operandText.lowercased()
            for register in ["tpidrro_el0", "tpidr_el0", "cntvct_el0", "cntpct_el0", "cntfrq_el0"] where lowered.contains(register) {
                return "reads or writes \(register) (\(text))"
            }
        }
        if registersRead.contains("x18") || registersWritten.contains("x18") {
            return "uses register x18 (\(text))"
        }
        return nil
    }
}

final class Disassembler {
    private var handle: csh = 0

    init() throws {
        guard cs_open(CS_ARCH_ARM64, CS_MODE_ARM, &handle) == CS_ERR_OK else {
            throw GraftError("Graft couldn't start the Capstone disassembler.")
        }
        cs_option(handle, CS_OPT_DETAIL, Int(CS_OPT_ON.rawValue))
    }

    deinit {
        cs_close(&handle)
    }

    static func canonical(_ name: String) -> String {
        if name == "wzr" { return "xzr" }
        if name == "wsp" { return "sp" }
        if name.first == "w", let number = Int(name.dropFirst()), (0...30).contains(number) { return "x\(number)" }
        return name
    }

    private func name(of register: UInt32) -> String {
        guard register != 0, let raw = cs_reg_name(handle, register) else { return "" }
        return Self.canonical(String(cString: raw))
    }

    func decode(_ bytes: [UInt8], at address: UInt64) -> Instruction? {
        guard bytes.count == 4 else { return nil }
        var pointer: UnsafeMutablePointer<cs_insn>?
        let count = bytes.withUnsafeBufferPointer { buffer in
            cs_disasm(handle, buffer.baseAddress, buffer.count, address, 1, &pointer)
        }
        guard count == 1, let insn = pointer else { return nil }
        defer { cs_free(insn, count) }

        let mnemonic = withUnsafePointer(to: insn.pointee.mnemonic) {
            $0.withMemoryRebound(to: CChar.self, capacity: 32) { String(cString: $0) }
        }
        let operandText = withUnsafePointer(to: insn.pointee.op_str) {
            $0.withMemoryRebound(to: CChar.self, capacity: 160) { String(cString: $0) }
        }

        var operands: [Instruction.Operand] = []
        var condition: UInt32 = 0
        var writeback = false
        if let detail = insn.pointee.detail {
            let arm64 = detail.pointee.arm64
            condition = arm64.cc.rawValue
            writeback = arm64.writeback
            let total = Int(arm64.op_count)
            withUnsafePointer(to: arm64.operands) { tuple in
                tuple.withMemoryRebound(to: cs_arm64_op.self, capacity: 8) { list in
                    for index in 0..<min(total, 8) {
                        let operand = list[index]
                        switch operand.type {
                        case ARM64_OP_REG:
                            operands.append(.register(name(of: operand.reg.rawValue)))
                        case ARM64_OP_IMM:
                            let shift = operand.shift.type == ARM64_SFT_LSL ? Int64(operand.shift.value) : 0
                            operands.append(.immediate(operand.imm << shift))
                        case ARM64_OP_MEM:
                            operands.append(.memory(base: name(of: operand.mem.base.rawValue), index: name(of: operand.mem.index.rawValue),
                                                    displacement: operand.mem.disp))
                        default:
                            operands.append(.other)
                        }
                    }
                }
            }
        }

        var readBuffer = [UInt16](repeating: 0, count: 64)
        var writeBuffer = [UInt16](repeating: 0, count: 64)
        var readCount: UInt8 = 0
        var writeCount: UInt8 = 0
        let accessResult = readBuffer.withUnsafeMutableBufferPointer { reads in
            writeBuffer.withUnsafeMutableBufferPointer { writes in
                cs_regs_access(handle, insn, reads.baseAddress, &readCount, writes.baseAddress, &writeCount)
            }
        }
        let registersRead = accessResult == CS_ERR_OK ? Set(readBuffer.prefix(Int(readCount)).map { name(of: UInt32($0)) }) : []
        let registersWritten = accessResult == CS_ERR_OK ? Set(writeBuffer.prefix(Int(writeCount)).map { name(of: UInt32($0)) }) : []

        let word = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
        return Instruction(address: address, word: word, id: insn.pointee.id, mnemonic: mnemonic, operandText: operandText,
                           condition: condition, writeback: writeback, operands: operands,
                           registersRead: registersRead, registersWritten: registersWritten)
    }
}
