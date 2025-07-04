import SwiftUI

struct ThreeDayView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header for days of the week
            HStack(spacing: 0) {
                ForEach(getThreeDays(), id: \.self) { day in
                    VStack(spacing: 4) {
                        Text(dayOfWeekString(from: day))
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor)
                        
                        Text(dayString(from: day))
                            .font(.caption)
                            .foregroundColor(isToday(day) ? themeManager.currentTheme.todayBorderColor : themeManager.currentTheme.textColor.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            .background(themeManager.currentTheme.headerBackgroundColor)
            
            // Three day columns
            HStack(spacing: 1) {
                ForEach(getThreeDays(), id: \.self) { day in
                    VStack(spacing: 4) {
                        // Custody info
                        let custodyInfo = viewModel.getCustodyInfo(for: day)
                        if !custodyInfo.text.isEmpty {
                            Text(custodyInfo.text.capitalized)
                                .font(.caption)
                                .bold()
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, minHeight: 20)
                                .background(getCustodyBackgroundColor(for: custodyInfo.owner))
                                .cornerRadius(4)
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 20)
                        }
                        
                        // Weather info
                        if viewModel.showWeather, let weather = viewModel.weatherInfoForDate(day) {
                            HStack(spacing: 4) {
                                Image(systemName: weatherIcon(for: weather.condition))
                                    .font(.caption2)
                                Text("\(Int(weather.temperature.rounded()))°")
                                    .font(.caption2)
                            }
                            .foregroundColor(themeManager.currentTheme.textColor)
                            .padding(2)
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
                        ForEach(getFilteredEvents(for: day)) { event in
                            Text(event.content)
                                .font(.caption2)
                                .foregroundColor(themeManager.currentTheme.textColor)
                                .padding(2)
                                .background(themeManager.currentTheme.iconActiveColor.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(isToday(day) ? themeManager.currentTheme.todayBorderColor.opacity(0.1) : Color.clear)
                    .overlay(
                        Rectangle()
                            .stroke(isToday(day) ? themeManager.currentTheme.todayBorderColor : themeManager.currentTheme.gridLinesColor, lineWidth: isToday(day) ? 2 : 1)
                    )
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor)
            
            Spacer()
        }
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
    
    private func getCustodyBackgroundColor(for ownerID: String) -> Color {
        if ownerID == viewModel.custodianOne?.id {
            return Color(hex: "#FFC2D9")
        } else {
            return Color(hex: "#96CBFC")
        }
    }
    
    private func weatherIcon(for condition: String) -> String {
        switch condition.lowercased() {
        case "clear", "sunny":
            return "sun.max.fill"
        case "clouds", "cloudy", "overcast":
            return "cloud.fill"
        case "rain", "drizzle":
            return "cloud.rain.fill"
        case "snow":
            return "cloud.snow.fill"
        case "thunderstorm":
            return "cloud.bolt.fill"
        default:
            return "cloud.fill"
        }
    }
}

struct ThreeDayView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 