import Foundation

struct Track: Identifiable, Codable {
	let id = UUID()
	let title: String
	let artist: String
	let streamUrl: String // will hold the github pages mp3 link!
	let artworkUrl: String?
}

