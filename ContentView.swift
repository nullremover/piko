import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioPlayerManager()
    @StateObject private var playlistLoader = PlaylistLoader()
    @StateObject private var themeManager = ThemeManager()
    
    // Replace this with your actual GitHub Pages JSON raw URL once you host it!
    // Example: "https://your-username.github.io/piko/playlist.json"
    @State private var jsonUrlInput: String = "https://raw.githubusercontent.com/nullremover/piko/main/playlist.json"

    var body: some View {
        ZStack {
            // Dynamic Tea Background
            themeManager.currentTheme.backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header & Tea Theme Picker
                VStack(spacing: 8) {
                    Text("piko player")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    
                    // The Orange Pekoe Theme Switcher
                    Picker("Tea Strength", selection: $themeManager.currentTheme) {
                        ForEach(PikoTeaTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                }
                .padding(.top)

                // Playlist Fetch Trigger
                HStack {
                    Button(action: {
                        playlistLoader.loadPlaylist(from: jsonUrlInput)
                    }) {
                        Text("Steep Playlist from Cloud")
                            .font(.headline)
                            .padding()
                            .background(themeManager.currentTheme.primaryColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }

                // Tracklist View
                if playlistLoader.isLoading {
                    ProgressView()
                        .tint(themeManager.currentTheme.primaryColor)
                        .padding()
                } else if let error = errorString(playlistLoader.errorMessage) {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.subheadline)
                        .padding()
                } else {
                    List(playlistLoader.tracks) { track in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(track.title)
                                    .font(.headline)
                                    .foregroundColor(themeManager.currentTheme.textColor)
                                Text(track.artist)
                                    .font(.subheadline)
                                    .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                            }
                            Spacer()
                            Button(action: {
                                audioManager.playTrack(urlString: track.streamUrl, title: track.title, artist: track.artist)
                            }) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                            }
                        }
                        .listRowBackground(themeManager.currentTheme.backgroundColor.opacity(0.8))
                    }
                    .scrollContentBackground(.hidden)
                }

                Spacer()

                // Now Playing Control Card
                VStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text(audioManager.currentTrackTitle)
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor)
                        Text(audioManager.currentArtist)
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                    }
                    
                    Button(action: {
                        audioManager.togglePlayPause()
                    }) {
                        Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 55))
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(themeManager.currentTheme.primaryColor.opacity(0.15))
                .cornerRadius(20)
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }
    
    func errorString(_ msg: String?) -> String? {
        return msg
    }
}