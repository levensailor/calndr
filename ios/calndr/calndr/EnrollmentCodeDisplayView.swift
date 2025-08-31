import SwiftUI

struct EnrollmentCodeDisplayView: View {
    let code: String
    @EnvironmentObject var themeManager: ThemeManager
    
    // Animation properties
    @State private var isAnimating = false
    @State private var animationOffset: CGFloat = 20
    @State private var opacity = 0.0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Your Enrollment Code")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
            
            Text("Share this code with your co-parent")
                .font(.body)
                .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Animated code display
            HStack(spacing: 8) {
                ForEach(0..<code.count, id: \.self) { index in
                    let character = String(Array(code)[index])
                    
                    ZStack {
                        // Background shape
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        themeManager.currentTheme.accentColorSwiftUI.opacity(0.7),
                                        themeManager.currentTheme.accentColorSwiftUI
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 45, height: 60)
                            .shadow(color: themeManager.currentTheme.accentColorSwiftUI.opacity(0.3), radius: 5, x: 0, y: 3)
                        
                        // Character
                        Text(character)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
                    }
                    .offset(y: isAnimating ? 0 : animationOffset)
                    .opacity(opacity)
                    .animation(
                        Animation.spring(response: 0.6, dampingFraction: 0.6)
                            .delay(Double(index) * 0.1),
                        value: isAnimating
                    )
                }
            }
            .padding(.vertical, 20)
            
            // Glow effect behind the code
            .background(
                Circle()
                    .fill(themeManager.currentTheme.accentColorSwiftUI.opacity(0.15))
                    .frame(width: 280, height: 280)
                    .blur(radius: 20)
                    .scaleEffect(isAnimating ? 1.1 : 0.9)
                    .animation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
            )
            
            // Copy button
            Button(action: {
                UIPasteboard.general.string = code
                // Add haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }) {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("Copy Code")
                }
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.accentColorSwiftUI)
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(themeManager.currentTheme.accentColorSwiftUI, lineWidth: 2)
                )
            }
            .padding(.top, 20)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding()
        .onAppear {
            // Start animations when view appears
            withAnimation {
                opacity = 1.0
                isAnimating = true
            }
        }
    }
}

// Preview provider for SwiftUI canvas
struct EnrollmentCodeDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        EnrollmentCodeDisplayView(code: "ABC123")
            .environmentObject(ThemeManager())
    }
}
