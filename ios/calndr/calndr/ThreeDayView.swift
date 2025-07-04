import SwiftUI

struct ThreeDayView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 1) {
            // Three day rows
            ForEach(getThreeDays(), id: \.self) { day in
                HStack(spacing: 8) {
                    // Day header
                    VStack(spacing: 2) {
                        Text(dayOfWeekString(from: day))
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor)
                        
                        Text(dayString(from: day))
                            .font(.caption)
                            .foregroundColor(isToday(day) ? themeManager.currentTheme.todayBorderColor : themeManager.currentTheme.textColor.opacity(0.7))
                    }
                    .frame(width: 60)
                    
                    // Custody info
                    if shouldShowCustodyInfo(for: day) {
                        Text(getCustodyText(for: day))
                            .font(.caption)
                            .bold()
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(getCustodyBackgroundColor(for: day))
                            .cornerRadius(4)
                    }
                    
                    // Weather info
                    if shouldShowWeatherInfo(for: day) {
                        HStack(spacing: 4) {
                            Image(systemName: getWeatherIconName(for: day))
                                .font(.caption2)
                            Text(getTemperatureText(for: day))
                                .font(.caption2)
                        }
                        .foregroundColor(themeManager.currentTheme.textColor)
                        .padding(4)
                        .background(themeManager.currentTheme.bubbleBackgroundColor)
                        .cornerRadius(4)
                    }
                    
                    // School event
                    if let schoolEvent = viewModel.schoolEventForDate(day) {
                        Text(schoolEvent)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.green)
                            .cornerRadius(4)
                    }
                    
                    // Regular events
                    HStack(spacing: 4) {
                        ForEach(getFilteredEvents(for: day)) { event in
                            Text(event.content)
                                .font(.caption2)
                                .foregroundColor(themeManager.currentTheme.textColor)
                                .padding(4)
                                .background(themeManager.currentTheme.iconActiveColor.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
                .background(getDayBackgroundColor(for: day))
                .overlay(
                    Rectangle()
                        .stroke(getDayBorderColor(for: day), lineWidth: getDayBorderWidth(for: day))
                )
            }
            
            Spacer()
        }
        .background(themeManager.currentTheme.mainBackgroundColor)
        .onAppear {
            viewModel.fetchEvents()
        }
    }
    
    private func getThreeDays() -> [Date] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -1, to: viewModel.currentDate) ?? viewModel.currentDate
        
        var days: [Date] = []
        for i in 0..<3 {
            if let day = calendar.date(byAdding: .day, value: i, to: startDate) {
                days.append(day)
            }
        }
        return days
    }
    
    private func dayOfWeekString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E" // Short day name (Mon, Tue, etc.)
        return formatter.string(from: date)
    }
    
    private func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private func isToday(_ date: Date) -> Bool {
        return Calendar.current.isDateInToday(date)
    }
    
    private func getFilteredEvents(for day: Date) -> [Event] {
        let dayEvents = viewModel.eventsForDate(day)
        let filteredEvents = dayEvents.filter { event in
            event.position < 4 && !event.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return filteredEvents.sorted { $0.position < $1.position }
    }
    
    private func getCustodyBackgroundColor(for day: Date) -> Color {
        let custodyInfo = viewModel.getCustodyInfo(for: day)
        if custodyInfo.owner == viewModel.custodianOne?.id {
            return Color(hex: "#FFC2D9")
        } else {
            return Color(hex: "#96CBFC")
        }
    }
    
    // Helper methods to simplify complex expressions
    private func shouldShowCustodyInfo(for day: Date) -> Bool {
        let custodyInfo = viewModel.getCustodyInfo(for: day)
        return !custodyInfo.text.isEmpty
    }
    
    private func getCustodyText(for day: Date) -> String {
        let custodyInfo = viewModel.getCustodyInfo(for: day)
        return custodyInfo.text.capitalized
    }
    
    private func shouldShowWeatherInfo(for day: Date) -> Bool {
        return viewModel.showWeather && viewModel.weatherInfoForDate(day) != nil
    }
    
    private func getWeatherIconName(for day: Date) -> String {
        guard let weather = viewModel.weatherInfoForDate(day) else { return "cloud.fill" }
        return weatherIcon(for: weather)
    }
    
    private func getTemperatureText(for day: Date) -> String {
        guard let weather = viewModel.weatherInfoForDate(day) else { return "0°" }
        return "\(Int(weather.temperature.rounded()))°"
    }
    
    private func getDayBackgroundColor(for day: Date) -> Color {
        return isToday(day) ? themeManager.currentTheme.todayBorderColor.opacity(0.1) : Color.clear
    }
    
    private func getDayBorderColor(for day: Date) -> Color {
        return isToday(day) ? themeManager.currentTheme.todayBorderColor : themeManager.currentTheme.gridLinesColor
    }
    
    private func getDayBorderWidth(for day: Date) -> CGFloat {
        return isToday(day) ? 2 : 1
    }
    
    private func weatherIcon(for weather: WeatherInfo) -> String {
        // Determine weather condition based on precipitation and cloud cover
        if weather.precipitation > 60 {
            // High precipitation - likely rain
            return "cloud.rain.fill"
        } else if weather.precipitation > 20 {
            // Some precipitation - drizzle or light rain
            return "cloud.drizzle.fill"
        } else if weather.cloudCover > 80 {
            // Very cloudy
            return "cloud.fill"
        } else if weather.cloudCover > 40 {
            // Partly cloudy
            return "cloud.sun.fill"
        } else {
            // Clear/sunny
            return "sun.max.fill"
        }
    }
}

struct ThreeDayView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 