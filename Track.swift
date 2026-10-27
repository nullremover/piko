import Foundation

struct Track: Identifiable, Codable {
    var id = UUID()
    let title: String
    let artist: String
    let url: String
    var artwork: String? = nil
    var lyrics: String? = nil

    enum CodingKeys: String, CodingKey {
        case title, artist, url, artwork, lyrics   // no `id`
    }
}
