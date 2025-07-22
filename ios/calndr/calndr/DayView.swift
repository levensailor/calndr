import SwiftUI

struct DayView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingReminderModal = false
    @State private var showingHandoffModal = false
    
    var body: some View {
        ZStack {
            // Weather effects background
            if viewModel.showWeather, let weatherInfo = viewModel.weatherInfoForDate(viewModel.currentDate) {
                WeatherFXView(weatherInfo: weatherInfo, scale: 10.0, opacityMultiplier: 2.0)
                    .ignoresSafeArea()
            }
            
            VStack(alignment: .leading, spacing: 20) {
                // Header with temperature
                VStack(spacing: 8) {
//                    Text(viewModel.currentDate.formatted(.dateTime.weekday(.wide)))
//                        .font(.largeTitle.bold())
//                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
//                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    // Temperature display
                    if viewModel.showWeather, let weatherInfo = viewModel.weatherInfoForDate(viewModel.currentDate) {
                        Text("\(Int(weatherInfo.temperature.rounded()))°F")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                            .cornerRadius(12)
                            .frame(maxWidth: .infinity, alignment: .center)

                    }
                }
            
            // Custody Information
            VStack(alignment: .leading, spacing: 12) {
                Text("Custody")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                
                let custodyInfo = getCustodyInfoWithDebug(for: viewModel.currentDate)
                let ownerName = custodyInfo.text
                let ownerId = custodyInfo.owner
                
                if !ownerName.isEmpty {
                    Button(action: {
                        viewModel.toggleCustodian(for: viewModel.currentDate)
                    }) {
                        Text(ownerName.capitalized)
                            .font(.title2.bold())
                            .foregroundColor(ownerId == viewModel.custodianOneId ? themeManager.currentTheme.parentOneTextColor : themeManager.currentTheme.parentTwoTextColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(ownerId == viewModel.custodianOneId ? themeManager.currentTheme.parentOneColorSwiftUI : themeManager.currentTheme.parentTwoColorSwiftUI)
                            .cornerRadius(10)
                    }
                    .disabled(isDateInPast(viewModel.currentDate) && !UserDefaults.standard.bool(forKey: "allowPastCustodyEditing"))
                    .opacity((isDateInPast(viewModel.currentDate) && !UserDefaults.standard.bool(forKey: "allowPastCustodyEditing")) ? 0.5 : 1.0)
                }
            }
            
            // Reminder Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Reminder")
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                    
                    Spacer()
                    
                    Button(action: {
                        showingReminderModal = true
                    }) {
                        Image(systemName: viewModel.hasReminderForDate(viewModel.currentDate) ? "note.text" : "note.text.badge.plus")
                            .font(.title2)
                            .foregroundColor(viewModel.hasReminderForDate(viewModel.currentDate) ? .orange : .gray)
                    }
                }
                
                if viewModel.hasReminderForDate(viewModel.currentDate) {
                    Text(viewModel.getReminderTextForDate(viewModel.currentDate))
                        .font(.body)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.yellow.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.orange, lineWidth: 1)
                                )
                        )
                        .onTapGesture {
                            showingReminderModal = true
                        }
                } else {
                    Text("No reminder set")
                        .font(.body)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.6))
                        .italic()
                }
            }
            
            // Handoff Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Handoff")
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                    
                    Spacer()
                    
                    Button(action: {
                        showingHandoffModal = true
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.title2)
                            .foregroundColor(hasHandoffForDate(viewModel.currentDate) ? .purple : .gray)
                    }
                }
                
                if hasHandoffForDate(viewModel.currentDate) {
                    Text(getHandoffTextForDate(viewModel.currentDate))
                        .font(.body)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.purple.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.purple, lineWidth: 1)
                                )
                        )
                        .onTapGesture {
                            showingHandoffModal = true
                        }
                } else {
                    Text("No handoff scheduled")
                        .font(.body)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.6))
                        .italic()
                }
            }
            
            // Events List
            VStack(alignment: .leading, spacing: 12) {
                Text("Events")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                
                let events = viewModel.eventsForDate(viewModel.currentDate).filter { $0.position < 4 }
                let schoolEvent = viewModel.schoolEventForDate(viewModel.currentDate)
                let hasAnyEvents = !events.isEmpty || schoolEvent != nil
                
                if !hasAnyEvents {
                    Text("No events scheduled.")
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.6))
                } else {
                    // Regular Events
                    ForEach(events) { event in
                        Text(event.content)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(themeManager.currentTheme.iconActiveColorSwiftUI.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    // School Events (only shown if enabled and exists)
                    if let schoolEvent = schoolEvent {
                        Text(schoolEvent)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .overlay(
                                HStack {
                                    Spacer()
                                    Image(systemName: "graduationcap.fill")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(.trailing, 12)
                            )
                    }
                }
            }
            
            Spacer()
            }
            .padding()
            .background(themeManager.currentTheme.mainBackgroundColorSwiftUI.opacity(0.8))
            .cornerRadius(12)
            .shadow(radius: 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showingReminderModal) {
            ReminderModal(date: viewModel.currentDate)
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingHandoffModal) {
            HandoffTimeModal(date: viewModel.currentDate, viewModel: viewModel, isPresented: $showingHandoffModal)
                .environmentObject(themeManager)
        }
    }
    
    private func isDateInPast(_ date: Date) -> Bool {
        return date < Calendar.current.startOfDay(for: Date())
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
        let timeString = String(format: "%02d:%02d", handoffTime.hour, handoffTime.minute)
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
            print("🔍 DayView: getCustodyInfo for Monday 21st (\(dateString)) = '\(custodyInfo.text)' (owner: '\(custodyInfo.owner)')")
        }
        
        return custodyInfo
    }
}

struct DayView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let themeManager = ThemeManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager, themeManager: themeManager)
        DayView(viewModel: calendarViewModel)
            .environmentObject(themeManager)
    }
} 
