struct Track: Identifiable, Codable {
    var id = UUID()
    let title: String
    let artist: String
    let url: String
    var artwork: String? = nil   // optional; old playlist entries still work
}
