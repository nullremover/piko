import Foundation

struct LyricLine: Identifiable, Equatable {
    let id: Int
    let time: Double      // seconds; -1 for unsynced lines
    let text: String
}

struct ParsedLyrics {
    let lines: [LyricLine]
    let isSynced: Bool
}

enum LRCParser {
    private static let timeRegex = try! NSRegularExpression(
        pattern: #"\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]"#
    )
    // enhanced LRC word timings like <00:12.34>
    private static let wordRegex = try! NSRegularExpression(
        pattern: #"<\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?>"#
    )

    static func parse(_ rawText: String) -> ParsedLyrics {
        var text = rawText
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }   // strip BOM

        var entries: [(time: Double, text: String)] = []
        var plain: [String] = []
        var offset = 0.0

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            let ns = line as NSString
            let matches = timeRegex.matches(in: line, range: NSRange(location: 0, length: ns.length))

            if matches.isEmpty {
                let lower = line.lowercased()
                if lower.hasPrefix("[offset:"), let end = line.firstIndex(of: "]") {
                    let start = line.index(line.startIndex, offsetBy: 8)
                    let value = line[start..<end].trimmingCharacters(in: .whitespaces)
                    offset = (Double(value) ?? 0) / 1000
                } else if !(line.hasPrefix("[") && line.contains(":") && line.hasSuffix("]")) {
                    plain.append(line)   // not a metadata tag, so keep as plain lyrics
                }
                continue
            }

            guard let last = matches.last else { continue }
            var lyric = ns.substring(from: last.range.location + last.range.length)
            lyric = wordRegex.stringByReplacingMatches(
                in: lyric,
                range: NSRange(location: 0, length: (lyric as NSString).length),
                withTemplate: ""
            ).trimmingCharacters(in: .whitespaces)

            for m in matches {
                let minutes = Double(ns.substring(with: m.range(at: 1))) ?? 0
                let seconds = Double(ns.substring(with: m.range(at: 2))) ?? 0
                var fraction = 0.0
                if m.range(at: 3).location != NSNotFound {
                    fraction = Double("0." + ns.substring(with: m.range(at: 3))) ?? 0
                }
                entries.append((minutes * 60 + seconds + fraction - offset, lyric))
            }
        }

        if entries.isEmpty {
            let lines = plain.enumerated().map { LyricLine(id: $0.offset, time: -1, text: $0.element) }
            return ParsedLyrics(lines: lines, isSynced: false)
        }

        let sorted = entries.sorted { $0.time < $1.time }
        let lines = sorted.enumerated().map {
            LyricLine(id: $0.offset, time: max($0.element.time, 0), text: $0.element.text)
        }
        return ParsedLyrics(lines: lines, isSynced: true)
    }
}
