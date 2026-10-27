import SwiftUI

// MARK: - Navigation

enum Destination: Hashable {
    case artist(String)
    case liked
    case allSongs
}

struct DestinationView: View {
    let destination: Destination
    @EnvironmentObject private var loader: PlaylistLoader
    @EnvironmentObject private var library: LibraryStore

    var body: some View {
        switch destination {
        case .artist(let name):
            CollectionView(
                title: name,
                subtitle: "artist",
                tracks: loader.tracks.filter { $0.artist == name },
                symbol: nil
            )
        case .liked:
            let liked = library.likedTracks(in: loader.tracks)
            CollectionView(title: "liked songs", subtitle: songCount(liked.count), tracks: liked, symbol: "heart.fill")
        case .allSongs:
            CollectionView(
                title: "all songs",
                subtitle: songCount(loader.tracks.count),
                tracks: loader.tracks,
                symbol: "music.note"
            )
        }
    }
}

struct ScreenBackground: View {
    let theme: PikoTeaTheme

    var body: some View {
        ZStack {
            theme.backgroundColor
            LinearGradient(
                colors: [theme.primaryColor.opacity(0.35), Color.clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.5)
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Home

struct HomeView: View {
    @EnvironmentObject private var audio: AudioPlayerManager
    @EnvironmentObject private var loader: PlaylistLoader
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var library: LibraryStore

    private var theme: PikoTeaTheme { themeManager.currentTheme }
    private var tracks: [Track] { loader.tracks }
    private var recents: [Track] { library.recentTracks(in: tracks) }
    private var liked: [Track] { library.likedTracks(in: tracks) }
    private var quickPicks: [Track] { Array(uniqueTracks(recents + tracks).prefix(6)) }
    private var artists: [String] { Array(Set(tracks.map { $0.artist })).sorted() }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 5 && hour < 12 { return "good morning" }
        if hour >= 12 && hour < 18 { return "good afternoon" }
        return "good evening"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    if tracks.isEmpty {
                        emptyState
                    } else {
                        quickGrid

                        if recents.isEmpty {
                            shelf("your songs", tracks, .allSongs)
                        } else {
                            shelf("recently played", recents, nil)
                        }

                        if !liked.isEmpty {
                            shelf("your liked songs", liked, .liked)
                        }

                        ForEach(artists, id: \.self) { artist in
                            shelf(
                                "more from \(artist)",
                                tracks.filter { $0.artist == artist },
                                .artist(artist)
                            )
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(ScreenBackground(theme: theme))
            .refreshable { loader.loadPlaylist(from: ContentView.jsonUrl) }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Destination.self) { DestinationView(destination: $0) }
        }
    }

    private var header: some View {
        HStack {
            Text(greeting)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(theme.textColor)
            Spacer()
            Menu {
                Picker("Tea Strength", selection: $themeManager.currentTheme) {
                    ForEach(PikoTeaTheme.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                Button {
                    loader.loadPlaylist(from: ContentView.jsonUrl)
                } label: {
                    Label("refresh playlist", systemImage: "arrow.clockwise")
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(theme.textColor.opacity(0.85))
                    .frame(width: 40, height: 40)
                    .background(theme.textColor.opacity(0.1), in: Circle())
            }
        }
        .padding(.horizontal, 16)
    }

    private var quickGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
            spacing: 8
        ) {
            ForEach(quickPicks) { track in
                QuickTile(track: track, list: quickPicks)
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            if loader.isLoading {
                ProgressView().tint(theme.primaryColor)
            } else {
                Image(systemName: loader.errorMessage == nil ? "music.note.list" : "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(theme.primaryColor)
                Text(loader.errorMessage ?? "nothing steeping yet")
                    .font(.subheadline)
                    .foregroundColor(theme.textColor.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button("try again") {
                    loader.loadPlaylist(from: ContentView.jsonUrl)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func shelf(_ title: String, _ list: [Track], _ destination: Destination?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            shelfTitle(title, destination)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(list) { track in
                        TrackCard(track: track, list: list)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private func shelfTitle(_ title: String, _ destination: Destination?) -> some View {
        let label = Text(title)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundColor(theme.textColor)

        if let destination {
            NavigationLink(value: destination) {
                HStack(spacing: 6) {
                    label
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.textColor.opacity(0.6))
                }
            }
            .buttonStyle(.plain)
        } else {
            label
        }
    }
}

struct QuickTile: View {
    let track: Track
    let list: [Track]

    @EnvironmentObject private var audio: AudioPlayerManager
    @EnvironmentObject private var themeManager: ThemeManager

    private var theme: PikoTeaTheme { themeManager.currentTheme }

    var body: some View {
        Button {
            audio.play(track: track, in: list)
        } label: {
            HStack(spacing: 10) {
                ArtworkView(
                    url: track.artworkURL,
                    title: track.title,
                    cornerRadius: 0,
                    shadowRadius: 0,
                    placeholderSize: 160
                )
                .frame(width: 56, height: 56)

                Text(track.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.textColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .frame(height: 56)
            .background(theme.textColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct TrackCard: View {
    let track: Track
    let list: [Track]

    @EnvironmentObject private var audio: AudioPlayerManager
    @EnvironmentObject private var themeManager: ThemeManager

    private var theme: PikoTeaTheme { themeManager.currentTheme }

    var body: some View {
        Button {
            audio.play(track: track, in: list)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ArtworkView(
                    url: track.artworkURL,
                    title: track.title,
                    cornerRadius: 8,
                    shadowRadius: 0,
                    placeholderSize: 300
                )
                .frame(width: 150, height: 150)

                Text(track.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textColor)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textColor.opacity(0.6))
                    .lineLimit(1)
            }
            .frame(width: 150, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search

struct SearchView: View {
    @EnvironmentObject private var loader: PlaylistLoader
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var query = ""

    private var theme: PikoTeaTheme { themeManager.currentTheme }
    private var artists: [String] { Array(Set(loader.tracks.map { $0.artist })).sorted() }
    private var trimmed: String { query.trimmingCharacters(in: .whitespaces).lowercased() }

    private var results: [Track] {
        loader.tracks.filter {
            $0.title.lowercased().contains(trimmed) || $0.artist.lowercased().contains(trimmed)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("search")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textColor)

                    searchField

                    if trimmed.isEmpty {
                        Text("browse all")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(theme.textColor)

                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                            spacing: 12
                        ) {
                            ForEach(artists, id: \.self) { artist in
                                ArtistTile(
                                    name: artist,
                                    artworkURL: loader.tracks.first(where: { $0.artist == artist })?.artworkURL
                                )
                            }
                        }
                    } else if results.isEmpty {
                        Text("no results for \"\(query)\"")
                            .font(.subheadline)
                            .foregroundColor(theme.textColor.opacity(0.6))
                            .padding(.top, 24)
                    } else {
                        LazyVStack(spacing: 2) {
                            ForEach(results) { track in
                                SongRow(track: track, list: results)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(ScreenBackground(theme: theme))
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Destination.self) { DestinationView(destination: $0) }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
            TextField("what do you want to play?", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
            }
        }
        .foregroundColor(theme.textColor.opacity(0.7))
        .padding(12)
        .background(theme.textColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct ArtistTile: View {
    let name: String
    let artworkURL: URL?

    private var color: Color {
        var hash: UInt = 5381
        for scalar in name.unicodeScalars {
            hash = hash &* 33 &+ UInt(scalar.value)
        }
        return Color(hue: Double(hash % 360) / 360.0, saturation: 0.55, brightness: 0.6)
    }

    var body: some View {
        NavigationLink(value: Destination.artist(name)) {
            color
                .frame(height: 100)
                .overlay(alignment: .topLeading) {
                    Text(name)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(12)
                        .multilineTextAlignment(.leading)
                }
                .overlay(alignment: .bottomTrailing) {
                    ArtworkView(
                        url: artworkURL,
                        title: name,
                        cornerRadius: 4,
                        shadowRadius: 4,
                        placeholderSize: 160
                    )
                    .frame(width: 62, height: 62)
                    .rotationEffect(.degrees(25))
                    .offset(x: 12, y: 8)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Library

struct LibraryView: View {
    @EnvironmentObject private var loader: PlaylistLoader
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var library: LibraryStore

    private var theme: PikoTeaTheme { themeManager.currentTheme }
    private var artists: [String] { Array(Set(loader.tracks.map { $0.artist })).sorted() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("your library")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textColor)

                    NavigationLink(value: Destination.liked) {
                        LibraryRow(
                            title: "liked songs",
                            subtitle: "playlist • \(songCount(library.likedTracks(in: loader.tracks).count))"
                        ) {
                            ZStack {
                                LinearGradient(
                                    colors: [theme.primaryColor, theme.primaryColor.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                Image(systemName: "heart.fill").foregroundColor(.white)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: Destination.allSongs) {
                        LibraryRow(
                            title: "all songs",
                            subtitle: "playlist • \(songCount(loader.tracks.count))"
                        ) {
                            ZStack {
                                theme.textColor.opacity(0.12)
                                Image(systemName: "music.note").foregroundColor(theme.textColor)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                    .buttonStyle(.plain)

                    ForEach(artists, id: \.self) { artist in
                        NavigationLink(value: Destination.artist(artist)) {
                            LibraryRow(title: artist, subtitle: "artist") {
                                ArtworkView(
                                    url: loader.tracks.first(where: { $0.artist == artist })?.artworkURL,
                                    title: artist,
                                    cornerRadius: 30,
                                    shadowRadius: 0,
                                    placeholderSize: 160
                                )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(ScreenBackground(theme: theme))
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Destination.self) { DestinationView(destination: $0) }
        }
    }
}

struct LibraryRow<Leading: View>: View {
    let title: String
    let subtitle: String
    let leading: Leading

    @EnvironmentObject private var themeManager: ThemeManager

    init(title: String, subtitle: String, @ViewBuilder leading: () -> Leading) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading()
    }

    var body: some View {
        let theme = themeManager.currentTheme
        HStack(spacing: 14) {
            leading
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textColor)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textColor.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Playlist / artist page

struct CollectionView: View {
    let title: String
    let subtitle: String
    let tracks: [Track]
    let symbol: String?

    @EnvironmentObject private var audio: AudioPlayerManager
    @EnvironmentObject private var themeManager: ThemeManager

    private var theme: PikoTeaTheme { themeManager.currentTheme }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                cover
                    .frame(width: 200, height: 200)
                    .padding(.top, 8)

                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textColor)
                        .multilineTextAlignment(.center)
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(theme.textColor.opacity(0.6))
                }

                HStack(spacing: 28) {
                    Button {
                        shuffleAll()
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(theme.textColor.opacity(0.8))
                    }

                    Button {
                        playAll()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(theme.primaryColor, in: Circle())
                    }
                }
                .padding(.vertical, 4)

                if tracks.isEmpty {
                    Text("nothing here yet")
                        .font(.subheadline)
                        .foregroundColor(theme.textColor.opacity(0.6))
                        .padding(.top, 24)
                } else {
                    LazyVStack(spacing: 2) {
                        ForEach(tracks) { track in
                            SongRow(track: track, list: tracks)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(ScreenBackground(theme: theme))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var cover: some View {
        if let symbol {
            ZStack {
                LinearGradient(
                    colors: [theme.primaryColor, theme.primaryColor.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: symbol)
                    .font(.system(size: 64))
                    .foregroundColor(.white)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(radius: 14, y: 8)
        } else {
            ArtworkView(url: tracks.first?.artworkURL, title: title, cornerRadius: 12)
        }
    }

    private func playAll() {
        guard let first = tracks.first else { return }
        audio.play(track: first, in: tracks)
    }

    private func shuffleAll() {
        let shuffled = tracks.shuffled()
        guard let first = shuffled.first else { return }
        audio.play(track: first, in: shuffled)
    }
}

// MARK: - Song row

struct SongRow: View {
    let track: Track
    let list: [Track]

    @EnvironmentObject private var audio: AudioPlayerManager
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var themeManager: ThemeManager

    private var theme: PikoTeaTheme { themeManager.currentTheme }
    private var isCurrent: Bool { audio.currentTrack?.url == track.url }

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(
                url: track.artworkURL,
                title: track.title,
                cornerRadius: 6,
                shadowRadius: 0,
                placeholderSize: 160
            )
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isCurrent ? theme.primaryColor : theme.textColor)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textColor.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            if isCurrent && audio.isPlaying {
                Image(systemName: "waveform")
                    .foregroundColor(theme.primaryColor)
            }

            Button {
                library.toggleLike(track)
            } label: {
                Image(systemName: library.isLiked(track) ? "heart.fill" : "heart")
                    .font(.system(size: 18))
                    .foregroundColor(library.isLiked(track) ? theme.primaryColor : theme.textColor.opacity(0.6))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if isCurrent {
                audio.togglePlayPause()
            } else {
                audio.play(track: track, in: list)
            }
        }
    }
}
