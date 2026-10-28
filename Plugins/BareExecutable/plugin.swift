import PackagePlugin

@main
struct BareExecutable: BuildToolPlugin {
  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    let bare = try context.tool(named: "bare")
    let output = context.pluginWorkDirectory.appending("bare")

    return [
      .buildCommand(
        displayName: "Bundle the Bare executable",
        executable: Path("/usr/bin/install"),
        arguments: ["-m", "755", bare.path, output],
        inputFiles: [bare.path],
        outputFiles: [output]
      )
    ]
  }
}
