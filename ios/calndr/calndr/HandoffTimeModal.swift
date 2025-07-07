import SwiftUI

struct HandoffTimeModal: View {
    let date: Date
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var isPresented: Bool
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedTimeIndex = 2 // Default to 5pm (index 2)
    @State private var selectedLocation = "daycare" // Default location
    
    // Available handoff times
    private let handoffTimes = [
        (hour: 9, minute: 0, display: "9:00 AM"),
        (hour: 12, minute: 0, display: "12:00 PM"),
        (hour: 17, minute: 0, display: "5:00 PM")
    ]
    
    // Available locations
    private var handoffLocations: [String] {
        var locations = ["daycare", "grocery store", "other"]
        
        // Add parent homes based on actual parent names
        let parent1Name = viewModel.custodianOneName.lowercased()
            locations.insert("\(parent1Name)'s home", at: 1)
        
        let parent2Name = viewModel.custodianTwoName.lowercased()
            locations.insert("\(parent2Name)'s home", at: 2)
        
        
        return locations
    }

    var body: some View {
        ZStack {
            // Blurred background
            Rectangle()
                .fill(.ultraThinMaterial)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isPresented = false // Dismiss on tap
                }
                .transition(.opacity)

            // Main modal content, mimicking FocusedDayView
            VStack(alignment: .leading, spacing: 16) {
                // Header
                Text("Custody Handoff")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top)

                Text(formatDate(date))
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(themeManager.currentTheme.textColor.opacity(0.8))
                
                // Time Selection
                VStack(alignment: .leading, spacing: 10) {
                    Text("Handoff Time").font(.headline)
                    ForEach(0..<handoffTimes.count, id: \.self) { index in
                        Button(action: { selectedTimeIndex = index }) {
                            HStack {
                                Image(systemName: selectedTimeIndex == index ? "largecircle.fill.circle" : "circle")
                                Text(handoffTimes[index].display)
                                Spacer()
                            }
                            .foregroundColor(themeManager.currentTheme.textColor)
                            .padding(10)
                            .background(themeManager.currentTheme.textColor.opacity(selectedTimeIndex == index ? 0.2 : 0.05))
                            .cornerRadius(8)
                        }
                    }
                }
                
                // Location Selection
                VStack(alignment: .leading, spacing: 10) {
                    Text("Handoff Location").font(.headline)
                    Menu {
                        ForEach(handoffLocations, id: \.self) { location in
                            Button(location.capitalized) { selectedLocation = location }
                        }
                    } label: {
                        HStack {
                            Text(selectedLocation.capitalized)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                        }
                        .foregroundColor(themeManager.currentTheme.textColor)
                        .padding(12)
                        .background(themeManager.currentTheme.textColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                // Save Button mimicking the custody banner
                Button(action: {
                    saveHandoffTime()
                    isPresented = false
                }) {
                    Text("Save Handoff")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
            .frame(width: 300, height: 450) // Slightly taller to accommodate content
            .background(themeManager.currentTheme.mainBackgroundColor)
            .cornerRadius(20)
            .shadow(radius: 10)
            .onAppear(perform: initializeTimeAndLocation)
            .onChange(of: viewModel.custodyRecords) { _ in
                initializeTimeAndLocation()
            }
        }
    }
    
    private func initializeTimeAndLocation() {
        // Use a UTC calendar for comparison to avoid timezone issues
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        
        // Find the first handoff for the selected day by checking custody records
        if let handoff = viewModel.custodyRecords.first(where: {
            guard let handoffDate = viewModel.isoDateFormatter.date(from: $0.event_date) else { return false }
            return utcCalendar.isDate(handoffDate, inSameDayAs: self.date)
        }) {
            // Set the time index
            if let handoffTimeStr = handoff.handoff_time,
               let hour = Int(handoffTimeStr.prefix(2)),
               let timeIndex = handoffTimes.firstIndex(where: { $0.hour == hour }) {
                selectedTimeIndex = timeIndex
            }
            
            // Set the location
            selectedLocation = handoff.handoff_location ?? "other" // Use location or default to "other"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
    
    private func saveHandoffTime() {
        let selectedTime = handoffTimes[selectedTimeIndex]
        let timeString = String(format: "%02d:%02d", selectedTime.hour, selectedTime.minute)
        let dateString = viewModel.isoDateFormatter.string(from: date)
        
        // Get the current custodian for this date
        let currentCustodianId = viewModel.getCustodyInfo(for: date).owner

        // Use a background queue for API calls
        DispatchQueue.global(qos: .userInitiated).async {
            APIService.shared.updateCustodyRecord(
                for: dateString,
                custodianId: currentCustodianId,
                handoffTime: timeString,
                handoffLocation: self.selectedLocation
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let updatedRecord):
                        // Optionally, you can update your local model here
                        if let index = self.viewModel.custodyRecords.firstIndex(where: { $0.id == updatedRecord.id }) {
                            self.viewModel.custodyRecords[index] = updatedRecord
                        }
                    case .failure(let error):
                        print("Failed to update handoff: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // Dismiss the modal
        isPresented = false
    }
}

struct HandoffTimeModal_Previews: PreviewProvider {
    static var previews: some View {
        HandoffTimeModal(
            date: Date(),
            viewModel: CalendarViewModel(authManager: AuthenticationManager()),
            isPresented: .constant(true)
        )
        .environmentObject(ThemeManager())
    }
} 
