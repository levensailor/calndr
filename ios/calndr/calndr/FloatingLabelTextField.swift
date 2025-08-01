import SwiftUI

struct FloatingLabelTextField: View {
    let title: String
    @Binding var text: String
    let isSecure: Bool
    @EnvironmentObject var themeManager: ThemeManager
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .leading) {
                // Background and border
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? themeManager.currentTheme.secondaryBackgroundColorSwiftUI : Color(white: 0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isFocused ? Color.blue : themeManager.currentTheme.textColorSwiftUI.opacity(0.3), lineWidth: isFocused ? 2 : 1)
                    )
                
                VStack(alignment: .leading, spacing: 0) {
                    // Label - Always visible
                    HStack {
                        Text(title)
                            .font(.caption)
                            .foregroundColor(isFocused ? Color.blue : themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
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
                    .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    .padding(.bottom, 16)
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
} 
