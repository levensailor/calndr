import SwiftUI
import Combine

struct Theme: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let fontName: String
    let todayBorderColor: Color
    let otherMonthBackgroundColor: Color
    let otherMonthForegroundColor: Color
    let mainBackgroundColor: Color
    let textColor: Color
    let gridLinesColor: Color
    let headerBackgroundColor: Color
    let footerBackgroundColor: Color
    let iconColor: Color
    let iconActiveColor: Color
    let parentOneColor: Color
    let parentTwoColor: Color
    
    var allColors: [Color] {
        [
            todayBorderColor,
            otherMonthBackgroundColor,
            otherMonthForegroundColor,
            mainBackgroundColor,
            textColor,
            gridLinesColor,
            headerBackgroundColor,
            footerBackgroundColor,
            iconColor,
            iconActiveColor,
            parentOneColor,
            parentTwoColor
        ]
    }

    var dayNumberColor: Color {
        return mainBackgroundColor.isLight ? .black : .white
    }

    var bubbleBackgroundColor: Color {
        return mainBackgroundColor.isLight ? Color.black.opacity(0.1) : Color.white.opacity(0.2)
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
              fontName: "-apple-system",
              todayBorderColor: Color(hex: "#2a64c4"),
              otherMonthBackgroundColor: Color(hex: "#f7f7f7"),
              otherMonthForegroundColor: Color(hex: "#aaa"),
              mainBackgroundColor: Color(hex: "#fff"),
              textColor: Color(hex: "#000"),
              gridLinesColor: Color(hex: "#e0e0e0"),
              headerBackgroundColor: Color(hex: "#e0e0e0"),
              footerBackgroundColor: Color(hex: "#f0f0f0"),
              iconColor: Color(hex: "#555"),
              iconActiveColor: Color(hex: "#007bff"),
              parentOneColor: Color(hex: "#FFC2D9"),
              parentTwoColor: Color(hex: "#96CBFC")),
        Theme(name: "Dracula",
              fontName: "Menlo-Regular",
              todayBorderColor: Color(hex: "#ff79c6"),
              otherMonthBackgroundColor: Color(hex: "#21222c"),
              otherMonthForegroundColor: Color(hex: "#6272a4"),
              mainBackgroundColor: Color(hex: "#282a36"),
              textColor: Color(hex: "#f8f8f2"),
              gridLinesColor: Color(hex: "#191a21"),
              headerBackgroundColor: Color(hex: "#191a21"),
              footerBackgroundColor: Color(hex: "#191a21"),
              iconColor: Color(hex: "#bd93f9"),
              iconActiveColor: Color(hex: "#ff79c6"),
              parentOneColor: Color(hex: "#FFC2D9"),
              parentTwoColor: Color(hex: "#96CBFC")),
        Theme(name: "Vibe",
              fontName: "Futura-Medium",
              todayBorderColor: Color(hex: "#00fddc"),
              otherMonthBackgroundColor: Color(hex: "#1a103c"),
              otherMonthForegroundColor: Color(hex: "#5d4a9c"),
              mainBackgroundColor: Color(hex: "#251758"),
              textColor: Color(hex: "#e0d8ff"),
              gridLinesColor: Color(hex: "#12092a"),
              headerBackgroundColor: Color(hex: "#12092a"),
              footerBackgroundColor: Color(hex: "#12092a"),
              iconColor: Color(hex: "#b3a5ef"),
              iconActiveColor: Color(hex: "#00fddc"),
              parentOneColor: Color(hex: "#FFC2D9"),
              parentTwoColor: Color(hex: "#96CBFC")),
        Theme(name: "Crayola",
              fontName: "ChalkboardSE-Regular",
              todayBorderColor: Color(hex: "#32cd32"),
              otherMonthBackgroundColor: Color(hex: "#f0f8ff"),
              otherMonthForegroundColor: Color(hex: "#d3d3d3"),
              mainBackgroundColor: Color(hex: "#fff"),
              textColor: Color(hex: "#000"),
              gridLinesColor: Color(hex: "#ffd700"),
              headerBackgroundColor: Color(hex: "#ffd700"),
              footerBackgroundColor: Color(hex: "#ff7f50"),
              iconColor: Color(hex: "#000"),
              iconActiveColor: Color(hex: "#1e90ff"),
              parentOneColor: Color(hex: "#FFC2D9"),
              parentTwoColor: Color(hex: "#96CBFC")),
        Theme(name: "Princess",
              fontName: "SnellRoundhand",
              todayBorderColor: Color(hex: "#ffd700"),
              otherMonthBackgroundColor: Color(hex: "#fdf4f5"),
              otherMonthForegroundColor: Color(hex: "#d8bfd8"),
              mainBackgroundColor: Color(hex: "#fffafb"),
              textColor: Color(hex: "#5e3c58"),
              gridLinesColor: Color(hex: "#fae3f5"),
              headerBackgroundColor: Color(hex: "#fae3f5"),
              footerBackgroundColor: Color(hex: "#fae3f5"),
              iconColor: Color(hex: "#c789a8"),
              iconActiveColor: Color(hex: "#e6a4b4"),
              parentOneColor: Color(hex: "#FFC2D9"),
              parentTwoColor: Color(hex: "#96CBFC")),
        Theme(name: "Vanilla",
              fontName: "-apple-system",
              todayBorderColor: Color(hex: "#007AFF"),
              otherMonthBackgroundColor: Color(hex: "#F2F2F7"),
              otherMonthForegroundColor: Color(hex: "#8E8E93"),
              mainBackgroundColor: Color(hex: "#FFFFFF"),
              textColor: Color(hex: "#000000"),
              gridLinesColor: Color(hex: "#E5E5EA"),
              headerBackgroundColor: Color(hex: "#E5E5EA"),
              footerBackgroundColor: Color(hex: "#E5E5EA"),
              iconColor: Color(hex: "#000000"),
              iconActiveColor: Color(hex: "#007AFF"),
              parentOneColor: Color(hex: "#FFC2D9"),
              parentTwoColor: Color(hex: "#96CBFC")),
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
