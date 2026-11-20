import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// An advisory lock shared by the app and extension. Atomic file replacement alone cannot protect a
/// read, change, write transaction. A process crash closes its descriptor and releases this lock.
enum SharedFileLock {
    static func withLock<Value>(in folder: URL, _ body: () throws -> Value) throws -> Value {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(".transcripts.lock")
        let descriptor = open(url.path, O_CREAT | O_RDWR, mode_t(0o600))
        guard descriptor >= 0 else { throw failure() }
        defer { close(descriptor) }
        while flock(descriptor, LOCK_EX) != 0 {
            guard errno == EINTR else { throw failure() }
        }
        defer { flock(descriptor, LOCK_UN) }
        return try body()
    }

    private static func failure() -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
}
