import SwiftUI
import Combine

struct Theme: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let font: Font
    let mainBackgroundColor: Color
    let secondaryBackgroundColor: Color
    let textColor: Color
    let dayNumberColor: Color
    let otherMonthBackgroundColor: Color
    let highlightColor: Color
    let bubbleBackgroundColor: Color
    let gridLinesColor: Color
    let headerBackgroundColor: Color
    let footerBackgroundColor: Color
    let iconColor: Color
    let iconActiveColor: Color
    let parentOneColor: Color
    let parentTwoColor: Color
    
    var allColors: [Color] {
        [
            mainBackgroundColor,
            secondaryBackgroundColor,
            textColor,
            dayNumberColor,
            otherMonthBackgroundColor,
            highlightColor,
            bubbleBackgroundColor,
            gridLinesColor,
            headerBackgroundColor,
            footerBackgroundColor,
            iconColor,
            iconActiveColor,
            parentOneColor,
            parentTwoColor
        ]
    }

    static func == (lhs: Theme, rhs: Theme) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

class ThemeManager: ObservableObject {
    @Published var currentTheme: Theme
    
    let themes: [Theme] = [
        Theme(name: "Stork",
              font: .system(size: 24, weight: .bold, design: .default),
              mainBackgroundColor: Color(hex: "#fff"),
              secondaryBackgroundColor: Color(hex: "#f2f2f2"),
              textColor: Color(hex: "#000"),
              dayNumberColor: Color(hex: "#000"),
              otherMonthBackgroundColor: Color(hex: "#f7f7f7"),
              highlightColor: Color(hex: "#2a64c4"),
              bubbleBackgroundColor: Color(hex: "#f0f0f0"),
              gridLinesColor: Color(hex: "#e0e0e0"),
              headerBackgroundColor: Color(hex: "#e0e0e0"),
              footerBackgroundColor: Color(hex: "#f0f0f0"),
              iconColor: Color(hex: "#555"),
              iconActiveColor: Color(hex: "#007bff"),
              parentOneColor: Color(hex: "#96CBFC"),
              parentTwoColor: Color(hex: "#FFC2D9")),
        Theme(name: "Dracula",
              font: .system(size: 24, weight: .bold, design: .default),
              mainBackgroundColor: Color(hex: "#282a36"),
              secondaryBackgroundColor: Color(red: 0.1, green: 0.1, blue: 0.15),
              textColor: Color(hex: "#f8f8f2"),
              dayNumberColor: Color(red: 0.7, green: 0.7, blue: 0.7),
              otherMonthBackgroundColor: Color(hex: "#21222c"),
              highlightColor: Color(hex: "#ff79c6"),
              bubbleBackgroundColor: Color(hex: "#21222c"),
              gridLinesColor: Color(hex: "#191a21"),
              headerBackgroundColor: Color(hex: "#191a21"),
              footerBackgroundColor: Color(hex: "#191a21"),
              iconColor: Color(hex: "#bd93f9"),
              iconActiveColor: Color(hex: "#ff79c6"),
              parentOneColor: Color(hex: "#96CBFC"),
              parentTwoColor: Color(hex: "#FFC2D9")),
        Theme(name: "Vibe",
              font: .system(size: 24, weight: .bold, design: .default),
              mainBackgroundColor: Color(hex: "#251758"),
              secondaryBackgroundColor: Color(red: 0.9, green: 0.95, blue: 1.0),
              textColor: Color(hex: "#e0d8ff"),
              dayNumberColor: Color(red: 0.5, green: 0.6, blue: 0.8),
              otherMonthBackgroundColor: Color(hex: "#1a103c"),
              highlightColor: Color(hex: "#00fddc"),
              bubbleBackgroundColor: Color(hex: "#1a103c"),
              gridLinesColor: Color(hex: "#12092a"),
              headerBackgroundColor: Color(hex: "#12092a"),
              footerBackgroundColor: Color(hex: "#12092a"),
              iconColor: Color(hex: "#b3a5ef"),
              iconActiveColor: Color(hex: "#00fddc"),
              parentOneColor: Color(hex: "#96CBFC"),
              parentTwoColor: Color(hex: "#FFC2D9")),
        Theme(name: "Crayola",
              font: .system(size: 24, weight: .bold, design: .default),
              mainBackgroundColor: Color(hex: "#fff"),
              secondaryBackgroundColor: Color(red: 0.98, green: 0.98, blue: 0.98),
              textColor: Color(hex: "#000"),
              dayNumberColor: Color(red: 0.4, green: 0.4, blue: 0.4),
              otherMonthBackgroundColor: Color(hex: "#f0f8ff"),
              highlightColor: Color(hex: "#32cd32"),
              bubbleBackgroundColor: Color(hex: "#f0f8ff"),
              gridLinesColor: Color(hex: "#ffd700"),
              headerBackgroundColor: Color(hex: "#ffd700"),
              footerBackgroundColor: Color(hex: "#ff7f50"),
              iconColor: Color(hex: "#000"),
              iconActiveColor: Color(hex: "#1e90ff"),
              parentOneColor: Color(hex: "#96CBFC"),
              parentTwoColor: Color(hex: "#FFC2D9")),
        Theme(name: "Princess",
              font: .system(size: 24, weight: .bold, design: .default),
              mainBackgroundColor: Color(hex: "#fffafb"),
              secondaryBackgroundColor: Color(red: 0.94, green: 0.97, blue: 0.94),
              textColor: Color(hex: "#5e3c58"),
              dayNumberColor: Color(red: 0.3, green: 0.5, blue: 0.4),
              otherMonthBackgroundColor: Color(hex: "#fdf4f5"),
              highlightColor: Color(hex: "#ffd700"),
              bubbleBackgroundColor: Color(hex: "#fdf4f5"),
              gridLinesColor: Color(hex: "#fae3f5"),
              headerBackgroundColor: Color(hex: "#fae3f5"),
              footerBackgroundColor: Color(hex: "#fae3f5"),
              iconColor: Color(hex: "#c789a8"),
              iconActiveColor: Color(hex: "#e6a4b4"),
              parentOneColor: Color(hex: "#96CBFC"),
              parentTwoColor: Color(hex: "#FFC2D9")),
        Theme(name: "Vanilla",
              font: .system(size: 24, weight: .bold, design: .default),
              mainBackgroundColor: Color(hex: "#FFFFFF"),
              secondaryBackgroundColor: Color(red: 0.98, green: 0.98, blue: 0.98),
              textColor: Color(hex: "#000000"),
              dayNumberColor: Color(red: 0.4, green: 0.4, blue: 0.4),
              otherMonthBackgroundColor: Color(hex: "#F2F2F7"),
              highlightColor: Color(hex: "#007AFF"),
              bubbleBackgroundColor: Color(hex: "#F2F2F7"),
              gridLinesColor: Color(hex: "#E5E5EA"),
              headerBackgroundColor: Color(hex: "#E5E5EA"),
              footerBackgroundColor: Color(hex: "#E5E5EA"),
              iconColor: Color(hex: "#000000"),
              iconActiveColor: Color(hex: "#007AFF"),
              parentOneColor: Color(hex: "#96CBFC"),
              parentTwoColor: Color(hex: "#FFC2D9")),
    ]

    init() {
        let storedThemeName = UserDefaults.standard.string(forKey: "selectedTheme") ?? "Stork"
        self.currentTheme = themes.first { $0.name == storedThemeName } ?? themes[0]
    }

    func setTheme(to theme: Theme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.name, forKey: "selectedTheme")
    }
}

// Helper to allow Color initialization from a hex string
extension Color {
    var isLight: Bool {
        guard let components = cgColor?.components, components.count >= 3 else {
            return false
        }
        let brightness = ((components[0] * 299) + (components[1] * 587) + (components[2] * 114)) / 1000
        return brightness > 0.5
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
} 
