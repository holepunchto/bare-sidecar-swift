# bare-sidecar-swift

Start and manage Bare sidecar processes from Swift. The Swift counterpart of [bare-sidecar](https://github.com/holepunchto/bare-sidecar): it runs a Bare entry point in a child process with an IPC connection to it, exposed as `Bare.IPC` inside the process. The Bare executable is shipped as a binary target of the package.

```swift
dependencies: [
  .package(url: "https://github.com/holepunchto/bare-sidecar-swift", from: "<tag>")
]

.product(name: "BareSidecar", package: "bare-sidecar-swift")
```

## Usage

```swift
import BareSidecar
import Foundation

let sidecar = try await Sidecar.spawn(URL(fileURLWithPath: "app.js"))

await sidecar.write(Data("Hello world".utf8))

for try await data in sidecar {
  print(String(decoding: data, as: UTF8.self))
}

await sidecar.close()
```

Where `app.js` is a Bare entry point using `Bare.IPC`:

```js
Bare.IPC.on("data", (data) => Bare.IPC.write(data));
```

## Release

1. Run the Prebuild workflow with the tag of the release, such as `v0.1.0`. It compiles the executable for every platform and creates a draft release with the artifact bundle, whose SHA-256 digest the release lists.
2. Update the URL and checksum of the `bare` binary target in `Package.swift` as part of the release.
3. Push the tag. The Publish workflow checks that `Package.swift` declares the checksum of the artifact bundle of the draft release and publishes it.

## License

Apache-2.0
