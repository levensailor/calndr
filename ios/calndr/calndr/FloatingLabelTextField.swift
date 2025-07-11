import SwiftUI

struct FloatingLabelTextField: View {
    let title: String
    @Binding var text: String
    let isSecure: Bool
    let themeManager: ThemeManager
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .leading) {
                // Background and border
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeManager.currentTheme.otherMonthBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isFocused ? Color.blue : themeManager.currentTheme.textColor.opacity(0.3), lineWidth: isFocused ? 2 : 1)
                    )
                
                VStack(alignment: .leading, spacing: 0) {
                    // Label - Always visible
                    HStack {
                        Text(title)
                            .font(.caption)
                            .foregroundColor(isFocused ? Color.blue : Color.primary)
                        Spacer()
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                    
                    // Text field
                    Group {
                        if isSecure {
                            SecureField("", text: $text)
                                .focused($isFocused)
                        } else {
                            TextField("", text: $text)
                                .focused($isFocused)
                        }
                    }
                    .foregroundColor(themeManager.currentTheme.textColor)
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    .padding(.bottom, 16)
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
} 
