import SwiftUI

struct ThemePreviewView: View {
    let theme: Theme
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingDeleteAlert = false
    
    // Callbacks for edit and delete actions
    let onEdit: (Theme) -> Void
    let onDelete: (Theme) -> Void

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
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .background(
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 24, height: 24)
                                    )
                                    .padding(8)
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                }

                // Theme name with edit/delete buttons
                HStack {
                    Text(theme.name)
                        .font(.system(size: 12, weight: .bold, design: .default))
                        .foregroundColor(themeManager.currentTheme.smartTextColor(for: themeManager.currentTheme.secondaryBackgroundColor))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Edit and delete buttons (only for non-public themes)
                    if theme.isPublic != true {
                        HStack(spacing: 4) {
                            // Edit button
                            Button(action: {
                                onEdit(theme)
                            }) {
                                Image(systemName: "pencil")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.orange)
                                    .clipShape(Circle())
                            }
                            
                            // Delete button
                            Button(action: {
                                showingDeleteAlert = true
                            }) {
                                Image(systemName: "trash")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.red)
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
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
        .alert("Delete Theme", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete(theme)
            }
        } message: {
            Text("Are you sure you want to delete '\(theme.name)'? This action cannot be undone.")
        }
        .animateThemeChanges(themeManager)
    }
    
    private var isCurrentTheme: Bool {
        theme.id == themeManager.currentTheme.id
    }
} 
