import SwiftUI

struct FloatingLabelTextField: View {
    let title: String
    @Binding var text: String
    let isSecure: Bool
    let themeManager: ThemeManager
    @FocusState private var isFocused: Bool
    
    private var shouldPlaceHolderMove: Bool {
        isFocused || !text.isEmpty
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            Text(title)
                .foregroundColor(shouldPlaceHolderMove ? themeManager.currentTheme.textColor : themeManager.currentTheme.textColor.opacity(0.6))
                .offset(y: shouldPlaceHolderMove ? -25 : 0)
                .scaleEffect(shouldPlaceHolderMove ? 0.8 : 1.0, anchor: .leading)
                .animation(.easeInOut(duration: 0.2), value: shouldPlaceHolderMove)
            
            Group {
                if isSecure {
                    SecureField("", text: $text)
                        .focused($isFocused)
                } else {
                    TextField("", text: $text)
                        .focused($isFocused)
                }
            }
            .padding(.top, 15) // Fixed padding to maintain consistent height
        }
        .frame(height: 56) // Fixed height to prevent resizing
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? themeManager.currentTheme.textColor : themeManager.currentTheme.textColor.opacity(0.3), lineWidth: isFocused ? 2 : 1)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeManager.currentTheme.otherMonthBackgroundColor)
                )
        )
        .foregroundColor(themeManager.currentTheme.textColor)
    }
} 
