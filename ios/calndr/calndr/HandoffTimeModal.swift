import SwiftUI

struct HandoffTimeModal: View {
    let date: Date
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var isPresented: Bool
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedHour = 17 // Default to 5 PM
    @State private var selectedMinute = 0
    @State private var isInitialized = false

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
            
            // Time Picker with enhanced visual appeal
            VStack {
                Text("Handoff Time")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.textColor)
                
                HStack {
                    // Hour Picker
                    Picker("Hour", selection: $selectedHour) {
                        ForEach(0..<24) { hour in
                            Text(String(format: "%02d", hour))
                                .font(.title2)
                                .foregroundColor(themeManager.currentTheme.textColor)
                                .tag(hour)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 80)
                    .clipped()
                    
                    Text(":")
                        .font(.title)
                        .foregroundColor(themeManager.currentTheme.textColor)
                    
                    // Minute Picker
                    Picker("Minute", selection: $selectedMinute) {
                        ForEach(0..<60) { minute in
                            Text(String(format: "%02d", minute))
                                .font(.title2)
                                .foregroundColor(themeManager.currentTheme.textColor)
                                .tag(minute)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 80)
                    .clipped()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(themeManager.currentTheme.bubbleBackgroundColor.opacity(0.1))
                )
            }
            .padding()
            
            // Selected time preview
            VStack {
                Text("Selected Time")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.textColor)
                
                Text(formatTime(hour: selectedHour, minute: selectedMinute))
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
            initializePickerValues()
        }
    }
    
    private func initializePickerValues() {
        // Ensure we only initialize once to prevent conflicts
        guard !isInitialized else { return }
        
        // Set current handoff time for this date
        let currentTime = viewModel.getHandoffTimeForDate(date)
        selectedHour = currentTime.hour
        selectedMinute = currentTime.minute
        isInitialized = true
        
        print("Initialized handoff modal for \(formatDate(date)) with time \(currentTime.hour):\(currentTime.minute)")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
    
    private func formatTime(hour: Int, minute: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        
        if let time = Calendar.current.date(from: components) {
            return formatter.string(from: time)
        }
        return "\(hour):\(String(format: "%02d", minute))"
    }
    
    private func saveHandoffTime() {
        let timeString = String(format: "%02d:%02d", selectedHour, selectedMinute)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        print("Saving handoff time: \(timeString) for date: \(dateString)")
        
        APIService.shared.saveHandoffTime(date: dateString, time: timeString) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let handoffTime):
                    print("✅ Successfully saved handoff time: \(handoffTime)")
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