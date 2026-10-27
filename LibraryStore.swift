import Foundation
import SwiftUI

extension Track {
    // Stable key for saved likes/history (doesn't change if you rotate the access key)
    var libraryKey: String { "\(artist.lowercased())|\(title.lowercased())" }
    var artworkURL: URL? { artwork.flatMap { URL(string: $0) } }
}

func uniqueTracks(_ list: [Track]) -> [Track] {
    var seen = Set<String>()
    return list.filter { seen.insert($0.libraryKey).inserted }
}

func songCount(_ n: Int) -> String {
    n == 1 ? "1 song" : "\(n) songs"
}

final class LibraryStore: ObservableObject {
    @Published private(set) var liked: [String] = []     // newest first
    @Published private(set) var recents: [String] = []   // newest first

    private let likedKey = "piko.liked"
    private let recentsKey = "piko.recents"

    init() {
        let defaults = UserDefaults.standard
        liked = defaults.stringArray(forKey: likedKey) ?? []
        recents = defaults.stringArray(forKey: recentsKey) ?? []
    }

    func isLiked(_ track: Track) -> Bool {
        liked.contains(track.libraryKey)
    }

    func toggleLike(_ track: Track) {
        if let i = liked.firstIndex(of: track.libraryKey) {
            liked.remove(at: i)
        } else {
            liked.insert(track.libraryKey, at: 0)
        }
        UserDefaults.standard.set(liked, forKey: likedKey)
    }

    func markPlayed(_ track: Track) {
        recents.removeAll { $0 == track.libraryKey }
        recents.insert(track.libraryKey, at: 0)
        if recents.count > 20 { recents = Array(recents.prefix(20)) }
        UserDefaults.standard.set(recents, forKey: recentsKey)
    }

    func likedTracks(in tracks: [Track]) -> [Track] {
        liked.compactMap { key in tracks.first { $0.libraryKey == key } }
    }

    func recentTracks(in tracks: [Track]) -> [Track] {
        recents.compactMap { key in tracks.first { $0.libraryKey == key } }
    }
}
