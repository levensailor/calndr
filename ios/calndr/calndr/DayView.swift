import SwiftUI

struct DayView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
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
//                        .foregroundColor(themeManager.currentTheme.textColor)
//                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    // Temperature display
                    if viewModel.showWeather, let weatherInfo = viewModel.weatherInfoForDate(viewModel.currentDate) {
                        Text("\(Int(weatherInfo.temperature.rounded()))°F")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.currentTheme.textColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(themeManager.currentTheme.bubbleBackgroundColor)
                            .cornerRadius(12)
                            .frame(maxWidth: .infinity, alignment: .center)

                    }
                }
            
            // Custody Information
            VStack(alignment: .leading, spacing: 12) {
                Text("Custody")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.textColor)
                
                let custodyInfo = viewModel.getCustodyInfo(for: viewModel.currentDate)
                let ownerName = custodyInfo.text
                let ownerId = custodyInfo.owner
                
                if !ownerName.isEmpty {
                    Button(action: {
                        viewModel.toggleCustodian(for: viewModel.currentDate)
                    }) {
                        Text(ownerName.capitalized)
                            .font(.title2.bold())
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(ownerId == viewModel.custodianOne?.id ? themeManager.currentTheme.parentOneColor : themeManager.currentTheme.parentTwoColor)
                            .cornerRadius(10)
                    }
                    .disabled(isDateInPast(viewModel.currentDate) && !UserDefaults.standard.bool(forKey: "allowPastCustodyEditing"))
                    .opacity((isDateInPast(viewModel.currentDate) && !UserDefaults.standard.bool(forKey: "allowPastCustodyEditing")) ? 0.5 : 1.0)
                }
            }
            
            // Events List
            VStack(alignment: .leading, spacing: 12) {
                Text("Events")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.textColor)
                
                let events = viewModel.eventsForDate(viewModel.currentDate).filter { $0.position < 4 }
                let schoolEvent = viewModel.schoolEventForDate(viewModel.currentDate)
                let hasAnyEvents = !events.isEmpty || schoolEvent != nil
                
                if !hasAnyEvents {
                    Text("No events scheduled.")
                        .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                } else {
                    // Regular Events
                    ForEach(events) { event in
                        Text(event.content)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(themeManager.currentTheme.iconActiveColor.opacity(0.8))
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
            .background(themeManager.currentTheme.mainBackgroundColor.opacity(0.8))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func isDateInPast(_ date: Date) -> Bool {
        return date < Calendar.current.startOfDay(for: Date())
    }
}

struct DayView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager)
        DayView(viewModel: calendarViewModel)
    }
} 
