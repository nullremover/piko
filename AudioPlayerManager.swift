import Foundation
import AVFoundation
import Combine

class AudioPlayerManager: ObservableObject {
    private var player: AVPlayer?
    
    @Published var isPlaying = false
    @Published var currentTrackTitle: String = "No Track Selected"
    @Published var currentArtist: String = ""
    @Published var progress: Double = 0.0

    // Play a specific track from a web URL
    func playTrack(urlString: String, title: String, artist: String) {
        guard let url = URL(string: urlString) else { return }
        
        currentTrackTitle = title
        currentArtist = artist
        
        let playerItem = AVPlayerItem(url: url)
        
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        
        player?.play()
        isPlaying = true
    }

    // Toggle between play and pause
    func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
}