import SwiftUI

struct HandoffTimeModal: View {
    let date: Date
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var isPresented: Bool
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedTimeIndex = 2 // Default to 5pm (index 2)
    @State private var selectedLocation = "daycare" // Default location
    @State private var currentInitializedDate: Date? = nil
    
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
        NavigationView {
            VStack(spacing: 20) {
                // Check if custodian data is loaded
                if !viewModel.isHandoffDataReady {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .progressViewStyle(CircularProgressViewStyle(tint: themeManager.currentTheme.iconActiveColor))
                        Text("Loading handoff information...")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(themeManager.currentTheme.mainBackgroundColor)
                } else {
                    // Existing modal content
                    modalContent
                }
            }
            .navigationTitle("Handoff Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(themeManager.currentTheme.textColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveHandoffTime()
                    }
                    .foregroundColor(themeManager.currentTheme.iconActiveColor)
                    .disabled(!viewModel.isHandoffDataReady) // Disable save until data is loaded
                }
            }
            .toolbarBackground(themeManager.currentTheme.headerBackgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .background(themeManager.currentTheme.mainBackgroundColor)
        .preferredColorScheme(themeManager.currentTheme.mainBackgroundColor.isLight ? .light : .dark)
        .onAppear {
            configureNavigationBarAppearance()
            // Defer initialization until all data is ready
            if viewModel.isHandoffDataReady {
                initializeTimeAndLocation()
            }
        }
        .onChange(of: viewModel.isHandoffDataReady) { isReady in
            if isReady {
                // Initialize when data becomes available
                initializeTimeAndLocation()
            }
        }
        .onDisappear {
            // Reset initialization state when modal is dismissed
            currentInitializedDate = nil
        }
    }
    
    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(themeManager.currentTheme.headerBackgroundColor)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(themeManager.currentTheme.textColor)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(themeManager.currentTheme.textColor)]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
    
    private var modalContent: some View {
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
                                    .foregroundColor(selectedTimeIndex == index ? themeManager.currentTheme.iconActiveColor : themeManager.currentTheme.textColor.opacity(0.6))
                                    .font(.title2)
                                
                                Text(handoffTimes[index].display)
                                    .font(.title3)
                                    .foregroundColor(themeManager.currentTheme.textColor)
                                
                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedTimeIndex == index ? themeManager.currentTheme.iconActiveColor.opacity(0.1) : themeManager.currentTheme.bubbleBackgroundColor.opacity(0.1))
                                    .stroke(selectedTimeIndex == index ? themeManager.currentTheme.iconActiveColor : Color.clear, lineWidth: 2)
                            )
                        }
                    }
                }
                .padding()
            }
            
            // Location Selection
            VStack(spacing: 15) {
                Text("Handoff Location")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.textColor)
                
                Menu {
                    ForEach(handoffLocations, id: \.self) { location in
                        Button(action: {
                            selectedLocation = location
                        }) {
                            HStack {
                                Text(location.capitalized)
                                    .foregroundColor(themeManager.currentTheme.textColor)
                                if selectedLocation == location {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundColor(themeManager.currentTheme.iconActiveColor)
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(themeManager.currentTheme.iconActiveColor)
                        
                        Text(selectedLocation.capitalized)
                            .font(.title3)
                            .foregroundColor(themeManager.currentTheme.textColor)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(themeManager.currentTheme.bubbleBackgroundColor.opacity(0.1))
                            .stroke(themeManager.currentTheme.iconActiveColor.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            
            // Selected time and location preview
            VStack(spacing: 10) {
                Text("Handoff Details")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.textColor)
                
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(themeManager.currentTheme.iconActiveColor)
                        Text(handoffTimes[selectedTimeIndex].display)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.currentTheme.textColor)
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(themeManager.currentTheme.iconActiveColor)
                        Text(selectedLocation.capitalized)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.currentTheme.textColor)
                        Spacer()
                    }
                }
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
                        .fill(themeManager.currentTheme.iconActiveColor)
                )
            }
            .padding()
        }
        .background(themeManager.currentTheme.mainBackgroundColor)
    }
    
    private func initializeTimeAndLocation() {
        // Only initialize if the date has changed or this is the first time
        guard currentInitializedDate != date else { return }

        // Set current handoff time and location for this date
        let handoffInfo = viewModel.getHandoffTimeForDate(date)
        
        // Find the closest matching time index
        selectedTimeIndex = findClosestTimeIndex(hour: handoffInfo.hour, minute: handoffInfo.minute)
        
        // Set location, defaulting to "other" if not found
        if let location = handoffInfo.location, !location.isEmpty {
            // Ensure the location exists in the list before setting
            if handoffLocations.contains(location.lowercased()) {
                selectedLocation = location.lowercased()
            } else {
                selectedLocation = "other" // Fallback for custom or unknown locations
            }
        } else {
            // Default to daycare if no location is set
            selectedLocation = "daycare"
        }
        
        currentInitializedDate = date
        
        print("Initialized handoff modal for \(formatDate(date)) with time \(handoffTimes[selectedTimeIndex].display) and location \(selectedLocation)")
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
        
        print("Saving handoff time: \(timeString) at \(selectedLocation) for date: \(dateString)")
        print("✅ Modal only updates handoff time and location, not custody")
        
        // Get current custody info to preserve the custodian
        let custodyInfo = viewModel.getCustodyInfo(for: date)
        let currentCustodianId = custodyInfo.owner
        
        // Update the custody record with new handoff time/location but keep same custodian
        updateHandoffTimeAndLocation(
            date: dateString,
            custodianId: currentCustodianId,
            handoffTime: timeString,
            handoffLocation: selectedLocation
        )
        
        self.isPresented = false
    }
    
    private func updateHandoffTimeAndLocation(date: String, custodianId: String, handoffTime: String, handoffLocation: String) {
        // This method updates the custody record with new handoff time/location
        // but keeps the same custodian (unlike dragging which changes custody)
        
        print("📝 Updating handoff info for \(date): time=\(handoffTime), location=\(handoffLocation), custodian=\(custodianId)")
        
        APIService.shared.updateCustodyRecord(for: date, custodianId: custodianId, handoffTime: handoffTime, handoffLocation: handoffLocation) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let custodyResponse):
                    print("✅ Updated handoff info: \(custodyResponse)")
                    // Update local custody records
                    if let index = self.viewModel.custodyRecords.firstIndex(where: { $0.event_date == custodyResponse.event_date }) {
                        self.viewModel.custodyRecords[index] = custodyResponse
                    } else {
                        self.viewModel.custodyRecords.append(custodyResponse)
                    }
                    
                case .failure(let error):
                    print("❌ Failed to update handoff info: \(error.localizedDescription)")
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
