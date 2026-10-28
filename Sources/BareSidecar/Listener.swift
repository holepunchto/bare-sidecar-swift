import Foundation

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

// A Unix socket in a directory only the current user can access, accepting the
// single IPC connection of a sidecar.
final class Listener: @unchecked Sendable {
  let path: String

  private let directory: String
  private let fd: Int32
  private let lock = NSLock()
  private var closed = false

  init() throws {
    var template = Array((NSTemporaryDirectory() + "bare-sidecar-XXXXXX").utf8CString)

    guard let directory = mkdtemp(&template) else { throw POSIXError.current }

    self.directory = String(cString: directory)
    self.path = self.directory + "/ipc"

    fd = socket(AF_UNIX, socketStream, 0)

    guard fd != -1 else { throw POSIXError.current }

    do {
      try bindUnix(fd, path)

      guard listen(fd, 1) == 0 else { throw POSIXError.current }
    } catch {
      close()
      throw error
    }
  }

  // Blocks a thread of its own, as the connection only arrives once the
  // process has started.
  func accept() async throws -> Int32 {
    try await withCheckedThrowingContinuation { continuation in
      Thread {
        let connection = systemAccept(self.fd, nil, nil)

        if connection == -1 {
          continuation.resume(throwing: POSIXError.current)
        } else {
          continuation.resume(returning: connection)
        }
      }.start()
    }
  }

  // Closed both once connected and once the process exits, by when the
  // descriptor may already have been reused.
  func close() {
    lock.lock()
    defer { lock.unlock() }

    if closed { return }

    closed = true

    _ = shutdown(fd, Int32(SHUT_RDWR))
    _ = systemClose(fd)
    _ = unlink(path)
    _ = rmdir(directory)
  }
}

private func bindUnix(_ fd: Int32, _ path: String) throws {
  var address = sockaddr_un()
  address.sun_family = sa_family_t(AF_UNIX)

  let bytes = Array(path.utf8)

  guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else {
    throw POSIXError(.ENAMETOOLONG)
  }

  withUnsafeMutableBytes(of: &address.sun_path) { buffer in
    buffer.copyBytes(from: bytes)
    buffer[bytes.count] = 0
  }

  let result = withUnsafePointer(to: &address) { pointer in
    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
      bind(fd, address, socklen_t(MemoryLayout<sockaddr_un>.size))
    }
  }

  guard result == 0 else { throw POSIXError.current }
}
