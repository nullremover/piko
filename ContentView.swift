import SwiftUI
import UniformTypeIdentifiers

// MARK: - Main Container ContentView

struct ContentView: View {
    @StateObject private var audioManager = AudioPlayerManager()
    @StateObject private var playlistLoader = PlaylistLoader()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var library = LibraryStore()

    static let jsonUrl = "https://piko-music.luckyexogd.workers.dev/playlist.json?k=PIKOMUSIC_SH3R1PSM30UT0FMYB0DY"

    @State private var selectedTab = 0
    @State private var showNowPlaying = false
    @State private var showMusicImporter = false
    @State private var localTracks: [Track] = []
    @State private var importError: String?

    private var theme: PikoTeaTheme { themeManager.currentTheme }

    private var allTracks: [Track] {
        playlistLoader.tracks + localTracks
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(0)
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }

                SearchView()
                    .tag(1)
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }

                LibraryView()
                    .tag(2)
                    .tabItem {
                        Label("Library", systemImage: "books.vertical.fill")
                    }
            }
            .accentColor(theme.primaryColor)
            .preferredColorScheme(theme == .splashOfMilk ? .light : .dark)
        }
        .safeAreaInset(edge: .bottom) {
            if audioManager.currentTrack != nil {
                MiniPlayer(audioManager: audioManager, clock: audioManager.clock, theme: theme) {
                    showNowPlaying = true
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView(audioManager: audioManager, clock: audioManager.clock, theme: theme)
                .environmentObject(library)
        }
        // Inject all managers down the environment tree so screens can consume them effortlessly
        .environmentObject(audioManager)
        .environmentObject(playlistLoader)
        .environmentObject(themeManager)
        .environmentObject(library)
        .onAppear {
            loadLocalTracks()
            if playlistLoader.tracks.isEmpty {
                playlistLoader.loadPlaylist(from: Self.jsonUrl)
            }
        }
        .fileImporter(
            isPresented: $showMusicImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                importLocalFiles(urls)
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .alert(
            "Couldn't import music",
            isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                importError = nil
            }
        } message: {
            Text(importError ?? "Unknown error")
        }
    }

    // MARK: - Local File Management

    private var importedMusicFolder: URL {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("ImportedMusic", isDirectory: true)
    }

    private func loadLocalTracks() {
        do {
            try FileManager.default.createDirectory(
                at: importedMusicFolder,
                withIntermediateDirectories: true
            )

            let files = try FileManager.default.contentsOfDirectory(
                at: importedMusicFolder,
                includingPropertiesForKeys: nil
            )

            let audioExtensions: Set<String> = [
                "mp3", "m4a", "aac", "wav", "aif",
                "aiff", "caf", "flac", "alac"
            ]

            localTracks = files
                .filter { audioExtensions.contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
                .map { url in
                    Track(
                        title: url.deletingPathExtension().lastPathComponent,
                        artist: "Local File",
                        url: url.absoluteString,
                        source: .local
                    )
                }
        } catch {
            importError = error.localizedDescription
        }
    }

    private func importLocalFiles(_ urls: [URL]) {
        do {
            try FileManager.default.createDirectory(
                at: importedMusicFolder,
                withIntermediateDirectories: true
            )

            for sourceURL in urls {
                let hasAccess = sourceURL.startAccessingSecurityScopedResource()
                defer {
                    if hasAccess {
                        sourceURL.stopAccessingSecurityScopedResource()
                    }
                }

                let ext = sourceURL.pathExtension.lowercased()
                let allowedExtensions: Set<String> = [
                    "mp3", "m4a", "aac", "wav", "aif",
                    "aiff", "caf", "flac", "alac"
                ]

                guard allowedExtensions.contains(ext) else { continue }

                let destinationURL = importedMusicFolder
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(ext)

                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            }

            loadLocalTracks()
        } catch {
            importError = error.localizedDescription
        }
    }
}
