import BareSidecar
import Foundation
import XCTest

let fixtures = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent()
  .appendingPathComponent("Fixtures")

func fixture(_ name: String) -> URL {
  fixtures.appendingPathComponent(name)
}

final class SidecarTests: XCTestCase {
  func testEchoesIPCData() async throws {
    let sidecar = try await Sidecar.spawn(fixture("echo.js"))

    await sidecar.write(Data("Hello world".utf8))

    var iterator = sidecar.makeAsyncIterator()

    let data = try await iterator.next()

    XCTAssertEqual(data, Data("Hello world".utf8))

    await sidecar.close()
  }

  func testPassesArguments() async throws {
    let sidecar = try await Sidecar.spawn(fixture("argv.js"), arguments: ["foo", "bar"])

    var received = Data()

    for try await data in sidecar {
      received.append(data)
    }

    XCTAssertEqual(String(decoding: received, as: UTF8.self), #"["foo","bar"]"#)
    let termination = await sidecar.wait()
    XCTAssertEqual(termination, .exit(0))
  }

  func testReportsTheExitCode() async throws {
    let sidecar = try await Sidecar.spawn(fixture("exit.js"))

    let termination = await sidecar.wait()
    XCTAssertEqual(termination, .exit(3))
  }

  func testExitsAfterIPCDestroyWhileWriting() async throws {
    let sidecar = try await Sidecar.spawn(fixture("ipc-destroy-exit.js"))

    let writing = Task {
      while !Task.isCancelled {
        await sidecar.write(Data("Hello world".utf8))
        try? await Task.sleep(nanoseconds: 10_000_000)
      }
    }

    let termination = await sidecar.wait()
    XCTAssertEqual(termination, .exit(3))

    writing.cancel()
  }

  func testPipesStandardOutput() async throws {
    let sidecar = try await Sidecar.spawn(fixture("log.js"), stdio: (.inherit, .pipe, .inherit))

    let output = try XCTUnwrap(sidecar.standardOutput).readDataToEndOfFile()

    XCTAssertEqual(String(decoding: output, as: UTF8.self), "Hello world\n")

    await sidecar.wait()
  }

  func testTerminateAndKillEndTheProcess() async throws {
    let terminated = try await Sidecar.spawn(fixture("sleep.js"))
    terminated.terminate()
    let termination = await terminated.wait()
    XCTAssertEqual(termination, .signal(SIGTERM))

    let killed = try await Sidecar.spawn(fixture("sleep.js"))
    killed.kill()
    let killing = await killed.wait()
    XCTAssertEqual(killing, .signal(SIGKILL))
  }

  func testCloseWaitsForTheProcessToExit() async throws {
    let sidecar = try await Sidecar.spawn(fixture("sleep.js"))

    let termination = await sidecar.close()

    XCTAssertNotEqual(termination, .exit(-1))
  }

  func testSpawnsSidecarsOneAfterAnother() async throws {
    for _ in 0..<5 {
      let sidecar = try await Sidecar.spawn(fixture("echo.js"))

      await sidecar.write(Data("Hello world".utf8))

      var iterator = sidecar.makeAsyncIterator()

      let data = try await iterator.next()

      XCTAssertEqual(data, Data("Hello world".utf8))

      sidecar.terminate()
    }
  }

  func testFailsWhenTheProcessExitsBeforeConnecting() async throws {
    do {
      _ = try await Sidecar.spawn(fixture("exit.js"), bare: URL(fileURLWithPath: "/usr/bin/true"))
      XCTFail("spawn succeeded")
    } catch SidecarError.exitedBeforeConnecting(let termination) {
      XCTAssertEqual(termination, .exit(0))
    }
  }

}
