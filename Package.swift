// swift-tools-version: 5.10
import PackageDescription

let bare: Target =
  Context.environment["BARE_SIDECAR_LOCAL"] == nil
  ? .binaryTarget(
    name: "Bare",
    url:
      "https://github.com/holepunchto/bare-sidecar-swift/releases/download/v0.2.0/Bare.artifactbundle.zip",
    checksum: "9cff06ba1bc563e29d3d62b1a214c1cd067163d4e5e6d39dcd794f0dd3b9496a"
  )
  : .binaryTarget(name: "Bare", path: "Bare.artifactbundle")

let package = Package(
  name: "BareSidecar",
  platforms: [.macOS(.v13)],
  products: [
    .library(name: "BareSidecar", targets: ["BareSidecar"])
  ],
  targets: [
    bare,
    .plugin(name: "BareExecutable", capability: .buildTool(), dependencies: ["Bare"]),
    .target(name: "BareSidecar", plugins: ["BareExecutable"]),
    .testTarget(
      name: "BareSidecarTests",
      dependencies: ["BareSidecar"],
      exclude: ["Fixtures"]
    ),
  ]
)
