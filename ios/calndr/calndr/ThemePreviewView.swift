import SwiftUI

struct ThemePreviewView: View {
    let theme: Theme
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingActionButtons = false

    var body: some View {
        Button(action: {
            themeManager.setTheme(to: theme)
        }) {
            VStack(spacing: 0) {
                ZStack {
                    // Color palette preview
                    HStack(spacing: 0) {
                        ForEach(theme.allColors.indices, id: \.self) { index in
                            theme.allColors[index]
                        }
                    }
                    .frame(height: 60)
                    
                    // Current theme indicator
                    if isCurrentTheme {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .background(
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 24, height: 24)
                                    )
                                    .padding(8)
                            }
                            Spacer()
                        }
                    }
                    
                    // Action buttons overlay (shown on long press)
                    if showingActionButtons {
                        VStack {
                            Spacer()
                            HStack(spacing: 8) {
                                // Apply button
                                Button(action: {
                                    themeManager.setTheme(to: theme)
                                    showingActionButtons = false
                                }) {
                                    Image(systemName: "paintbrush.fill")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                }
                                
                                // Edit button (if not a public theme)
                                if theme.isPublic != true {
                                    Button(action: {
                                        // Handle edit action here
                                        showingActionButtons = false
                                    }) {
                                        Image(systemName: "pencil")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(6)
                                            .background(Color.orange)
                                            .clipShape(Circle())
                                    }
                                }
                            }
                            .padding(8)
                        }
                        .background(
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .opacity(0.8)
                        )
                        .transition(.opacity)
                    }
                }

                Text(theme.name)
                    .font(.system(size: 12, weight: .bold, design: .default))
                    .foregroundColor(themeManager.currentTheme.smartTextColor(for: themeManager.currentTheme.secondaryBackgroundColor))
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                
            }
        }
        .buttonStyle(PlainButtonStyle())
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isCurrentTheme ? theme.accentColorSwiftUI : themeManager.currentTheme.textColorSwiftUI.opacity(0.2), lineWidth: isCurrentTheme ? 3 : 1)
        )
        .scaleEffect(isCurrentTheme ? 1.05 : 1.0)
        .shadow(color: isCurrentTheme ? theme.accentColorSwiftUI.opacity(0.3) : Color.clear, radius: isCurrentTheme ? 8 : 0)
        .animation(.easeInOut(duration: 0.2), value: isCurrentTheme)
        .animation(.easeInOut(duration: 0.2), value: showingActionButtons)
        .contextMenu {
            Button(action: {
                themeManager.setTheme(to: theme)
            }) {
                Label("Apply Theme", systemImage: "paintbrush.fill")
            }
            
            if theme.isPublic != true {
                Button(action: {
                    // Handle edit action
                }) {
                    Label("Edit Theme", systemImage: "pencil")
                }
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingActionButtons.toggle()
            }
        }
        .onTapGesture {
            if showingActionButtons {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingActionButtons = false
                }
            } else {
                themeManager.setTheme(to: theme)
            }
        }
        .animateThemeChanges(themeManager)
    }
    
    private var isCurrentTheme: Bool {
        theme.id == themeManager.currentTheme.id
    }
} 
