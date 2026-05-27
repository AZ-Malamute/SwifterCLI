import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
struct SwifterRecommenderApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct CatalogPayload: Codable {
    let count: Int
    let titles: [CatalogTitle]
}

struct CatalogTitle: Codable, Identifiable {
    var id: String { "\(title)-\(year ?? 0)" }
    let title: String
    let year: Int?
    let description: String?
    let poster_url: String?
    let source: String?
    let source_file: String?
}

struct TasteProfile: Codable {
    let profile_name: String?
    let movies_count: Int?
    let shows_count: Int?
    let favorites: [TasteItem]
}

struct TasteItem: Codable {
    let title: String
    let media_type: String?
    let weight: Int?
    let genre: String?
    let creator_or_director: String?
    let detected_count: Int?
}

struct WatchRow: Identifiable {
    let id = UUID()
    let title: String
}

struct ScoredTitle: Identifiable {
    let id = UUID()
    let item: CatalogTitle
    let score: Int
    let reason: String
}

struct ContentView: View {
    @State private var catalog: [CatalogTitle] = []
    @State private var tasteItems: [TasteItem] = []
    @State private var watchRows: [WatchRow] = []
    @State private var blockedTitles: Set<String> = []
    @State private var search = ""
    @State private var generatedLines = 12094
    @State private var status = "Loading local catalog and Greg taste profile..."

    var watchedKeys: Set<String> {
        Set(watchRows.map { normalize($0.title) })
    }

    var tasteWordScores: [String: Int] {
        var scores: [String: Int] = [:]

        for item in tasteItems {
            let weight = item.weight ?? 5
            let text = "\(item.title) \(item.genre ?? "") \(item.creator_or_director ?? "")"

            for word in words(text) {
                scores[word, default: 0] += weight
            }
        }

        return scores
    }

    var recommendations: [ScoredTitle] {
        let q = normalize(search)
        let scores = tasteWordScores
        let watched = watchedKeys

        return catalog.compactMap { item in
            let key = normalize(item.title)
            if watched.contains(key) { return nil }
            if blockedTitles.contains(where: { key.contains($0) || $0.contains(key) }) { return nil }

            let text = "\(item.title) \(item.year.map(String.init) ?? "") \(item.description ?? "")"
            if !q.isEmpty && !normalize(text).contains(q) { return nil }

            let matchedWords = words(text).filter { scores[$0, default: 0] > 0 }
            let score = matchedWords.reduce(0) { $0 + scores[$1, default: 0] }

            let reason = matchedWords.prefix(5).joined(separator: ", ")

            return ScoredTitle(
                item: item,
                score: score,
                reason: reason.isEmpty ? "Available in local catalog" : "Matches: \(reason)"
            )
        }
        .sorted {
            if $0.score == $1.score { return $0.item.title < $1.item.title }
            return $0.score > $1.score
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                header

                HStack {
                    Spacer()
                    Text("TECH STACK: Orion → Swifter → Swift → SwiftUI → Python → Perl → JSON → CSV → HTML → Git → SHA-256 → macOS")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .tracking(1.1)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                Text(status)
                    .foregroundStyle(.gray)

                TextField("", text: $search, prompt: Text("Search recommendations").foregroundColor(.gray))
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color(red: 0.08, green: 0.08, blue: 0.08))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 1.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack {
                    metricCard("Taste Signals", "\(tasteItems.count)")
                    metricCard("Watched Rows", "\(watchRows.count)")
                    metricCard("Catalog", "\(catalog.count)")
                    metricCard("Recommendations", "\(recommendations.count)")
                    metricCard("Generated Lines", String(generatedLines))
                }

                HStack {
                    Text("Orion AI Recommendations Based on Greg's Taste Profile")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(.white)

                    Spacer()

                    Text(search.isEmpty ? "Showing all ranked recommendations" : "Filtering: \(search)")
                        .foregroundStyle(.gray)
                }

                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(190), spacing: 18), count: 5), spacing: 22) {
                        ForEach(recommendations) { scored in
                            posterCard(scored)
                        }
                    }
                    .padding(.bottom, 30)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 0)
            .frame(minWidth: 1100, minHeight: 760)
        }
        .onAppear {
            loadCatalog()
            loadTasteProfile()
            loadMergedViewingHistory()
            loadDoNotRecommend()
        }
    }

    var header: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: -6) {
                Text("NETFLIX")
                    .font(.system(size: 50, weight: .black))
                    .foregroundStyle(.red)
                Text("ORION AI RECOMMENDER")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Workflow Proof")
                    .font(.title2).bold().foregroundStyle(.white)
                Text("Greg taste profile + local catalog + Netflix viewing history filter — built in ~3 hours")
                    .foregroundStyle(.gray)
            }

            Spacer()

            Button("Choose Netflix Viewing History CSV") { chooseCSV() }
                .buttonStyle(.borderedProminent)
        }
    }

    func posterCard(_ scored: ScoredTitle) -> some View {
        let item = scored.item

        return VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
                    .frame(height: 260)

                if let poster = item.poster_url,
                   let url = URL(string: poster),
                   !poster.isEmpty {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView().frame(height: 260)
                        case .success(let image):
                            image.resizable()
                                .scaledToFill()
                                .frame(height: 260)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .failure:
                            posterPlaceholder(item)
                        @unknown default:
                            posterPlaceholder(item)
                        }
                    }
                } else {
                    posterPlaceholder(item)
                }
            }

            Text(item.title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)

            Text("Score: \(scored.score)")
                .font(.caption)
                .foregroundStyle(.red)

            Text(scored.reason)
                .font(.caption)
                .foregroundStyle(.gray)
                .lineLimit(2)
        }
        .padding()
        .background(Color(red: 0.07, green: 0.07, blue: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    func posterPlaceholder(_ item: CatalogTitle) -> some View {
        VStack(spacing: 10) {
            Text("N")
                .font(.system(size: 56, weight: .black))
                .foregroundStyle(.red)
            Text(item.year.map(String.init) ?? "NEW")
                .foregroundStyle(.gray)
        }
        .frame(height: 260)
    }

    func metricCard(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title).foregroundStyle(.gray)
            Text(value).font(.title).bold().foregroundStyle(.white)
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
        panel.canChooseFiles = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            loadViewingHistory(url)
        }
    }



    func loadDoNotRecommend() {
        let url = URL(fileURLWithPath: "/Users/greg/Projects/Swifter/SwifterCLI/Swifter_Recommender/Data/do_not_recommend.json")

        guard
            let data = try? Data(contentsOf: url),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let titles = json["titles"] as? [String]
        else { return }

        blockedTitles = Set(titles.map { normalize($0) })
    }

    func loadMergedViewingHistory() {
        let url = URL(fileURLWithPath: "/Users/greg/Projects/Swifter/SwifterCLI/Swifter_Recommender/Data/merged_netflix_viewing_history.csv")

        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }

        let parsed = text.split(separator: "\n").dropFirst().map { line in
            WatchRow(title: firstCSVField(String(line)))
        }
        .filter { !$0.title.isEmpty }

        watchRows = Array(parsed.prefix(10000))
        status = "Loaded catalog + taste profile + merged Netflix watched history: \(watchRows.count) watched rows"
    }

    func loadViewingHistory(_ url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            status = "Could not read \(url.lastPathComponent)"
            return
        }

        let parsed = text.split(separator: "\n").dropFirst().map { line in
            WatchRow(title: firstCSVField(String(line)))
        }
        .filter { !$0.title.isEmpty }

        watchRows = Array(parsed.prefix(3000))
        status = "Loaded \(watchRows.count) Netflix viewing rows. Watched titles are filtered out; taste profile drives ranking."
    }

    func loadCatalog() {
        let url = URL(fileURLWithPath: "/Users/greg/Projects/Swifter/SwifterCLI/Swifter_Recommender/Data/available_titles.json")

        if let data = try? Data(contentsOf: url),
           let payload = try? JSONDecoder().decode(CatalogPayload.self, from: data) {
            catalog = payload.titles
            status = "Loaded local catalog: \(payload.count) titles"
        } else {
            status = "Catalog not loaded. Expected Data/available_titles.json"
        }
    }

    func loadTasteProfile() {
        let url = URL(fileURLWithPath: "/Users/greg/Projects/Swifter/SwifterCLI/Swifter_Recommender/Data/greg_taste_profile.json")

        if let data = try? Data(contentsOf: url),
           let payload = try? JSONDecoder().decode(TasteProfile.self, from: data) {
            tasteItems = payload.favorites
            status = "Loaded catalog + Greg taste profile: \(payload.favorites.count) taste signals"
        } else {
            status = "Taste profile not loaded. Expected Data/greg_taste_profile.json"
        }
    }

    func firstCSVField(_ line: String) -> String {
        var result = ""
        var inQuotes = false

        for ch in line {
            if ch == "\"" {
                inQuotes.toggle()
            } else if ch == "," && !inQuotes {
                break
            } else {
                result.append(ch)
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: #"[^a-z0-9 ]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func words(_ s: String) -> [String] {
        let stop: Set<String> = [
            "the","and","or","of","a","an","to","in","on","for","with","by",
            "season","episode","movie","film","watch","stream","online",
            "where","find","guide","part","chapter"
        ]

        return normalize(s)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 2 && !stop.contains($0) }
    }
}
