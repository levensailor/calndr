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
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .leading) {
                // Background and border
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeManager.currentTheme.otherMonthBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isFocused ? themeManager.currentTheme.textColor : themeManager.currentTheme.textColor.opacity(0.3), lineWidth: isFocused ? 2 : 1)
                    )
                
                VStack(alignment: .leading, spacing: 0) {
                    // Label
                    if shouldPlaceHolderMove {
                        Text(title)
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor)
                            .padding(.top, 8)
                            .padding(.horizontal, 16)
                            .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
                    }
                    
                    // Text field
                    Group {
                        if isSecure {
                            SecureField(shouldPlaceHolderMove ? "" : title, text: $text)
                                .focused($isFocused)
                        } else {
                            TextField(shouldPlaceHolderMove ? "" : title, text: $text)
                                .focused($isFocused)
                        }
                    }
                    .foregroundColor(themeManager.currentTheme.textColor)
                    .padding(.horizontal, 16)
                    .padding(.top, shouldPlaceHolderMove ? 2 : 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: shouldPlaceHolderMove)
    }
} 
