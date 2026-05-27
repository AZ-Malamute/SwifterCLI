// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SA_Inspector",
    platforms: [.macOS(.v15)],
    targets: [.executableTarget(name: "SA_Inspector")]
)