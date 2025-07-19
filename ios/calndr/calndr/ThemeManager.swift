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
    var isPublic: Bool?
    var createdByUserId: UUID?
    var createdAt: Date?
    var updatedAt: Date?

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
    
    // Smart contrast text colors - automatically choose black/white based on background
    var smartTextColor: Color {
        mainBackgroundColor.color.isLight ? Color.black : textColor.color
    }
    
    var smartHeaderTextColor: Color {
        mainBackgroundColor.color.isLight ? Color.black : headerTextColor.color
    }
    
    // Smart text color for specific backgrounds
    func smartTextColor(for backgroundColor: Color) -> Color {
        backgroundColor.isLight ? Color.black : Color.white
    }
    
    func smartTextColor(for backgroundColor: CodableColor) -> Color {
        backgroundColor.color.isLight ? Color.black : Color.white
    }
    
    // Enhanced contrast detection for parent colors
    var parentOneTextColor: Color {
        parentOneColor.color.isLight ? Color.black : Color.white
    }
    
    var parentTwoTextColor: Color {
        parentTwoColor.color.isLight ? Color.black : Color.white
    }
    
    // Smart accent colors with good contrast
    var smartAccentColor: Color {
        mainBackgroundColor.color.isLight ? accentColor.color : accentColor.color
    }
    
    // Automatic color scheme detection for system UI elements
    var preferredColorScheme: ColorScheme {
        mainBackgroundColor.color.isLight ? .light : .dark
    }
    
    // Check if this is a dark theme
    var isDarkTheme: Bool {
        !mainBackgroundColor.color.isLight
    }
    
    // Check if this is a light theme  
    var isLightTheme: Bool {
        mainBackgroundColor.color.isLight
    }

    // Custom CodingKeys to handle snake_case from backend
    enum CodingKeys: String, CodingKey {
        case id, name, isPublic, mainBackgroundColor, secondaryBackgroundColor
        case textColor, headerTextColor, iconColor, iconActiveColor, accentColor
        case parentOneColor, parentTwoColor
        case createdByUserId = "created_by_user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Custom date formatters for backend date strings (handle different microsecond precisions)
    private static let dateFormatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd HH:mm:ss.SSSSSS",  // 6 digits microseconds
            "yyyy-MM-dd HH:mm:ss.SSSSS",   // 5 digits
            "yyyy-MM-dd HH:mm:ss.SSSS",    // 4 digits
            "yyyy-MM-dd HH:mm:ss.SSS",     // 3 digits
            "yyyy-MM-dd HH:mm:ss"          // No microseconds
        ]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.timeZone = TimeZone(abbreviation: "UTC")
            return formatter
        }
    }()
    
    private static func parseDate(from string: String) -> Date? {
        for formatter in dateFormatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
    
    // Custom decoding to handle date strings from backend
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        mainBackgroundColor = try container.decode(CodableColor.self, forKey: .mainBackgroundColor)
        secondaryBackgroundColor = try container.decode(CodableColor.self, forKey: .secondaryBackgroundColor)
        textColor = try container.decode(CodableColor.self, forKey: .textColor)
        headerTextColor = try container.decode(CodableColor.self, forKey: .headerTextColor)
        iconColor = try container.decode(CodableColor.self, forKey: .iconColor)
        iconActiveColor = try container.decode(CodableColor.self, forKey: .iconActiveColor)
        accentColor = try container.decode(CodableColor.self, forKey: .accentColor)
        parentOneColor = try container.decode(CodableColor.self, forKey: .parentOneColor)
        parentTwoColor = try container.decode(CodableColor.self, forKey: .parentTwoColor)
        isPublic = try container.decodeIfPresent(Bool.self, forKey: .isPublic)
        createdByUserId = try container.decodeIfPresent(UUID.self, forKey: .createdByUserId)
        
        // Custom date decoding
        if let createdAtString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            createdAt = Theme.parseDate(from: createdAtString)
        } else {
            createdAt = nil
        }
        
        if let updatedAtString = try container.decodeIfPresent(String.self, forKey: .updatedAt) {
            updatedAt = Theme.parseDate(from: updatedAtString)
        } else {
            updatedAt = nil
        }
    }
    
    // Memberwise initializer (required since we have custom init(from decoder:))
    init(id: UUID = UUID(), name: String, mainBackgroundColor: CodableColor, secondaryBackgroundColor: CodableColor, textColor: CodableColor, headerTextColor: CodableColor, iconColor: CodableColor, iconActiveColor: CodableColor, accentColor: CodableColor, parentOneColor: CodableColor, parentTwoColor: CodableColor, isPublic: Bool? = nil, createdByUserId: UUID? = nil, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.mainBackgroundColor = mainBackgroundColor
        self.secondaryBackgroundColor = secondaryBackgroundColor
        self.textColor = textColor
        self.headerTextColor = headerTextColor
        self.iconColor = iconColor
        self.iconActiveColor = iconActiveColor
        self.accentColor = accentColor
        self.parentOneColor = parentOneColor
        self.parentTwoColor = parentTwoColor
        self.isPublic = isPublic
        self.createdByUserId = createdByUserId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Custom encoding to handle date formatting for backend
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(mainBackgroundColor, forKey: .mainBackgroundColor)
        try container.encode(secondaryBackgroundColor, forKey: .secondaryBackgroundColor)
        try container.encode(textColor, forKey: .textColor)
        try container.encode(headerTextColor, forKey: .headerTextColor)
        try container.encode(iconColor, forKey: .iconColor)
        try container.encode(iconActiveColor, forKey: .iconActiveColor)
        try container.encode(accentColor, forKey: .accentColor)
        try container.encode(parentOneColor, forKey: .parentOneColor)
        try container.encode(parentTwoColor, forKey: .parentTwoColor)
        try container.encodeIfPresent(isPublic, forKey: .isPublic)
        try container.encodeIfPresent(createdByUserId, forKey: .createdByUserId)
        
        // Custom date encoding (use first formatter with full precision)
        if let createdAt = createdAt {
            try container.encode(Theme.dateFormatters[0].string(from: createdAt), forKey: .createdAt)
        }
        
        if let updatedAt = updatedAt {
            try container.encode(Theme.dateFormatters[0].string(from: updatedAt), forKey: .updatedAt)
        }
    }

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
    
    // Convenience initializer for hex strings
    init(hex: String) {
        let color = Color(hex: hex)
        self.init(color: color)
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
    
    // Custom decoding to handle both hex strings and object format
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let hexString = try? container.decode(String.self) {
            // Backend sent a hex string - convert to RGBA
            let color = Color(hex: hexString)
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
        } else {
            // Decode as object with red/green/blue/opacity properties
            let keyedContainer = try decoder.container(keyedBy: CodingKeys.self)
            self.red = try keyedContainer.decode(Double.self, forKey: .red)
            self.green = try keyedContainer.decode(Double.self, forKey: .green)
            self.blue = try keyedContainer.decode(Double.self, forKey: .blue)
            self.opacity = try keyedContainer.decode(Double.self, forKey: .opacity)
        }
    }
    
    // Encode as hex string for sending to backend
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.hexString)
    }
    
    // Convert to hex string representation
    var hexString: String {
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    // Smart contrast text color for this background
    var contrastTextColor: Color {
        self.color.isLight ? Color.black : Color.white
    }
    
    // Check if this color is light
    var isLight: Bool {
        return self.color.isLight
    }
    
    enum CodingKeys: String, CodingKey {
        case red, green, blue, opacity
    }
}

class ThemeManager: ObservableObject {
    @Published var currentTheme: Theme
    @Published var themes: [Theme]
    @Published var isThemeChanging: Bool = false
    
    private let apiService = APIService.shared

    init() {
        self.themes = []
        self.currentTheme = Theme.defaultTheme
        loadThemes()
    }

    func loadThemes(completion: @escaping () -> Void = {}) {
        apiService.fetchThemes { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let themes):
                    print("🎨 ThemeManager: Loaded \(themes.count) themes")
                    self?.themes = themes
                    completion() // Notify that themes are loaded
                case .failure(let error):
                    print("❌ Failed to load themes: \(error)")
                    completion() // Still call completion even on failure
                }
            }
        }
    }

    func setTheme(to theme: Theme, animated: Bool = true) {
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                isThemeChanging = true
                currentTheme = theme
            }
            
            // Reset the changing flag after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isThemeChanging = false
            }
        } else {
            currentTheme = theme
        }
        
        // Save preference to backend
        apiService.setThemePreference(themeId: theme.id) { result in
            if case .failure(let error) = result {
                print("Failed to set theme preference: \(error)")
            }
        }
        
        print("🎨 ThemeManager: Theme changed to '\(theme.name)'")
        
        // Force a comprehensive UI refresh for calendar components
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // Force a UI refresh for all theme-dependent components
    func refreshTheme() {
        DispatchQueue.main.async {
            // Trigger a re-render by updating the published property
            self.objectWillChange.send()
        }
    }

    func addTheme(_ theme: Theme) {
        apiService.createTheme(theme) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let newTheme):
                    self?.themes.append(newTheme)
                case .failure(let error):
                    print("Failed to add theme: \(error)")
                }
            }
        }
    }

    func updateTheme(_ theme: Theme) {
        apiService.updateTheme(theme) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedTheme):
                    if let index = self?.themes.firstIndex(where: { $0.id == updatedTheme.id }) {
                        self?.themes[index] = updatedTheme
                    }
                case .failure(let error):
                    print("Failed to update theme: \(error)")
                }
            }
        }
    }
    
    func deleteTheme(_ theme: Theme) {
        apiService.deleteTheme(theme.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.themes.removeAll { $0.id == theme.id }
                case .failure(let error):
                    print("Failed to delete theme: \(error)")
                }
            }
        }
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

// MARK: - Theme View Modifiers

struct ThemedText: ViewModifier {
    let themeManager: ThemeManager
    let useSmartContrast: Bool
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(useSmartContrast ? themeManager.currentTheme.smartTextColor : themeManager.currentTheme.textColorSwiftUI)
    }
}

struct ThemedBackground: ViewModifier {
    let themeManager: ThemeManager
    let isSecondary: Bool
    
    func body(content: Content) -> some View {
        content
            .background(isSecondary ? themeManager.currentTheme.secondaryBackgroundColorSwiftUI : themeManager.currentTheme.mainBackgroundColorSwiftUI)
    }
}

struct ThemedButton: ViewModifier {
    let themeManager: ThemeManager
    let backgroundColor: Color?
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(backgroundColor != nil ? themeManager.currentTheme.smartTextColor(for: backgroundColor!) : .white)
    }
}

// MARK: - Convenient View Extensions

extension View {
    func themedText(_ themeManager: ThemeManager, smartContrast: Bool = false) -> some View {
        self.modifier(ThemedText(themeManager: themeManager, useSmartContrast: smartContrast))
    }
    
    func themedBackground(_ themeManager: ThemeManager, secondary: Bool = false) -> some View {
        self.modifier(ThemedBackground(themeManager: themeManager, isSecondary: secondary))
    }
    
    func themedButton(_ themeManager: ThemeManager, backgroundColor: Color? = nil) -> some View {
        self.modifier(ThemedButton(themeManager: themeManager, backgroundColor: backgroundColor))
    }
    
    // Animate theme changes
    func animateThemeChanges(_ themeManager: ThemeManager) -> some View {
        self.animation(.easeInOut(duration: 0.3), value: themeManager.currentTheme.id)
    }
    
    // Automatically apply preferred color scheme based on theme
    func themeColorScheme(_ themeManager: ThemeManager) -> some View {
        self.preferredColorScheme(themeManager.currentTheme.preferredColorScheme)
    }
    
    // Complete theme application - background, text, and color scheme
    func themedView(_ themeManager: ThemeManager, secondary: Bool = false) -> some View {
        self
            .background(secondary ? themeManager.currentTheme.secondaryBackgroundColorSwiftUI : themeManager.currentTheme.mainBackgroundColorSwiftUI)
            .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
            .preferredColorScheme(themeManager.currentTheme.preferredColorScheme)
            .animateThemeChanges(themeManager)
    }
} 
