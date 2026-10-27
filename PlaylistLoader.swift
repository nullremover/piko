import Foundation
import Combine

class PlaylistLoader: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // Fetch the playlist.json file from your web server / GitHub Pages URL
    func loadPlaylist(from urlString: String) {
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid URL syntax in the void."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Network bleeding error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "The cloud returned an empty abyss."
                    return
                }
                
                do {
                    // Decode the raw JSON directly into our Track model array
                    let decodedTracks = try JSONDecoder().decode([Track].self, from: data)
                    self?.tracks = decodedTracks
                } catch {
                    self.errorMessage = "Failed to parse soul manifest: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}
