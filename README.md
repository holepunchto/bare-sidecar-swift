# bare-sidecar-swift

Start and manage Bare sidecar processes from Swift, each running Bare alongside the application with an IPC to it exposed as `Bare.IPC` inside the process.

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

## Versions

`Sidecar.versions` lists the versions of the components bundled with the package, such as `bare` for the Bare executable:

```swift
print(Sidecar.versions["bare"]!)
```

They come from `versions.json` at the root of the package, which is also where the build reads the version of Bare to bundle.

## License

Apache-2.0
