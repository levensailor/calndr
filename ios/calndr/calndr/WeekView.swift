import SwiftUI

struct WeekView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingReminderModal = false
    @State private var showingHandoffModal = false
    @State private var selectedDate: Date = Date()
    
    var body: some View {
        ZStack {
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
                                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                                    
                                    // Handoff icon moved to right of day name
                                    if getHandoffDays().contains(day) {
                                        Button(action: {
                                            selectedDate = day
                                            showingHandoffModal = true
                                        }) {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                                .font(.headline)
                                                .foregroundColor(.purple)
                                        }
                                    }
                                    
                                    Spacer()
                                    // Temperature display
                                    if viewModel.showWeather, let weatherInfo = viewModel.weatherInfoForDate(day) {
                                        Text("\(Int(weatherInfo.temperature.rounded()))°")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                                            .padding(3)
                                            .background(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                                            .cornerRadius(4)
                                    }
                                }
                                Text(day.formatted(.dateTime.month().day()))
                                    .font(.caption)
                                    .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
                            }
                            .frame(width: 200, alignment: .leading)
                            
                            Spacer()
                            
                            // Reminder icon
                            Button(action: {
                                selectedDate = day
                                showingReminderModal = true
                            }) {
                                Image(systemName: "note.text")
                                    .font(.title2)
                                    .foregroundColor(viewModel.hasReminderForDate(day) ? .orange : .gray)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(viewModel.hasReminderForDate(day) ? Color.yellow.opacity(0.3) : Color.gray.opacity(0.1))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(viewModel.hasReminderForDate(day) ? Color.orange : Color.gray.opacity(0.5), lineWidth: 1)
                                    )
                            }
                            .padding(.trailing, 8)
                            

                            
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
                                        .foregroundColor(ownerId == viewModel.custodianOneId ? themeManager.currentTheme.parentOneTextColor : themeManager.currentTheme.parentTwoTextColor)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(ownerId == viewModel.custodianOneId ? themeManager.currentTheme.parentOneColorSwiftUI : themeManager.currentTheme.parentTwoColorSwiftUI)
                                        .cornerRadius(8)
                                }
                                .disabled(isDateInPast(day) && !UserDefaults.standard.bool(forKey: "allowPastCustodyEditing"))
                                .opacity((isDateInPast(day) && !UserDefaults.standard.bool(forKey: "allowPastCustodyEditing")) ? 0.5 : 1.0)
                            }
                        }
                    }
                    .padding()
                    .frame(minHeight: 60)
                    .background(themeManager.currentTheme.mainBackgroundColorSwiftUI.opacity(0.5))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
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
    
    private func getHandoffDays() -> [Date] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var handoffDays: Set<Date> = []
        let weekDaysSet = Set(getDaysForCurrentWeek())
        
        for custodyRecord in viewModel.custodyRecords {
            if custodyRecord.handoff_day == true {
                if let date = dateFormatter.date(from: custodyRecord.event_date) {
                    if weekDaysSet.contains(date) {
                        handoffDays.insert(date)
                    }
                }
            }
        }
        
        var previousOwner: String?
        
        for date in getDaysForCurrentWeek() {
            let currentOwner = viewModel.getCustodyInfo(for: date).owner
            
            if let prev = previousOwner, prev != currentOwner {
                let dateString = dateFormatter.string(from: date)
                let hasHandoffRecord = viewModel.custodyRecords.contains { record in
                    record.event_date == dateString && record.handoff_day == true
                }
                
                if !hasHandoffRecord {
                    handoffDays.insert(date)
                }
            }
            
            previousOwner = currentOwner
        }
        
        return Array(handoffDays).sorted()
    }
}

struct WeekView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let themeManager = ThemeManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager, themeManager: themeManager)
        WeekView(viewModel: calendarViewModel)
            .environmentObject(themeManager)
    }
} 
