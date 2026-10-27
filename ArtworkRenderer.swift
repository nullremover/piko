import SwiftUI
import UIKit

// MARK: - SwiftUI view for the Now Playing screen
struct ArtworkView: View {
    let url: URL?
    let title: String
    var cornerRadius: CGFloat = 20

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(radius: 12, y: 6)
    }

    private var placeholder: some View {
        Image(uiImage: ArtworkRenderer.placeholderImage(title: title, size: 600))
            .resizable()
            .scaledToFill()
    }
}

// MARK: - UIImage rendering (used for lock screen artwork)
enum ArtworkRenderer {
    private static let cache = NSCache<NSURL, UIImage>()

    static func loadImage(from url: URL?, title: String) async -> UIImage {
        guard let url else { return placeholderImage(title: title, size: 600) }
        if let cached = cache.object(forKey: url as NSURL) { return cached }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                cache.setObject(image, forKey: url as NSURL)
                return image
            }
        } catch {
            print("Artwork load failed: \(error.localizedDescription)")
        }
        return placeholderImage(title: title, size: 600)
    }

    static func placeholderImage(title: String, size: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [
                UIColor(red: 0.85, green: 0.45, blue: 0.15, alpha: 1).cgColor,
                UIColor(red: 0.16, green: 0.08, blue: 0.04, alpha: 1).cgColor
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(gradient,
                                      start: .zero,
                                      end: CGPoint(x: size, y: size),
                                      options: [])
            }

            let initial = String(title.trimmingCharacters(in: .whitespaces).first ?? "♪").uppercased()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size * 0.45, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9)
            ]
            let text = NSAttributedString(string: initial, attributes: attrs)
            let textSize = text.size()
            text.draw(at: CGPoint(x: (size - textSize.width) / 2,
                                  y: (size - textSize.height) / 2))
        }
    }
}
