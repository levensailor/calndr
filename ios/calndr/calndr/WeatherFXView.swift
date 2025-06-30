import SwiftUI

struct WeatherFXView: View {
    let weatherInfo: WeatherInfo

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Cloud cover
                if weatherInfo.cloudCover > 20 { // 20% cloud cover threshold
                    let cloudCount = Int((weatherInfo.cloudCover / 25.0).rounded())
                    ForEach(0..<cloudCount, id: \.self) { i in
                        CloudView()
                            .offset(x: CGFloat.random(in: -geometry.size.width/2...geometry.size.width/2),
                                    y: CGFloat.random(in: -geometry.size.height/2...geometry.size.height/2))
                            .opacity(0.3)
                    }
                }

                // Precipitation
                if weatherInfo.precipitation > 30 { // 30% precipitation chance threshold
                    let intensity = weatherInfo.precipitation / 100.0 // 0.0 to 1.0
                    RainView(intensity: intensity)
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

    var body: some View {
        Image(systemName: "cloud.fill")
            .resizable()
            .scaledToFit()
            .frame(width: CGFloat.random(in: 25...50))
            .foregroundColor(.gray)
            .opacity(0.5)
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

    var body: some View {
        GeometryReader { geometry in
            let dropCount = Int(100 * intensity)
            ForEach(0..<dropCount, id: \.self) { _ in
                Raindrop()
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

    var body: some View {
        Rectangle()
            .fill(Color.blue.opacity(0.7))
            .frame(width: 1, height: CGFloat.random(in: 5...10))
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