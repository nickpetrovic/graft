import Foundation

public enum FileLock {
    public static func holding<T>(_ url: URL, timeout: Duration = .seconds(30),
                                  isolation: isolated (any Actor)? = #isolation,
                                  _ body: () async throws -> T) async throws -> T {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let descriptor = open(url.path, O_RDWR | O_CREAT | O_CLOEXEC, 0o644)
        guard descriptor >= 0 else {
            throw GraftError("Couldn't open \(url.path): \(String(cString: strerror(errno)))")
        }
        defer { close(descriptor) }
        let deadline = ContinuousClock.now + timeout
        while flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
            guard errno == EWOULDBLOCK, ContinuousClock.now < deadline else {
                throw GraftError("Another Graft task is still changing this game's mods. Try again when it finishes.")
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        defer { flock(descriptor, LOCK_UN) }
        return try await body()
    }
}
