import SwiftUI

// MARK: - Brutalist Theme Definitions
extension Theme {
    static var brutalistDark: Theme {
        Theme(
            id: UUID(),
            name: "Brutalist Dark",
            mainBackgroundColor: CodableColor(color: Color.black),
            secondaryBackgroundColor: CodableColor(color: Color(red: 0.1, green: 0.1, blue: 0.1)),
            textColor: CodableColor(color: Color.white),
            headerTextColor: CodableColor(color: Color.white),
            iconColor: CodableColor(color: Color(red: 0.8, green: 0.8, blue: 0.8)),
            iconActiveColor: CodableColor(color: Color.white),
            accentColor: CodableColor(color: Color(red: 1.0, green: 0.0, blue: 0.3)), // Hot pink accent
            parentOneColor: CodableColor(color: Color(red: 1.0, green: 1.0, blue: 0.0)), // Bright yellow
            parentTwoColor: CodableColor(color: Color(red: 0.0, green: 1.0, blue: 1.0)), // Bright cyan
            isPublic: true
        )
    }
    
    static var brutalistLight: Theme {
        Theme(
            id: UUID(),
            name: "Brutalist Light",
            mainBackgroundColor: CodableColor(color: Color.white),
            secondaryBackgroundColor: CodableColor(color: Color(red: 0.95, green: 0.95, blue: 0.95)),
            textColor: CodableColor(color: Color.black),
            headerTextColor: CodableColor(color: Color.black),
            iconColor: CodableColor(color: Color(red: 0.2, green: 0.2, blue: 0.2)),
            iconActiveColor: CodableColor(color: Color.black),
            accentColor: CodableColor(color: Color(red: 1.0, green: 0.0, blue: 0.3)), // Hot pink accent
            parentOneColor: CodableColor(color: Color(red: 1.0, green: 0.8, blue: 0.0)), // Golden yellow
            parentTwoColor: CodableColor(color: Color(red: 0.0, green: 0.8, blue: 1.0)), // Bright blue
            isPublic: true
        )
    }
    
    static var brutalistContrast: Theme {
        Theme(
            id: UUID(),
            name: "Brutalist Contrast",
            mainBackgroundColor: CodableColor(color: Color.black),
            secondaryBackgroundColor: CodableColor(color: Color.white),
            textColor: CodableColor(color: Color.white),
            headerTextColor: CodableColor(color: Color.white),
            iconColor: CodableColor(color: Color.white),
            iconActiveColor: CodableColor(color: Color.black),
            accentColor: CodableColor(color: Color.white),
            parentOneColor: CodableColor(color: Color.white),
            parentTwoColor: CodableColor(color: Color(red: 1.0, green: 0.0, blue: 0.0)), // Pure red
            isPublic: true
        )
    }
}

// MARK: - Brutalist UI Components

struct BrutalistButton: View {
    let title: String
    let action: () -> Void
    let style: BrutalistButtonStyle
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isPressed = false
    
    enum BrutalistButtonStyle {
        case primary
        case secondary
        case destructive
    }
    
    var buttonColor: Color {
        switch style {
        case .primary:
            return themeManager.currentTheme.accentColorSwiftUI
        case .secondary:
            return themeManager.currentTheme.secondaryBackgroundColorSwiftUI
        case .destructive:
            return Color.red
        }
    }
    
    var textColor: Color {
        switch style {
        case .primary:
            return themeManager.currentTheme.smartTextColor(for: buttonColor)
        case .secondary:
            return themeManager.currentTheme.textColorSwiftUI
        case .destructive:
            return Color.white
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .black, design: .default))
                .textCase(.uppercase)
                .letterSpacing(1.5)
                .foregroundColor(textColor)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(buttonColor)
                .overlay(
                    Rectangle()
                        .stroke(themeManager.currentTheme.textColorSwiftUI, lineWidth: 3)
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
}

struct BrutalistCard: View {
    let content: () -> any View
    @EnvironmentObject var themeManager: ThemeManager
    
    init(@ViewBuilder content: @escaping () -> any View) {
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AnyView(content())
        }
        .padding(16)
        .background(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
        .overlay(
            Rectangle()
                .stroke(themeManager.currentTheme.textColorSwiftUI, lineWidth: 2)
        )
    }
}

struct BrutalistTextField: View {
    let title: String
    @Binding var text: String
    let isSecure: Bool
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isFocused = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .default))
                .textCase(.uppercase)
                .letterSpacing(1.2)
                .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
            
            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .font(.system(size: 16, weight: .bold, design: .monospaced))
            .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
            .padding(12)
            .background(themeManager.currentTheme.mainBackgroundColorSwiftUI)
            .overlay(
                Rectangle()
                    .stroke(
                        isFocused ? themeManager.currentTheme.accentColorSwiftUI : themeManager.currentTheme.textColorSwiftUI,
                        lineWidth: isFocused ? 3 : 2
                    )
            )
            .onTapGesture {
                isFocused = true
            }
        }
    }
}

struct BrutalistHeader: View {
    let title: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Text(title)
            .font(.system(size: 32, weight: .black, design: .default))
            .textCase(.uppercase)
            .letterSpacing(2.0)
            .foregroundColor(themeManager.currentTheme.headerTextColorSwiftUI)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Rectangle()
                    .fill(themeManager.currentTheme.accentColorSwiftUI)
                    .frame(height: 4)
                    .offset(y: 20)
            )
    }
}

struct BrutalistDayCell: View {
    let date: Date
    let events: [Event]
    let custodyOwner: String
    let custodyID: String
    let isToday: Bool
    let isCurrentMonth: Bool
    @EnvironmentObject var themeManager: ThemeManager
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Day number with brutal styling
            Text(dayNumber)
                .font(.system(size: 16, weight: .black, design: .default))
                .foregroundColor(isToday ? themeManager.currentTheme.accentColorSwiftUI : themeManager.currentTheme.textColorSwiftUI)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.top, 4)
                .padding(.leading, 4)
            
            Spacer()
            
            // Events with sharp rectangular styling
            VStack(spacing: 1) {
                ForEach(events.prefix(3)) { event in
                    Rectangle()
                        .fill(themeManager.currentTheme.accentColorSwiftUI)
                        .frame(height: 8)
                        .overlay(
                            Text("■")
                                .font(.system(size: 6, weight: .black))
                                .foregroundColor(themeManager.currentTheme.smartTextColor(for: themeManager.currentTheme.accentColorSwiftUI))
                        )
                }
            }
            .padding(.horizontal, 2)
            
            Spacer()
            
            // Custody bar with sharp edges
            if !custodyOwner.isEmpty {
                Rectangle()
                    .fill(custodyID == "parent1" ? themeManager.currentTheme.parentOneColorSwiftUI : themeManager.currentTheme.parentTwoColorSwiftUI)
                    .frame(height: 16)
                    .overlay(
                        Text(String(custodyOwner.prefix(1)).uppercased())
                            .font(.system(size: 10, weight: .black, design: .default))
                            .foregroundColor(.black)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isCurrentMonth ? themeManager.currentTheme.mainBackgroundColorSwiftUI : themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
        .overlay(
            Rectangle()
                .stroke(
                    isToday ? themeManager.currentTheme.accentColorSwiftUI : themeManager.currentTheme.textColorSwiftUI.opacity(0.3),
                    lineWidth: isToday ? 3 : 1
                )
        )
    }
}

// MARK: - Brutalist Gestures
struct OnPressGesture: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}

extension View {
    func onPressGesture(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(OnPressGesture(onPress: onPress, onRelease: onRelease))
    }
}

// MARK: - Brutalist Theme Extension
extension ThemeManager {
    func addBrutalistThemes() {
        let brutalistThemes = [
            Theme.brutalistDark,
            Theme.brutalistLight,
            Theme.brutalistContrast
        ]
        
        for theme in brutalistThemes {
            if !themes.contains(where: { $0.name == theme.name }) {
                themes.append(theme)
            }
        }
    }
} 