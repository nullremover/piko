import Foundation
import AVFoundation
import Combine
import MediaPlayer
import UIKit

final class PlaybackClock: ObservableObject {
    @Published var elapsed: Double = 0
    @Published var duration: Double = 0

    var progress: Double {
        duration > 0 ? min(max(elapsed / duration, 0), 1) : 0
    }
}

enum LyricsState {
    case none, loading, ready
}

class AudioPlayerManager: ObservableObject {
    private var player: AVPlayer?
    private var statusObservation: NSKeyValueObservation?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var artworkImage: UIImage?
    private var artworkToken = UUID()
    private var lyricsToken = UUID()

    let clock = PlaybackClock()

    @Published var isPlaying = false
    @Published var currentTrackTitle: String = "No Track Selected"
    @Published var currentArtist: String = ""
    @Published var currentArtworkURL: URL? = nil
    @Published var errorMessage: String?
    @Published var queue: [Track] = []
    @Published var currentIndex: Int? = nil

    @Published var lyrics: [LyricLine] = []
    @Published var lyricsSynced = false
    @Published var lyricsState: LyricsState = .none

    var currentTrack: Track? {
        guard let i = currentIndex, queue.indices.contains(i) else { return nil }
        return queue[i]
    }

    init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
        configureRemoteCommands()
    }

    // MARK: - Queue

    func play(track: Track, in tracks: [Track]) {
        queue = tracks
        guard let i = tracks.firstIndex(where: { $0.url == track.url }) else { return }
        start(at: i)
    }

    func next() {
        guard let i = currentIndex, !queue.isEmpty else { return }
        start(at: (i + 1) % queue.count)
    }

    func previous() {
        guard let i = currentIndex, !queue.isEmpty else { return }
        if clock.elapsed > 3 {
            seek(toFraction: 0)
            return
        }
        start(at: (i - 1 + queue.count) % queue.count)
    }

    private func start(at index: Int) {
        guard queue.indices.contains(index) else { return }
        currentIndex = index
        let t = queue[index]
        playTrack(
            urlString: t.url,
            title: t.title,
            artist: t.artist,
            artworkURLString: t.artwork,
            lyricsURLString: t.lyrics
        )
    }

    // MARK: - Playback

    func playTrack(urlString: String,
                   title: String,
                   artist: String,
                   artworkURLString: String? = nil,
                   lyricsURLString: String? = nil) {
        guard let url = URL(string: urlString) else {
            errorMessage = "Bad URL: \(urlString)"
            return
        }

        currentTrackTitle = title
        currentArtist = artist
        currentArtworkURL = artworkURLString.flatMap { URL(string: $0) }
        clock.elapsed = 0
        clock.duration = 0

        let item = AVPlayerItem(url: url)

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self?.updateNowPlaying()
                case .failed:
                    self?.errorMessage = item.error?.localizedDescription ?? "Unknown playback error"
                    self?.isPlaying = false
                    self?.updateNowPlaying()
                default:
                    break
                }
            }
        }

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.next()
        }

        if let player {
            player.replaceCurrentItem(with: item)
        } else {
            let newPlayer = AVPlayer(playerItem: item)
            player = newPlayer
            timeObserver = newPlayer.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
                queue: .main
            ) { [weak self] time in
                guard let self, time.seconds.isFinite else { return }
                self.clock.elapsed = time.seconds
                if let d = self.player?.currentItem?.duration.seconds, d.isFinite, d > 0 {
                    self.clock.duration = d
                }
            }
        }

        artworkImage = ArtworkRenderer.placeholderImage(title: title, size: 600)
        loadArtwork(title: title)
        loadLyrics(urlString: lyricsURLString)

        play()
    }

    func play() {
        player?.play()
        isPlaying = true
        updateNowPlaying()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func togglePlayPause() {
        guard player != nil else { return }
        isPlaying ? pause() : play()
    }

    func seek(toFraction fraction: Double) {
        guard clock.duration > 0 else { return }
        let target = min(max(fraction, 0), 1) * clock.duration
        clock.elapsed = target
        player?.seek(to: CMTime(seconds: target, preferredTimescale: 600)) { [weak self] _ in
            DispatchQueue.main.async { self?.updateNowPlaying() }
        }
    }

    func seek(toSeconds seconds: Double) {
        guard clock.duration > 0 else { return }
        seek(toFraction: seconds / clock.duration)
    }

    // MARK: - Artwork

    private func loadArtwork(title: String) {
        let token = UUID()
        artworkToken = token
        let url = currentArtworkURL

        Task {
            let image = await ArtworkRenderer.loadImage(from: url, title: title)
            await MainActor.run {
                guard self.artworkToken == token else { return }
                self.artworkImage = image
                self.updateNowPlaying()
            }
        }
    }

    // MARK: - Lyrics

    private func loadLyrics(urlString: String?) {
        let token = UUID()
        lyricsToken = token
        lyrics = []
        lyricsSynced = false

        guard let urlString, let url = URL(string: urlString) else {
            lyricsState = .none
            return
        }
        lyricsState = .loading

        Task {
            var parsed: ParsedLyrics? = nil
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                    let text = String(data: data, encoding: .utf8)
                        ?? String(decoding: data, as: UTF8.self)
                    parsed = LRCParser.parse(text)
                }
            } catch {
                print("Lyrics load failed: \(error.localizedDescription)")
            }

            await MainActor.run {
                guard self.lyricsToken == token else { return }   // track changed meanwhile
                if let parsed, !parsed.lines.isEmpty {
                    self.lyrics = parsed.lines
                    self.lyricsSynced = parsed.isSynced
                    self.lyricsState = .ready
                } else {
                    self.lyricsState = .none
                }
            }
        }
    }

    // MARK: - Lock screen

    private func updateNowPlaying() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentTrackTitle,
            MPMediaItemPropertyArtist: currentArtist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player?.currentTime().seconds ?? 0,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        if let duration = player?.currentItem?.duration.seconds, duration.isFinite {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }

        if let image = artworkImage {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.play() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.togglePlayPause() }
            return .success
        }
        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.next() }
            return .success
        }
        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.previous() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            DispatchQueue.main.async {
                self?.seek(toSeconds: event.positionTime)
            }
            return .success
        }
    }
}
