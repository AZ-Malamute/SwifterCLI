import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Charts

@main
struct PLAConfiguratorApp: App {
    var body: some Scene {
        WindowGroup {
            PLAView()
        }
    }
}

struct SamplePoint: Identifiable {
    let id = UUID()
    let index: Int
    let value: Double
}

struct PLAView: View {
    @State private var status = "Drop a CSV file on the chart area"
    @State private var samples: [SamplePoint] = []
    @State private var fileName = "No CSV loaded"

    var body: some View {
        HStack(spacing: 10) {
            controlPanel
                .frame(width: 390)

            chartPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(10)
        .frame(width: 1200, height: 720)
        .background(Color(red: 0.12, green: 0.13, blue: 0.12))
    }

    var controlPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            redBadge("NOT CONNECTED")
            redBadge("Barometer")
            redBadge("LIDAR")

            Text("0.00V")
                .bold()
                .frame(width: 145, height: 36)
                .background(Color.red)
                .foregroundStyle(.black)

            Divider()

            Text("Time")
                .font(.title2).bold()
                .foregroundStyle(.white)

            Button("Set Mac Time") {}
            Button("Set Manual Time") {}

            Divider()

            Text("Configuration")
                .font(.title2).bold()
                .foregroundStyle(.white)

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                configRow("DZ Elevation", unit: "ft")
                configRow("Pressure", unit: "inHg")
                configRow("Temperature", unit: "F")
                configRow("Downwind", unit: "ft")
                configRow("Crosswind", unit: "ft")
                configRow("Final", unit: "ft")
            }

            Button("Choose CSV") {
                chooseCSV()
            }

            Text(fileName)
                .font(.caption)
                .foregroundStyle(.gray)

            Text(status)
                .font(.caption)
                .foregroundStyle(.gray)

            Spacer()
        }
        .padding()
        .background(Color(red: 0.15, green: 0.17, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var chartPanel: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.white)
            .overlay(
                VStack(alignment: .leading) {
                    Text("PLA Telemetry Chart")
                        .font(.title)
                        .bold()
                        .foregroundStyle(.black)

                    if samples.isEmpty {
                        Spacer()
                        Text("Drop CSV here to plot first numeric telemetry column")
                            .font(.title2)
                            .foregroundStyle(.gray)
                            .frame(maxWidth: .infinity)
                        Spacer()
                    } else {
                        Chart(samples) { point in
                            LineMark(
                                x: .value("Sample", point.index),
                                y: .value("Value", point.value)
                            )
                        }
                        .chartXAxisLabel("Sample")
                        .chartYAxisLabel("Value")
                        .padding()
                    }
                }
                .padding()
            )
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                guard let provider = providers.first else { return false }

                provider.loadDataRepresentation(forTypeIdentifier: "public.file-url") { data, _ in
                    guard
                        let data,
                        let url = URL(dataRepresentation: data, relativeTo: nil)
                    else { return }

                    Task { @MainActor in
                        loadCSV(url)
                    }
                }

                return true
            }
    }

    func chooseCSV() {
        let panel = NSOpenPanel()
        panel.title = "Choose PLA CSV Log"
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            loadCSV(url)
        }
    }

    func loadCSV(_ url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            status = "Could not read CSV"
            return
        }

        let lines = text.split(separator: "\n").map(String.init)
        var parsed: [SamplePoint] = []

        for (i, line) in lines.dropFirst().enumerated() {
            let cells = line.split(separator: ",").map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if let value = cells.compactMap({ Double($0.replacingOccurrences(of: "\"", with: "")) }).first {
                parsed.append(SamplePoint(index: i, value: value))
            }
        }

        samples = parsed
        fileName = url.lastPathComponent
        status = "Loaded \(parsed.count) numeric samples"
    }

    func redBadge(_ text: String) -> some View {
        Text(text)
            .bold()
            .frame(width: 145, height: 24)
            .background(Color.red)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    func configRow(_ label: String, unit: String) -> some View {
        GridRow {
            Text(label)
                .bold()
                .foregroundStyle(.white)
                .frame(width: 140, alignment: .trailing)

            TextField("", text: .constant(""))
                .frame(width: 110)

            Text(unit)
                .bold()
                .foregroundStyle(.white)
        }
    }
}
