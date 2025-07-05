import SwiftUI

struct HandoffTimeModal: View {
    let date: Date
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var isPresented: Bool
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedTimeIndex = 2 // Default to 5pm (index 2)
    @State private var isInitialized = false
    
    // Available handoff times
    private let handoffTimes = [
        (hour: 9, minute: 0, display: "9:00 AM"),
        (hour: 12, minute: 0, display: "12:00 PM"),
        (hour: 17, minute: 0, display: "5:00 PM")
    ]

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack {
                Text("Custody Handoff")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.currentTheme.textColor)
                
                Text(formatDate(date))
                    .font(.title2)
                    .foregroundColor(themeManager.currentTheme.textColor.opacity(0.8))
            }
            .padding()
            
            // Time Selection with segmented control
            VStack(spacing: 15) {
                Text("Handoff Time")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.textColor)
                
                VStack(spacing: 10) {
                    ForEach(0..<handoffTimes.count, id: \.self) { index in
                        Button(action: {
                            selectedTimeIndex = index
                        }) {
                            HStack {
                                Image(systemName: selectedTimeIndex == index ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedTimeIndex == index ? Color.purple : themeManager.currentTheme.textColor.opacity(0.6))
                                    .font(.title2)
                                
                                Text(handoffTimes[index].display)
                                    .font(.title3)
                                    .foregroundColor(themeManager.currentTheme.textColor)
                                
                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedTimeIndex == index ? Color.purple.opacity(0.1) : themeManager.currentTheme.bubbleBackgroundColor.opacity(0.1))
                                    .stroke(selectedTimeIndex == index ? Color.purple : Color.clear, lineWidth: 2)
                            )
                        }
                    }
                }
                .padding()
            }
            
            // Selected time preview
            VStack {
                Text("Selected Time")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.textColor)
                
                Text(handoffTimes[selectedTimeIndex].display)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Color.purple)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(themeManager.currentTheme.bubbleBackgroundColor)
                    )
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 20) {
                Button("Cancel") {
                    isPresented = false
                }
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.textColor)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(themeManager.currentTheme.textColor, lineWidth: 2)
                )
                
                Button("Save") {
                    saveHandoffTime()
                }
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.purple)
                )
            }
            .padding()
        }
        .background(themeManager.currentTheme.mainBackgroundColor)
        .onAppear {
            initializeTimeSelection()
        }
    }
    
    private func initializeTimeSelection() {
        // Ensure we only initialize once to prevent conflicts
        guard !isInitialized else { return }
        
        // Set current handoff time for this date
        let currentTime = viewModel.getHandoffTimeForDate(date)
        
        // Find the closest matching time index
        selectedTimeIndex = findClosestTimeIndex(hour: currentTime.hour, minute: currentTime.minute)
        isInitialized = true
        
        print("Initialized handoff modal for \(formatDate(date)) with time \(handoffTimes[selectedTimeIndex].display)")
    }
    
    private func findClosestTimeIndex(hour: Int, minute: Int) -> Int {
        let totalMinutes = hour * 60 + minute
        
        var closestIndex = 0
        var smallestDifference = Int.max
        
        for (index, time) in handoffTimes.enumerated() {
            let timeMinutes = time.hour * 60 + time.minute
            let difference = abs(totalMinutes - timeMinutes)
            
            if difference < smallestDifference {
                smallestDifference = difference
                closestIndex = index
            }
        }
        
        return closestIndex
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
    
    private func saveHandoffTime() {
        let selectedTime = handoffTimes[selectedTimeIndex]
        let timeString = String(format: "%02d:%02d", selectedTime.hour, selectedTime.minute)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        print("Saving handoff time: \(timeString) for date: \(dateString)")
        
        APIService.shared.saveHandoffTime(date: dateString, time: timeString) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let handoffTime):
                    print("✅ Successfully saved handoff time: \(handoffTime)")
                    
                    // Update custody for this date based on handoff time
                    self.updateCustodyBasedOnHandoffTime()
                    
                    // Refresh handoff times to update the view
                    self.viewModel.fetchHandoffTimes()
                    self.isPresented = false
                    
                case .failure(let error):
                    print("❌ Failed to save handoff time: \(error.localizedDescription)")
                    // Still close the modal for now
                    self.isPresented = false
                }
            }
        }
    }
    
    private func updateCustodyBasedOnHandoffTime() {
        // Determine who should have custody after this handoff
        let custodyInfo = viewModel.getCustodyInfo(for: date)
        let currentCustodian = custodyInfo.owner
        
        // Toggle to the other parent
        let newCustodianId: String
        if currentCustodian == viewModel.custodianOne?.id {
            newCustodianId = viewModel.custodianTwo?.id ?? ""
        } else {
            newCustodianId = viewModel.custodianOne?.id ?? ""
        }
        
        guard !newCustodianId.isEmpty else {
            print("Error: Could not determine new custodian ID for handoff")
            return
        }
        
        let dateString = viewModel.isoDateString(from: date)
        
        // Update custody record for this date
        APIService.shared.updateCustodyRecord(for: dateString, custodianId: newCustodianId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let custodyResponse):
                    print("✅ Updated custody for handoff date: \(custodyResponse)")
                    // Update local custody records
                    if let index = self.viewModel.custodyRecords.firstIndex(where: { $0.event_date == custodyResponse.event_date }) {
                        self.viewModel.custodyRecords[index] = custodyResponse
                    } else {
                        self.viewModel.custodyRecords.append(custodyResponse)
                    }
                    self.viewModel.updateCustodyPercentages()
                    
                case .failure(let error):
                    print("❌ Failed to update custody for handoff: \(error.localizedDescription)")
                }
            }
        }
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