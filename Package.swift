// swift-tools-version: 5.10
import PackageDescription

let bare: Target =
  Context.environment["BARE_SIDECAR_LOCAL"] == nil
  ? .binaryTarget(
    name: "Bare",
    url:
      "https://github.com/holepunchto/bare-sidecar-swift/releases/download/v0.1.3/Bare.artifactbundle.zip",
    checksum: "2669df903470fd9a06344aa674ab41117143f599a7225bbefdf9e47bb30b8f9d"
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
