import SwiftUI
import Combine

struct Theme: Identifiable, Equatable, Hashable, Codable {
    var id: UUID
    var name: String
    var mainBackgroundColor: CodableColor
    var secondaryBackgroundColor: CodableColor
    var textColor: CodableColor
    var headerTextColor: CodableColor
    var iconColor: CodableColor
    var iconActiveColor: CodableColor
    var accentColor: CodableColor
    var parentOneColor: CodableColor
    var parentTwoColor: CodableColor

    // Computed properties for SwiftUI Colors
    var mainBackgroundColorSwiftUI: Color { mainBackgroundColor.color }
    var secondaryBackgroundColorSwiftUI: Color { secondaryBackgroundColor.color }
    var textColorSwiftUI: Color { textColor.color }
    var headerTextColorSwiftUI: Color { headerTextColor.color }
    var iconColorSwiftUI: Color { iconColor.color }
    var iconActiveColorSwiftUI: Color { iconActiveColor.color }
    var accentColorSwiftUI: Color { accentColor.color }
    var parentOneColorSwiftUI: Color { parentOneColor.color }
    var parentTwoColorSwiftUI: Color { parentTwoColor.color }

    var allColors: [Color] {
        [
            mainBackgroundColorSwiftUI,
            secondaryBackgroundColorSwiftUI,
            textColorSwiftUI,
            headerTextColorSwiftUI,
            iconColorSwiftUI,
            iconActiveColorSwiftUI,
            accentColorSwiftUI,
            parentOneColorSwiftUI,
            parentTwoColorSwiftUI
        ]
    }

    static func == (lhs: Theme, rhs: Theme) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static let defaultTheme = Theme(
        id: UUID(),
        name: "Default",
        mainBackgroundColor: CodableColor(color: Color(hex: "#FFFFFF")),
        secondaryBackgroundColor: CodableColor(color: Color(hex: "#F2F2F7")),
        textColor: CodableColor(color: Color(hex: "#000000")),
        headerTextColor: CodableColor(color: Color(hex: "#000000")),
        iconColor: CodableColor(color: Color(hex: "#000000")),
        iconActiveColor: CodableColor(color: Color(hex: "#007AFF")),
        accentColor: CodableColor(color: Color(hex: "#007AFF")),
        parentOneColor: CodableColor(color: Color(hex: "#96CBFC")),
        parentTwoColor: CodableColor(color: Color(hex: "#FFC2D9"))
    )
}

struct CodableColor: Codable, Equatable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    init(color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.opacity = Double(a)
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

class ThemeManager: ObservableObject {
    @Published var currentTheme: Theme
    @Published var themes: [Theme]
    
    private let customThemesKey = "customThemes"

    init() {
        // Initialize properties first
        self.themes = []
        self.currentTheme = Theme.defaultTheme
        
        // Now load the themes
        self.themes = loadThemes()
        
        // Set the current theme based on user defaults
        let storedThemeName = UserDefaults.standard.string(forKey: "selectedTheme") ?? "Stork"
        self.currentTheme = themes.first { $0.name == storedThemeName } ?? Theme.defaultTheme
    }

    func setTheme(to theme: Theme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.name, forKey: "selectedTheme")
    }

    func addTheme(_ theme: Theme) {
        themes.append(theme)
        saveThemes()
    }

    func updateTheme(_ theme: Theme) {
        if let index = themes.firstIndex(where: { $0.id == theme.id }) {
            themes[index] = theme
            saveThemes()
        }
    }

    private func loadThemes() -> [Theme] {
        var loadedThemes = defaultThemes
        if let data = UserDefaults.standard.data(forKey: customThemesKey) {
            do {
                let customThemes = try JSONDecoder().decode([Theme].self, from: data)
                loadedThemes.append(contentsOf: customThemes)
            } catch {
                print("Failed to load custom themes: \(error)")
            }
        }
        return loadedThemes
    }

    private func saveThemes() {
        let customThemes = themes.filter { theme in !defaultThemes.contains(where: { $0.id == theme.id }) }
        do {
            let data = try JSONEncoder().encode(customThemes)
            UserDefaults.standard.set(data, forKey: customThemesKey)
        } catch {
            print("Failed to save custom themes: \(error)")
        }
    }
    
    private var defaultThemes: [Theme] {
        return [
            Theme(
                id: UUID(),
                name: "Stork",
                mainBackgroundColor: CodableColor(color: Color(hex: "#FFFFFF")),
                secondaryBackgroundColor: CodableColor(color: Color(hex: "#F2F2F7")),
                textColor: CodableColor(color: Color(hex: "#000000")),
                headerTextColor: CodableColor(color: Color(hex: "#000000")),
                iconColor: CodableColor(color: Color(hex: "#000000")),
                iconActiveColor: CodableColor(color: Color(hex: "#007AFF")),
                accentColor: CodableColor(color: Color(hex: "#007AFF")),
                parentOneColor: CodableColor(color: Color(hex: "#96CBFC")),
                parentTwoColor: CodableColor(color: Color(hex: "#FFC2D9"))
            ),
            Theme(
                id: UUID(),
                name: "Dracula",
                mainBackgroundColor: CodableColor(color: Color(hex: "#282a36")),
                secondaryBackgroundColor: CodableColor(color: Color(hex: "#21222c")),
                textColor: CodableColor(color: Color(hex: "#f8f8f2")),
                headerTextColor: CodableColor(color: Color(hex: "#f8f8f2")),
                iconColor: CodableColor(color: Color(hex: "#bd93f9")),
                iconActiveColor: CodableColor(color: Color(hex: "#ff79c6")),
                accentColor: CodableColor(color: Color(hex: "#ff79c6")),
                parentOneColor: CodableColor(color: Color(hex: "#96CBFC")),
                parentTwoColor: CodableColor(color: Color(hex: "#FFC2D9"))
            )
        ]
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
