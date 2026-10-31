// swift-tools-version: 5.10
import PackageDescription

let bare: Target =
  Context.environment["BARE_SIDECAR_LOCAL"] == nil
  ? .binaryTarget(
    name: "Bare",
    url:
      "https://github.com/holepunchto/bare-sidecar-swift/releases/download/v0.1.1/Bare.artifactbundle.zip",
    checksum: "428011bd0060423ee024c732c14ba3e0c4f3e74bc4ad952e719f24514f29d656"
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
