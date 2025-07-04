import SwiftUI

struct SplashScreenView: View {
    @State private var isAnimating = false
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0.0
    @State private var titleOffset: CGFloat = 30
    @State private var titleOpacity: Double = 0.0
    @State private var loadingOpacity: Double = 0.0
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.8),
                    Color.purple.opacity(0.6),
                    Color.blue.opacity(0.4)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Background pattern (optional decorative elements)
            GeometryReader { geometry in
                ForEach(0..<20, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 20, height: 20)
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                        .scaleEffect(isAnimating ? 1.5 : 0.5)
                        .animation(
                            Animation.easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1),
                            value: isAnimating
                        )
                }
            }
            
            VStack(spacing: 30) {
                Spacer()
                
                // App Logo/Icon
                VStack(spacing: 20) {
                    ZStack {
                        // Shadow background
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.black.opacity(0.1))
                            .frame(width: 125, height: 125)
                            .blur(radius: 10)
                            .offset(y: 5)
                        
                        // App Icon
                        if let appIcon = UIImage(named: "AppIcon") {
                            Image(uiImage: appIcon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 25))
                        } else {
                            // Fallback to system icon if AppIcon not found
                            Image(systemName: "calendar")
                                .font(.system(size: 60, weight: .light))
                                .foregroundColor(.white)
                                .frame(width: 120, height: 120)
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .fill(LinearGradient(
                                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                )
                        }
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .rotationEffect(.degrees(rotationAngle))
                    
                    // App Name
                    Text("Calndr")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .offset(y: titleOffset)
                        .opacity(titleOpacity)
                    
                    // Tagline
                    Text("Family Calendar Made Simple")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .offset(y: titleOffset)
                        .opacity(titleOpacity * 0.8)
                }
                
                Spacer()
                
                // Loading indicator
                VStack(spacing: 16) {
                    // Custom loading animation
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(Color.white)
                                .frame(width: 12, height: 12)
                                .scaleEffect(isAnimating ? 1.0 : 0.5)
                                .opacity(isAnimating ? 1.0 : 0.3)
                                .animation(
                                    Animation.easeInOut(duration: 0.6)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.2),
                                    value: isAnimating
                                )
                        }
                    }
                    .opacity(loadingOpacity)
                    
                    Text("Loading your calendar...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .opacity(loadingOpacity)
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Logo animation
        withAnimation(.easeOut(duration: 0.8)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Slight rotation for dynamic feel
        withAnimation(.easeInOut(duration: 1.0).delay(0.3)) {
            rotationAngle = 5
        }
        
        withAnimation(.easeInOut(duration: 0.8).delay(0.8)) {
            rotationAngle = 0
        }
        
        // Title animation
        withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
            titleOffset = 0
            titleOpacity = 1.0
        }
        
        // Loading animation
        withAnimation(.easeIn(duration: 0.5).delay(0.8)) {
            loadingOpacity = 1.0
        }
        
        // Start background animation
        withAnimation(.easeInOut(duration: 1.0).delay(1.0)) {
            isAnimating = true
        }
    }
}

#Preview {
    SplashScreenView()
} 