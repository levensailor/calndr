import SwiftUI

struct WeekView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack {
            ForEach(getDaysForCurrentWeek(), id: \.self) { day in
                ZStack {
                    // Weather effects background
                    if viewModel.showWeather, let weatherInfo = viewModel.weatherInfoForDate(day) {
                        WeatherFXView(weatherInfo: weatherInfo)
                            .cornerRadius(8)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(day.formatted(.dateTime.weekday(.wide)))
                                    .font(.headline)
                                    .foregroundColor(themeManager.currentTheme.textColor)
                                Spacer()
                                // Temperature display
                                if viewModel.showWeather, let weatherInfo = viewModel.weatherInfoForDate(day) {
                                    Text("\(Int(weatherInfo.temperature.rounded()))°")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(themeManager.currentTheme.dayNumberColor)
                                        .padding(3)
                                        .background(themeManager.currentTheme.bubbleBackgroundColor)
                                        .cornerRadius(4)
                                }
                            }
                            Text(day.formatted(.dateTime.month().day()))
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                        }
                        .frame(width: 120, alignment: .leading)
                        
                        Spacer()
                        
                        // Custody information and toggle button
                        let custodyInfo = viewModel.getCustodyInfo(for: day)
                        let ownerName = custodyInfo.text
                        let ownerId = custodyInfo.owner
                        
                        if !ownerName.isEmpty {
                            Button(action: {
                                viewModel.toggleCustodian(for: day)
                            }) {
                                Text(ownerName.capitalized)
                                    .font(.headline.bold())
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(ownerId == viewModel.custodianOne?.id ? Color(hex: "#FFC2D9") : Color(hex: "#96CBFC"))
                                    .cornerRadius(8)
                            }
                            .disabled(isDateInPast(day) && !UserDefaults.standard.bool(forKey: "allowPastCustodyEditing"))
                            .opacity((isDateInPast(day) && !UserDefaults.standard.bool(forKey: "allowPastCustodyEditing")) ? 0.5 : 1.0)
                        }
                    }
                }
                .padding()
                .frame(minHeight: 60)
                .background(themeManager.currentTheme.mainBackgroundColor.opacity(0.5))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
    
    private func getDaysForCurrentWeek() -> [Date] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: viewModel.currentDate) else {
            return []
        }
        
        var days: [Date] = []
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: weekInterval.start) {
                days.append(date)
            }
        }
        return days
    }
    
    private func isDateInPast(_ date: Date) -> Bool {
        return date < Calendar.current.startOfDay(for: Date())
    }
}

struct WeekView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager)
        WeekView(viewModel: calendarViewModel)
    }
} 
