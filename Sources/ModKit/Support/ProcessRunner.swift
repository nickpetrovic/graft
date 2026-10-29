import Foundation

public struct ProcessResult: Sendable {
    public let status: Int32
    public let output: Data
    public let errorText: String

    public var outputText: String { String(decoding: output, as: UTF8.self) }

    public func lastLines(_ count: Int) -> String {
        (errorText.split(whereSeparator: \.isNewline) + outputText.split(whereSeparator: \.isNewline))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .suffix(count)
            .joined(separator: " ")
    }
}

public enum ProcessRunner {
    public enum LineSource: Sendable {
        case standardError
        case standardOutput
    }

    public static func run(_ executable: URL, arguments: [String], workingDirectory: URL? = nil,
                           lineSource: LineSource = .standardError, children: ChildProcesses = .shared,
                           onLine: @escaping @Sendable (String) -> Void = { _ in }) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        if let workingDirectory { process.currentDirectoryURL = workingDirectory }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.standardInput = FileHandle.nullDevice

        let (exit, exitContinuation) = AsyncStream.makeStream(of: Int32.self)
        process.terminationHandler = { finished in
            children.finished(finished)
            exitContinuation.yield(finished.terminationStatus)
            exitContinuation.finish()
        }
        try process.run()
        children.started(process)
        if !process.isRunning { children.finished(process) }

        return try await withTaskCancellationHandler {
            async let output = read(outputPipe.fileHandleForReading, onLine: lineSource == .standardOutput ? onLine : nil)
            async let errors = read(errorPipe.fileHandleForReading, onLine: lineSource == .standardError ? onLine : nil)
            let (outputData, errorData) = try await (output, errors)
            var status: Int32 = -1
            for await value in exit { status = value }
            return ProcessResult(status: status, output: outputData, errorText: String(decoding: errorData, as: UTF8.self))
        } onCancel: {
            process.terminate()
        }
    }

    private static func read(_ handle: FileHandle, onLine: (@Sendable (String) -> Void)?) async throws -> Data {
        var data = Data()
        var line = Data()
        for try await byte in handle.bytes {
            data.append(byte)
            guard let onLine else { continue }
            if byte == UInt8(ascii: "\n") {
                onLine(String(decoding: line, as: UTF8.self))
                line.removeAll(keepingCapacity: true)
            } else {
                line.append(byte)
            }
        }
        if let onLine, !line.isEmpty {
            onLine(String(decoding: line, as: UTF8.self))
        }
        return data
    }
}
