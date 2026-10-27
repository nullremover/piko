
import Foundation

enum TrackSource: String, Codable {
    case online
    case local
}

struct Track: Identifiable, Codable {
    var id = UUID()
    let title: String
    let artist: String
    let url: String
    var artwork: String? = nil
    var lyrics: String? = nil
    var source: TrackSource = .online

    enum CodingKeys: String, CodingKey {
        case title, artist, url, artwork, lyrics, source
    }

    init(
        title: String,
        artist: String,
        url: String,
        artwork: String? = nil,
        lyrics: String? = nil,
        source: TrackSource = .online
    ) {
        self.id = UUID()
        self.title = title
        self.artist = artist
        self.url = url
        self.artwork = artwork
        self.lyrics = lyrics
        self.source = source
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        title = try c.decode(String.self, forKey: .title)
        artist = try c.decode(String.self, forKey: .artist)
        url = try c.decode(String.self, forKey: .url)
        artwork = try c.decodeIfPresent(String.self, forKey: .artwork)
        lyrics = try c.decodeIfPresent(String.self, forKey: .lyrics)
        source = try c.decodeIfPresent(TrackSource.self, forKey: .source) ?? .online
    }
}
