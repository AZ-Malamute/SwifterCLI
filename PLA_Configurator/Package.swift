// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PLA_Configurator",
    platforms: [.macOS(.v15)],
    targets: [.executableTarget(name: "PLA_Configurator")]
)