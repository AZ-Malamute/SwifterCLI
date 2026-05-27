import SwiftUI

@main
struct SA_InspectorApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 16) {
                Text("SA Inspector")
                    .font(.largeTitle)
                        Button("Start Inspection") {
            print("Start Inspection")
        }
        Button("Generate Report") {
            print("Generate Report")
        }
            }
            .padding()
            .frame(width: 1200, height: 800)
        }
    }
}