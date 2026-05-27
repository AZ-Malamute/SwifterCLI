import Foundation

@main
struct SwifterCLI {
    static func quoted(_ line: String) -> String {
        line.split(separator: "\"").dropFirst().first.map(String.init) ?? ""
    }

    static func write(_ path: String, _ text: String) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    static func main() throws {
        let path = CommandLine.arguments.dropFirst().first ?? "examples/sa_inspector.swifter"
        let text = try String(contentsOfFile: path, encoding: .utf8)
        let lines = text.split(separator: "\n").map(String.init)

        var appName = "Untitled"
        var width = "800"
        var height = "600"
        var buttons: [String] = []

        for line in lines {
            if line.hasPrefix("app ") {
                appName = quoted(line)
            } else if line.hasPrefix("window ") {
                let parts = line.split(separator: " ")
                if parts.count >= 3 {
                    width = String(parts[1])
                    height = String(parts[2])
                }
            } else if line.hasPrefix("button ") {
                buttons.append(quoted(line))
            }
        }

        let safe = appName.replacingOccurrences(of: " ", with: "_")
        let buttonCode = buttons.map {
            """
                    Button("\($0)") {
                        print("\($0)")
                    }
            """
        }.joined(separator: "\n")

        try write("\(safe)/Package.swift", """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "\(safe)",
            platforms: [.macOS(.v15)],
            targets: [.executableTarget(name: "\(safe)")]
        )
        """)

        try write("\(safe)/Sources/\(safe)/main.swift", """
        import SwiftUI

        @main
        struct \(safe)App: App {
            var body: some Scene {
                WindowGroup {
                    VStack(spacing: 16) {
                        Text("\(appName)")
                            .font(.largeTitle)
                        \(buttonCode)
                    }
                    .padding()
                    .frame(width: \(width), height: \(height))
                }
            }
        }
        """)

        print("✅ Generated SwiftUI app: \(safe)")
        print("Run:")
        print("cd \(safe) && /usr/bin/xcrun swift run")
    }
}
