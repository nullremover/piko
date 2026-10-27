import SwiftUI

enum PikoTeaTheme: String, CaseIterable, Identifiable {
    case standardBrew = "Standard brew"
    case splashOfMilk = "A splash of milk"
    case addedTeabags = "Added teabags"
    
    var id: String { self.rawValue }
    
    // Background colors for each steep level
    var backgroundColor: Color {
        switch self {
        case .standardBrew:
            return Color(red: 0.16, green: 0.08, blue: 0.04) // orange-brown
        case .splashOfMilk:
            return Color(red: 0.98, green: 0.95, blue: 0.92) // white
        case .addedTeabags:
            return Color(red: 0.03, green: 0.02, blue: 0.02) // Pitch-black
        }
    }
    
    // Accent colors representing the tea strength
    var primaryColor: Color {
        switch self {
        case .standardBrew:
            return Color(red: 0.85, green: 0.45, blue: 0.15) // dark orange
        case .splashOfMilk:
            return Color(red: 0.90, green: 0.60, blue: 0.35) // Soft orange
        case .addedTeabags:
            return Color(red: 1.0, green: 0.40, blue: 0.05)  // burnt pekoe
        }
    }
    
    // Dynamic text color to keep everything readable against the brew
    var textColor: Color {
        switch self {
        case .splashOfMilk:
            return Color(red: 0.16, green: 0.08, blue: 0.04) // Dark text for light mode
        default:
            return .white // Glowing text for the dark brews
        }
    }
}

class ThemeManager: ObservableObject {
    @Published var currentTheme: PikoTeaTheme = .standardBrew
}