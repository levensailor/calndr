import SwiftUI

struct WeatherFXView: View {
    let weatherInfo: WeatherInfo
    let scale: CGFloat
    let opacityMultiplier: Double
    
    init(weatherInfo: WeatherInfo, scale: CGFloat = 1.0, opacityMultiplier: Double = 1.0) {
        self.weatherInfo = weatherInfo
        self.scale = scale
        self.opacityMultiplier = opacityMultiplier
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Cloud cover
                if weatherInfo.cloudCover > 20 { // 20% cloud cover threshold
                    let cloudCount = Int((weatherInfo.cloudCover / 25.0).rounded())
                    ForEach(0..<cloudCount, id: \.self) { i in
                        CloudView(scale: scale, opacityMultiplier: opacityMultiplier)
                            .offset(x: CGFloat.random(in: -geometry.size.width/2...geometry.size.width/2),
                                    y: CGFloat.random(in: -geometry.size.height/2...geometry.size.height/2))
                            .opacity(0.3 * opacityMultiplier)
                    }
                }

                // Precipitation
                if weatherInfo.precipitation > 30 { // 30% precipitation chance threshold
                    let intensity = weatherInfo.precipitation / 100.0 // 0.0 to 1.0
                    RainView(intensity: intensity, scale: scale, opacityMultiplier: opacityMultiplier)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color.clear)
            .allowsHitTesting(false)
            .clipped()
        }
    }
}

struct CloudView: View {
    @State private var drift: CGFloat = CGFloat.random(in: -20...20)
    let scale: CGFloat
    let opacityMultiplier: Double
    
    init(scale: CGFloat = 1.0, opacityMultiplier: Double = 1.0) {
        self.scale = scale
        self.opacityMultiplier = opacityMultiplier
    }

    var body: some View {
        Image(systemName: "cloud.fill")
            .resizable()
            .scaledToFit()
            .frame(width: CGFloat.random(in: 25...50) * scale)
            .foregroundColor(.gray)
            .opacity(0.5 * opacityMultiplier)
            .offset(x: drift)
            .onAppear {
                withAnimation(Animation.linear(duration: Double.random(in: 15...30)).repeatForever(autoreverses: true)) {
                    drift += CGFloat.random(in: -40...40)
                }
            }
    }
}

struct RainView: View {
    let intensity: Double // 0.0 to 1.0
    let scale: CGFloat
    let opacityMultiplier: Double
    
    init(intensity: Double, scale: CGFloat = 1.0, opacityMultiplier: Double = 1.0) {
        self.intensity = intensity
        self.scale = scale
        self.opacityMultiplier = opacityMultiplier
    }

    var body: some View {
        GeometryReader { geometry in
            let dropCount = Int(100 * intensity)
            ForEach(0..<dropCount, id: \.self) { _ in
                Raindrop(scale: scale, opacityMultiplier: opacityMultiplier)
                    .offset(x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: -geometry.size.height...geometry.size.height))
            }
        }
    }
}

struct Raindrop: View {
    @State private var yOffset = CGFloat.random(in: -1...0)
    @State private var isAnimating = false
    let duration = Double.random(in: 0.4...1.2)
    let scale: CGFloat
    let opacityMultiplier: Double
    
    init(scale: CGFloat = 1.0, opacityMultiplier: Double = 1.0) {
        self.scale = scale
        self.opacityMultiplier = opacityMultiplier
    }

    var body: some View {
        Rectangle()
            .fill(Color.blue.opacity(0.7 * opacityMultiplier))
            .frame(width: 1 * scale, height: CGFloat.random(in: 5...10) * scale)
            .offset(y: yOffset * 200) // Start offscreen
            .onAppear {
                isAnimating = true
            }
            .onChange(of: isAnimating) {
                withAnimation(Animation.linear(duration: duration).repeatForever(autoreverses: false)) {
                     yOffset = 1
                }
            }
    }
} 