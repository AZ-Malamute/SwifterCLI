import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
struct SwifterRecommenderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct Recommendation: Identifiable {
    let id = UUID()
    let fields: [String]
}

struct ContentView: View {
    @State private var rows: [Recommendation] = []
    @State private var status = "Choose or drop your NetflixViewingHistory.csv"
    @State private var search = ""

    var filteredRows: [Recommendation] {
        if search.isEmpty { return rows }
        return rows.filter {
            $0.fields.joined(separator: " ").localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("NETFLIX")
                        .font(.system(size: 44, weight: .black, design: .default))
                        .foregroundStyle(.red)

                    VStack(alignment: .leading) {
                        Text("Recommender Proof")
                            .font(.title2)
                            .bold()
                            .foregroundStyle(.white)
                        Text("CSV → local analysis → recommendation surface")
                            .foregroundStyle(.gray)
                    }

                    Spacer()

                    Button("Choose CSV") {
                        chooseCSV()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Text(status)
                    .foregroundStyle(.gray)

                TextField("Search viewing history / recommendations", text: $search)
                    .textFieldStyle(.roundedBorder)

                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 2, dash: [10]))
                    .frame(height: 130)
                    .overlay(
                        VStack(spacing: 8) {
                            Text("Drop NetflixViewingHistory.csv here")
                                .font(.title2)
                                .foregroundStyle(.white)
                            Text("or click Choose CSV")
                                .foregroundStyle(.gray)
                        }
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

                HStack {
                    metricCard("Rows Loaded", "\(rows.count)")
                    metricCard("Filtered", "\(filteredRows.count)")
                    metricCard("Proof Mode", "Local")
                }

                Text("Viewing History / Recommendation Inputs")
                    .font(.headline)
                    .foregroundStyle(.white)

                List(filteredRows) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(row.fields.first ?? "Netflix Title")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(row.fields.dropFirst().joined(separator: " • "))
                            .foregroundStyle(.gray)
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color(red: 0.08, green: 0.08, blue: 0.08))
                }
                .scrollContentBackground(.hidden)
            }
            .padding(28)
            .frame(width: 1200, height: 820)
        }
    }

    func metricCard(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .foregroundStyle(.gray)
            Text(value)
                .font(.title)
                .bold()
                .foregroundStyle(.white)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.10, green: 0.10, blue: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    func chooseCSV() {
        let panel = NSOpenPanel()
        panel.title = "Choose NetflixViewingHistory.csv"
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            loadCSV(url)
        }
    }

    func loadCSV(_ url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            status = "Could not read \(url.lastPathComponent)"
            return
        }

        let parsed = text
            .split(separator: "\n")
            .dropFirst()
            .map { line in
                Recommendation(
                    fields: line.split(separator: ",").map {
                        String($0).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                )
            }

        rows = parsed
        status = "Loaded \(parsed.count) rows from \(url.lastPathComponent)"
    }
}
