import Foundation

#if canImport(Darwin)
  import Darwin

  let socketStream = SOCK_STREAM
  let sendFlags: Int32 = 0
#elseif canImport(Glibc)
  import Glibc

  let socketStream = Int32(SOCK_STREAM.rawValue)
  let sendFlags = Int32(MSG_NOSIGNAL)
#endif

// The system calls whose names clash with methods of the types using them.
let systemAccept = accept
let systemClose = close
let systemKill = kill

extension POSIXError {
  static var current: POSIXError {
    POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
  }
}
