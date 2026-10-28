// swift-tools-version: 5.10
import PackageDescription

let bare: Target =
  Context.environment["BARE_SIDECAR_LOCAL"] == nil
  ? .binaryTarget(
    name: "Bare",
    url:
      "https://github.com/holepunchto/bare-sidecar-swift/releases/download/v0.1.0/Bare.artifactbundle.zip",
    checksum: "0000000000000000000000000000000000000000000000000000000000000000"
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
