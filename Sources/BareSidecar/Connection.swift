import Foundation

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

final class Connection: @unchecked Sendable {
  let data: AsyncThrowingStream<Data, Error>

  private let fd: Int32
  private let writes = DispatchQueue(label: "to.holepunch.bare-sidecar.write")
  private let continuation: AsyncThrowingStream<Data, Error>.Continuation
  private let exited: @Sendable () async -> Void

  init(_ fd: Int32, exited: @escaping @Sendable () async -> Void) {
    self.fd = fd
    self.exited = exited

    (data, continuation) = AsyncThrowingStream.makeStream()

    #if canImport(Darwin)
      var on: Int32 = 1
      _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
    #endif

    Thread { self.read() }.start()
  }

  deinit {
    _ = systemClose(fd)
  }

  func write(_ data: Data) async {
    await withCheckedContinuation { continuation in
      writes.async {
        self.sendAll(data)
        continuation.resume()
      }
    }
  }

  func close() {
    _ = shutdown(fd, Int32(SHUT_RDWR))
  }

  private func read() {
    var buffer = [UInt8](repeating: 0, count: 65536)

    while true {
      let read = buffer.withUnsafeMutableBytes {
        waitReadable() ? recv(fd, $0.baseAddress, $0.count, 0) : -1
      }

      if read > 0 {
        continuation.yield(Data(buffer[0..<read]))
      } else if read == -1 && errno == EINTR {
        continue
      } else {
        // The process exits once the connection has closed, which takes both
        // ends to have ended. On Linux, a process that exits with data still
        // unread resets the connection rather than ending it.
        let error: Error? = read == 0 || errno == ECONNRESET ? nil : POSIXError.current

        _ = shutdown(fd, Int32(SHUT_WR))

        // The data ends only once the process has exited, so that readers
        // reaching the end don't leave it unreaped.
        Task {
          await exited()
          continuation.finish(throwing: error)
        }

        return
      }
    }
  }

  // A blocking `recv()` on macOS may miss the end of the connection, which `poll()` does not.
  private func waitReadable() -> Bool {
    var readable = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)

    while poll(&readable, 1, -1) == -1 {
      if errno != EINTR { return false }
    }

    return true
  }

  // Data written once the process has closed its end, such as while exiting,
  // is dropped, as its exit already accounts for it.
  private func sendAll(_ data: Data) {
    data.withUnsafeBytes { buffer in
      var offset = 0

      while offset < buffer.count {
        let sent = send(fd, buffer.baseAddress! + offset, buffer.count - offset, sendFlags)

        if sent > 0 {
          offset += sent
        } else if errno != EINTR {
          return
        }
      }
    }
  }
}
