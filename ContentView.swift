import SwiftUI

private func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds)
    return String(format: "%d:%02d", total / 60, total % 60)
}

// MARK: - Main screen

struct ContentView: View {
    @StateObject private var audioManager = AudioPlayerManager()
    @StateObject private var playlistLoader = PlaylistLoader()
    @StateObject private var themeManager = ThemeManager()

    private let jsonUrl = "https://piko-music.luckyexogd.workers.dev/playlist.json?k=PIKOMUSIC_SH3R1PSM30UT0FMYB0DY"

    @State private var searchText = ""
    @State private var showNowPlaying = false

    private var theme: PikoTeaTheme { themeManager.currentTheme }

    private var filteredTracks: [Track] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return playlistLoader.tracks }
        return playlistLoader.tracks.filter {
            $0.title.lowercased().contains(q) || $0.artist.lowercased().contains(q)
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.backgroundColor, theme.primaryColor.opacity(0.30)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                searchBar
                content
            }
        }
        .preferredColorScheme(theme == .splashOfMilk ? .light : .dark)
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
        }
        .onAppear {
            if playlistLoader.tracks.isEmpty {
                playlistLoader.loadPlaylist(from: jsonUrl)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("piko")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundColor(theme.primaryColor)
                Text("\(playlistLoader.tracks.count) \(playlistLoader.tracks.count == 1 ? "song" : "songs")")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textColor.opacity(0.6))
            }
            Spacer()

            Button {
                playlistLoader.loadPlaylist(from: jsonUrl)
            } label: {
                circleIcon("arrow.clockwise")
            }

            Menu {
                Picker("Tea Strength", selection: $themeManager.currentTheme) {
                    ForEach(PikoTeaTheme.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
            } label: {
                circleIcon("cup.and.saucer.fill")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func circleIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(theme.primaryColor)
            .frame(width: 40, height: 40)
            .background(theme.primaryColor.opacity(0.15), in: Circle())
    }

    // MARK: Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
            TextField("search songs or artists", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
            }
        }
        .foregroundColor(theme.textColor.opacity(0.7))
        .padding(12)
        .background(theme.textColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if playlistLoader.tracks.isEmpty {
            if playlistLoader.isLoading {
                VStack {
                    Spacer()
                    ProgressView().tint(theme.primaryColor)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                statusView
            }
        } else {
            trackList
        }
    }

    private var statusView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: playlistLoader.errorMessage == nil ? "music.note.list" : "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(theme.primaryColor)
            Text(playlistLoader.errorMessage ?? "nothing steeping yet")
                .font(.subheadline)
                .foregroundColor(theme.textColor.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("try again") {
                playlistLoader.loadPlaylist(from: jsonUrl)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primaryColor)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var trackList: some View {
        List {
            ForEach(filteredTracks) { track in
                TrackRow(
                    track: track,
                    theme: theme,
                    isCurrent: audioManager.currentTrack?.url == track.url,
                    isPlaying: audioManager.isPlaying
                )
                .contentShape(Rectangle())
                .onTapGesture { select(track) }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 2, leading: 14, bottom: 2, trailing: 14))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { playlistLoader.loadPlaylist(from: jsonUrl) }
        .overlay {
            if filteredTracks.isEmpty {
                Text("no matches")
                    .font(.subheadline)
                    .foregroundColor(theme.textColor.opacity(0.6))
            }
        }
    }

    private func select(_ track: Track) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if audioManager.currentTrack?.url == track.url {
            audioManager.togglePlayPause()
        } else {
            audioManager.play(track: track, in: filteredTracks)
        }
    }
}

// MARK: - Track row

struct TrackRow: View {
    let track: Track
    let theme: PikoTeaTheme
    let isCurrent: Bool
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 14) {
            ArtworkView(
                url: track.artwork.flatMap { URL(string: $0) },
                title: track.title,
                cornerRadius: 10,
                shadowRadius: 3,
                placeholderSize: 160
            )
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(isCurrent ? theme.primaryColor : theme.textColor)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(theme.textColor.opacity(0.65))
                    .lineLimit(1)
            }

            Spacer()

            if isCurrent {
                Image(systemName: isPlaying ? "waveform" : "pause.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryColor)
            }
        }
        .padding(8)
        .background(
            isCurrent ? theme.primaryColor.opacity(0.15) : Color.clear,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}

// MARK: - Mini player

struct MiniPlayer: View {
    @ObservedObject var audioManager: AudioPlayerManager
    @ObservedObject var clock: PlaybackClock
    let theme: PikoTeaTheme
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(
                url: audioManager.currentArtworkURL,
                title: audioManager.currentTrackTitle,
                cornerRadius: 8,
                shadowRadius: 0,
                placeholderSize: 160
            )
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(audioManager.currentTrackTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.textColor)
                    .lineLimit(1)
                Text(audioManager.currentArtist)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(theme.textColor.opacity(0.65))
                    .lineLimit(1)
            }

            Spacer()

            Button {
                audioManager.togglePlayPause()
            } label: {
                Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22))
                    .frame(width: 36, height: 36)
            }

            Button {
                audioManager.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 20))
                    .frame(width: 36, height: 36)
            }
        }
        .foregroundColor(theme.primaryColor)
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            GeometryReader { geo in
                Capsule()
                    .fill(theme.primaryColor)
                    .frame(width: geo.size.width * clock.progress, height: 3)
            }
            .frame(height: 3)
            .padding(.horizontal, 16)
            .padding(.bottom, 3)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Full-screen player

struct NowPlayingView: View {
    @ObservedObject var audioManager: AudioPlayerManager
    @ObservedObject var clock: PlaybackClock
    let theme: PikoTeaTheme

    @Environment(\.dismiss) private var dismiss
    @State private var scrub: Double = 0
    @State private var isScrubbing = false

    private var shownElapsed: Double {
        isScrubbing ? scrub * clock.duration : clock.elapsed
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.primaryColor.opacity(0.45), theme.backgroundColor],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    Spacer()
                    Text("now playing")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Spacer()
                    Color.clear.frame(width: 24, height: 24)
                }
                .foregroundColor(theme.textColor.opacity(0.8))
                .padding(.top, 16)

                Spacer(minLength: 0)

                ArtworkView(
                    url: audioManager.currentArtworkURL,
                    title: audioManager.currentTrackTitle,
                    cornerRadius: 24
                )
                .padding(.horizontal, 28)
                .scaleEffect(audioManager.isPlaying ? 1.0 : 0.88)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: audioManager.isPlaying)

                VStack(spacing: 6) {
                    Text(audioManager.currentTrackTitle)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textColor)
                        .multilineTextAlignment(.center)
                    Text(audioManager.currentArtist)
                        .font(.system(size: 17, design: .rounded))
                        .foregroundColor(theme.primaryColor)
                }
                .padding(.horizontal, 24)

                VStack(spacing: 4) {
                    Slider(value: $scrub, in: 0...1, onEditingChanged: { editing in
                        isScrubbing = editing
                        if !editing {
                            audioManager.seek(toFraction: scrub)
                        }
                    })
                    .tint(theme.primaryColor)

                    HStack {
                        Text(formatTime(shownElapsed))
                        Spacer()
                        Text("-" + formatTime(max(clock.duration - shownElapsed, 0)))
                    }
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(theme.textColor.opacity(0.6))
                }
                .padding(.horizontal, 28)

                HStack(spacing: 44) {
                    Button {
                        audioManager.previous()
                    } label: {
                        Image(systemName: "backward.fill").font(.system(size: 28))
                    }

                    Button {
                        audioManager.togglePlayPause()
                    } label: {
                        Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 78))
                    }

                    Button {
                        audioManager.next()
                    } label: {
                        Image(systemName: "forward.fill").font(.system(size: 28))
                    }
                }
                .foregroundColor(theme.primaryColor)

                Spacer(minLength: 0)
            }
        }
        .preferredColorScheme(theme == .splashOfMilk ? .light : .dark)
        .onAppear { scrub = clock.progress }
        .onReceive(clock.$elapsed) { e in
            if !isScrubbing && clock.duration > 0 {
                scrub = min(max(e / clock.duration, 0), 1)
            }
        }
    }
}
