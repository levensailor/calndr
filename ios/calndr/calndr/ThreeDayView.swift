import SwiftUI

struct ThreeDayView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingReminderModal = false
    @State private var showingHandoffModal = false
    @State private var selectedDate: Date = Date()
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 1) {
                // Three day sections
                ForEach(getThreeDays(), id: \.self) { day in
                    VStack(spacing: 0) {
                        // Header with day name and custody badge
                        HStack {
                            Text(getDayHeaderText(for: day))
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(themeManager.currentTheme.textColor.color)
                            
                            Spacer()
                            
                            // Custody badge
                            if shouldShowCustodyInfo(for: day) {
                                Text(getCustodyText(for: day))
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(themeManager.currentTheme.smartTextColor(for: getCustodyBackgroundColor(for: day)))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(getCustodyBackgroundColor(for: day))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(themeManager.currentTheme.secondaryBackgroundColor.color)
                        
                        // Content area for events and info
                        VStack(alignment: .leading, spacing: 8) {
                            // Weather info
                            if shouldShowWeatherInfo(for: day) {
                                HStack(spacing: 8) {
                                    Image(systemName: getWeatherIconName(for: day))
                                        .font(.title3)
                                        .foregroundColor(themeManager.currentTheme.iconActiveColor.color)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Weather")
                                            .font(.caption)
                                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                                        Text(getTemperatureText(for: day))
                                            .font(.subheadline)
                                            .foregroundColor(themeManager.currentTheme.textColor.color)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                            }
                            
                            // School event - Orange color
                            if let schoolEvent = viewModel.schoolEventForDate(day) {
                                HStack(spacing: 8) {
                                    Image(systemName: "graduationcap.fill")
                                        .font(.title3)
                                        .foregroundColor(.orange)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("School")
                                            .font(.caption)
                                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                                        Text(schoolEvent)
                                            .font(.subheadline)
                                            .foregroundColor(themeManager.currentTheme.textColor.color)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                            }
                            
                            // Daycare event - Purple color
                            if let daycareEvent = viewModel.daycareEventForDate(day) {
                                HStack(spacing: 8) {
                                    Image(systemName: "building.2.fill")
                                        .font(.title3)
                                        .foregroundColor(.purple)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Daycare")
                                            .font(.caption)
                                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                                        Text(daycareEvent)
                                            .font(.subheadline)
                                            .foregroundColor(themeManager.currentTheme.textColor.color)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                            }
                            
                            // Regular events
                            if !getFilteredEvents(for: day).isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "calendar")
                                            .font(.title3)
                                            .foregroundColor(themeManager.currentTheme.iconActiveColor.color)
                                        
                                        Text("Events")
                                            .font(.caption)
                                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(getFilteredEvents(for: day)) { event in
                                            Text(event.content)
                                                .font(.subheadline)
                                                .foregroundColor(themeManager.currentTheme.textColor.color)
                                                .padding(.horizontal, 16)
                                        }
                                    }
                                }
                            }
                            
                            // Reminder section
                            if viewModel.hasReminderForDate(day) {
                                HStack(spacing: 8) {
                                    Image(systemName: "note.text")
                                        .font(.title3)
                                        .foregroundColor(.orange)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Reminder")
                                            .font(.caption)
                                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                                        Text(viewModel.getReminderTextForDate(day))
                                            .font(.subheadline)
                                            .foregroundColor(themeManager.currentTheme.textColor.color)
                                            .lineLimit(2)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .onTapGesture {
                                    selectedDate = day
                                    showingReminderModal = true
                                }
                            }
                            
                            // Handoff section
                            if hasHandoffForDate(day) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.title3)
                                        .foregroundColor(.purple)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Handoff")
                                            .font(.caption)
                                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                                        Text(getHandoffTextForDate(day))
                                            .font(.subheadline)
                                            .foregroundColor(themeManager.currentTheme.textColor.color)
                                            .lineLimit(2)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .onTapGesture {
                                    selectedDate = day
                                    showingHandoffModal = true
                                }
                            }
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(getDayBackgroundColor(for: day))
                    }
                    .frame(height: (geometry.size.height - 2) / 3) // Equal height for each section
                    .overlay(
                        Rectangle()
                            .stroke(getDayBorderColor(for: day), lineWidth: getDayBorderWidth(for: day))
                    )
                }
            }
        }
        .background(themeManager.currentTheme.mainBackgroundColor.color)
        .onAppear {
            viewModel.fetchEvents()
        }
        .sheet(isPresented: $showingReminderModal) {
            ReminderModal(date: selectedDate)
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingHandoffModal) {
            HandoffTimeModal(date: selectedDate, viewModel: viewModel, isPresented: $showingHandoffModal)
                .environmentObject(themeManager)
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
            event.position != 4 && // Exclude custody events
            !event.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            event.source_type != "school" && // Exclude school events (non-editable)
            event.source_type != "daycare" // Exclude daycare events (non-editable)
        }
        return filteredEvents
    }
    
    private func getCustodyBackgroundColor(for day: Date) -> Color {
        let custodyInfo = getCustodyInfoWithDebug(for: day)
        if custodyInfo.owner == viewModel.custodianOneId {
            return themeManager.currentTheme.parentOneColor.color
        } else {
            return themeManager.currentTheme.parentTwoColor.color
        }
    }
    
    // Helper methods to simplify complex expressions
    private func shouldShowCustodyInfo(for day: Date) -> Bool {
        let custodyInfo = getCustodyInfoWithDebug(for: day)
        return !custodyInfo.text.isEmpty
    }
    
    private func getCustodyText(for day: Date) -> String {
        let custodyInfo = getCustodyInfoWithDebug(for: day)
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
        return isToday(day) ? themeManager.currentTheme.accentColor.color.opacity(0.1) : Color.clear
    }
    
    private func getDayBorderColor(for day: Date) -> Color {
        return isToday(day) ? themeManager.currentTheme.accentColor.color : themeManager.currentTheme.secondaryBackgroundColor.color.opacity(0.5)
    }
    
    private func getDayBorderWidth(for day: Date) -> CGFloat {
        return isToday(day) ? 2 : 1
    }
    
    private func getDayHeaderText(for day: Date) -> String {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE" // Full day name
        
        let dayNumberFormatter = DateFormatter()
        dayNumberFormatter.dateFormat = "d"
        
        let dayName = dayFormatter.string(from: day)
        let dayNumber = dayNumberFormatter.string(from: day)
        
        // Add ordinal suffix (1st, 2nd, 3rd, etc.)
        let ordinalSuffix = getOrdinalSuffix(for: Int(dayNumber) ?? 0)
        
        return "\(dayName) \(dayNumber)\(ordinalSuffix)"
    }
    
    private func getOrdinalSuffix(for number: Int) -> String {
        switch number {
        case 11, 12, 13:
            return "th"
        default:
            switch number % 10 {
            case 1:
                return "st"
            case 2:
                return "nd"
            case 3:
                return "rd"
            default:
                return "th"
            }
        }
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
    
    private func hasHandoffForDate(_ date: Date) -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        // Check if there's a handoff record for this date
        let hasHandoffRecord = viewModel.custodyRecords.contains { record in
            record.event_date == dateString && record.handoff_day == true
        }
        
        if hasHandoffRecord {
            return true
        }
        
        // Check if there's a custody change from previous day
        if let previousDate = Calendar.current.date(byAdding: .day, value: -1, to: date) {
            let previousOwner = viewModel.getCustodyInfo(for: previousDate).owner
            let currentOwner = viewModel.getCustodyInfo(for: date).owner
            return previousOwner != currentOwner
        }
        
        return false
    }
    
    private func getHandoffTextForDate(_ date: Date) -> String {
        let handoffTime = viewModel.getHandoffTimeForDate(date)
        let timeString = TimeFormatter.format12Hour(hour: handoffTime.hour, minute: handoffTime.minute)
        let location = handoffTime.location ?? "daycare"
        return "\(timeString) at \(location)"
    }
    
    private func getCustodyInfoWithDebug(for date: Date) -> (owner: String, text: String) {
        let custodyInfo = viewModel.getCustodyInfo(for: date)
        
        // Debug for Monday 21st
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        if dateString.contains("-21") {
            print("🔍 ThreeDayView: getCustodyInfo for Monday 21st (\(dateString)) = '\(custodyInfo.text)' (owner: '\(custodyInfo.owner)')")
        }
        
        return custodyInfo
    }
}

struct ThreeDayView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 