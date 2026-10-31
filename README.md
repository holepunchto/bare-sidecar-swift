# bare-sidecar-swift

Start and manage Bare sidecar processes from Swift. The Swift counterpart of [bare-sidecar](https://github.com/holepunchto/bare-sidecar): it runs a Bare entry point in a child process with an IPC connection to it, exposed as `Bare.IPC` inside the process.

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

## License

Apache-2.0
