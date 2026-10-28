import Foundation

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

/// A Bare process connected to its `Bare.IPC`.
///
/// Iterating a sidecar yields the data the process writes to `Bare.IPC` until
/// the connection ends. Use ``spawn(_:arguments:stdio:bare:)`` to start one.
public final class Sidecar: AsyncSequence, @unchecked Sendable {
  public typealias Element = Data

  /// How a standard stream of the process is connected.
  public enum Stdio: Sendable {
    /// The stream of the current process.
    case inherit
    /// A pipe, exposed as ``Sidecar/standardInput``, ``Sidecar/standardOutput``,
    /// or ``Sidecar/standardError``.
    case pipe
    /// The null device.
    case ignore
  }

  /// How the process exited.
  public enum Termination: Equatable, Sendable {
    /// The process exited with the code.
    case exit(Int32)
    /// The process was killed by the signal.
    case signal(Int32)
  }

  /// The process identifier.
  public var pid: Int32 { process.processIdentifier }

  /// The write end of the standard input of the process when spawned with
  /// ``Stdio/pipe``.
  public let standardInput: FileHandle?
  /// The read end of the standard output of the process when spawned with
  /// ``Stdio/pipe``.
  public let standardOutput: FileHandle?
  /// The read end of the standard error of the process when spawned with
  /// ``Stdio/pipe``.
  public let standardError: FileHandle?

  private let process: Process
  private let connection: Connection
  private let termination: Task<Termination, Never>

  private init(
    process: Process,
    connection: Connection,
    termination: Task<Termination, Never>,
    stdio: (FileHandle?, FileHandle?, FileHandle?)
  ) {
    self.process = process
    self.connection = connection
    self.termination = termination
    (standardInput, standardOutput, standardError) = stdio
  }

  /// The Bare executable shipped for the running platform.
  public static var executable: URL? {
    Bundle.module.url(forResource: "bare", withExtension: nil)
  }

  /// Starts `entry` in a Bare process with an IPC connection to it.
  ///
  /// - Parameters:
  ///   - entry: The Bare entry point to run.
  ///   - arguments: The arguments passed to it as `Bare.argv`.
  ///   - stdio: How the standard input, output, and error of the process are
  ///     connected, in that order.
  ///   - bare: The Bare executable to use, defaulting to the one shipped with
  ///     this package.
  /// - Throws: ``SidecarError/exitedBeforeConnecting(_:)`` if the process exits
  ///   before connecting to its IPC.
  public static func spawn(
    _ entry: URL,
    arguments: [String] = [],
    stdio: (Stdio, Stdio, Stdio) = (.inherit, .inherit, .inherit),
    bare: URL? = nil
  ) async throws -> Sidecar {
    guard let bare = bare ?? executable else { throw SidecarError.noExecutable }

    let listener = try Listener()

    let process = Process()
    process.executableURL = bare
    process.arguments = [entry.path] + arguments

    var environment = ProcessInfo.processInfo.environment
    environment["BARE_SIDECAR_IPC"] = listener.path
    process.environment = environment

    let standardInput = connect(stdio.0)
    let standardOutput = connect(stdio.1)
    let standardError = connect(stdio.2)

    process.standardInput = standardInput
    process.standardOutput = standardOutput
    process.standardError = standardError

    let (exits, exited) = AsyncStream<Termination>.makeStream()

    // A process that exits before connecting would leave the listener waiting
    // forever, so its exit closes the listener too.
    process.terminationHandler = { process in
      listener.close()

      switch process.terminationReason {
      case .uncaughtSignal:
        exited.yield(.signal(process.terminationStatus))
      default:
        exited.yield(.exit(process.terminationStatus))
      }

      exited.finish()
    }

    do {
      try process.run()
    } catch {
      listener.close()
      throw error
    }

    let termination = Task { await exits.first { _ in true }! }

    let fd: Int32

    do {
      fd = try await listener.accept()
    } catch {
      throw SidecarError.exitedBeforeConnecting(await termination.value)
    }

    listener.close()

    return Sidecar(
      process: process,
      connection: Connection(fd),
      termination: termination,
      stdio: (
        (standardInput as? Pipe)?.fileHandleForWriting,
        (standardOutput as? Pipe)?.fileHandleForReading,
        (standardError as? Pipe)?.fileHandleForReading
      )
    )
  }

  public func makeAsyncIterator() -> AsyncThrowingStream<Data, Error>.AsyncIterator {
    connection.data.makeAsyncIterator()
  }

  /// Writes `data` to `Bare.IPC` of the process.
  ///
  /// Data written once the process has closed its end of the connection, such
  /// as while it is exiting, is dropped, as its exit already accounts for it.
  public func write(_ data: Data) async {
    await connection.write(data)
  }

  /// Asks the process to exit with `SIGTERM`, unless it has already exited.
  public func terminate() {
    sendSignal(SIGTERM)
  }

  /// Kills the process with `SIGKILL`, unless it has already exited.
  public func kill() {
    sendSignal(SIGKILL)
  }

  /// Sends `signal` to the process, unless it has already exited.
  public func sendSignal(_ signal: Int32) {
    if process.isRunning { _ = systemKill(process.processIdentifier, signal) }
  }

  /// Waits for the process to exit.
  ///
  /// - Returns: How the process exited.
  @discardableResult
  public func wait() async -> Termination {
    await termination.value
  }

  /// Closes the connection, terminating the process if it is still running,
  /// and waits for it to exit.
  ///
  /// - Returns: How the process exited.
  @discardableResult
  public func close() async -> Termination {
    connection.close()
    terminate()

    return await wait()
  }
}

/// An error spawning a sidecar.
public enum SidecarError: Error, Equatable {
  /// No Bare executable is shipped for the running platform.
  case noExecutable
  /// The process exited before connecting to its IPC.
  case exitedBeforeConnecting(Sidecar.Termination)
}

private func connect(_ stdio: Sidecar.Stdio) -> Any? {
  switch stdio {
  case .inherit:
    return nil
  case .pipe:
    return Pipe()
  case .ignore:
    return FileHandle.nullDevice
  }
}
