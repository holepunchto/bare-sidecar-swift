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

  init(_ fd: Int32) {
    self.fd = fd

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
      let read = buffer.withUnsafeMutableBytes { recv(fd, $0.baseAddress, $0.count, 0) }

      if read > 0 {
        continuation.yield(Data(buffer[0..<read]))
      } else if read == -1 && errno == EINTR {
        continue
      } else {
        // The process exits once the connection has closed, which takes both
        // ends to have ended. On Linux, a process that exits with data still
        // unread resets the connection rather than ending it.
        if read == 0 || errno == ECONNRESET {
          _ = shutdown(fd, Int32(SHUT_WR))
          continuation.finish()
        } else {
          continuation.finish(throwing: POSIXError.current)
        }

        return
      }
    }
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
