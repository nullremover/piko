import Foundation
import AVFoundation
import Combine
import MediaPlayer
import UIKit

class AudioPlayerManager: ObservableObject {
    private var player: AVPlayer?
    private var statusObservation: NSKeyValueObservation?
    private var timeObserver: Any?
    private var artworkImage: UIImage?
    private var artworkToken = UUID()

    @Published var isPlaying = false
    @Published var currentTrackTitle: String = "No Track Selected"
    @Published var currentArtist: String = ""
    @Published var currentArtworkURL: URL? = nil
    @Published var progress: Double = 0.0
    @Published var errorMessage: String?

    init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
        configureRemoteCommands()
    }

    // MARK: - Playback

    func playTrack(urlString: String, title: String, artist: String, artworkURLString: String? = nil) {
        guard let url = URL(string: urlString) else {
            errorMessage = "Bad URL: \(urlString)"
            return
        }

        currentTrackTitle = title
        currentArtist = artist
        currentArtworkURL = artworkURLString.flatMap { URL(string: $0) }
        progress = 0

        let item = AVPlayerItem(url: url)

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self?.updateNowPlaying()   // duration is known now
                case .failed:
                    self?.errorMessage = item.error?.localizedDescription ?? "Unknown playback error"
                    self?.isPlaying = false
                    self?.updateNowPlaying()
                default:
                    break
                }
            }
        }

        if let player {
            player.replaceCurrentItem(with: item)
        } else {
            let newPlayer = AVPlayer(playerItem: item)
            player = newPlayer
            timeObserver = newPlayer.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
                queue: .main
            ) { [weak self] time in
                guard let self,
                      let duration = self.player?.currentItem?.duration.seconds,
                      duration.isFinite, duration > 0 else { return }
                self.progress = time.seconds / duration
            }
        }

        // Show a generated cover right away, then swap in the real one
        artworkImage = ArtworkRenderer.placeholderImage(title: title, size: 600)
        loadArtwork(title: title)

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

    // MARK: - Artwork

    private func loadArtwork(title: String) {
        let token = UUID()
        artworkToken = token
        let url = currentArtworkURL

        Task {
            let image = await ArtworkRenderer.loadImage(from: url, title: title)
            await MainActor.run {
                guard self.artworkToken == token else { return }  // track changed meanwhile
                self.artworkImage = image
                self.updateNowPlaying()
            }
        }
    }

    // MARK: - Lock screen card

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
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            DispatchQueue.main.async {
                self?.player?.seek(to: CMTime(seconds: event.positionTime, preferredTimescale: 600)) { _ in
                    self?.updateNowPlaying()
                }
            }
            return .success
        }
    }
}
