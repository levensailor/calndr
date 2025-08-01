import SwiftUI

struct AddMedicationView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var dosage = ""
    @State private var frequency = ""
    @State private var instructions = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(30 * 24 * 3600) // 30 days from now
    @State private var isActive = true
    @State private var reminderEnabled = false
    @State private var reminderTime = Date()
    @State private var notes = ""
    @State private var showingEndDatePicker = false
    
    // Predefined frequency options
    private let frequencyOptions = [
        "Once daily",
        "Twice daily",
        "Three times daily",
        "Every 4 hours",
        "Every 6 hours",
        "Every 8 hours",
        "Every 12 hours",
        "As needed",
        "Weekly",
        "Monthly"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add Medication")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.currentTheme.textColor.color)
                        
                        Text("Add a new medication with tracking and reminders")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Basic Information
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Basic Information")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor.color)
                        
                        VStack(spacing: 16) {
                            TextField("Medication Name *", text: $name)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            TextField("Dosage (e.g., 500mg, 1 tablet)", text: $dosage)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Picker("Frequency", selection: $frequency) {
                                Text("Select frequency").tag("")
                                ForEach(frequencyOptions, id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            
                            TextField("Instructions (e.g., Take with food)", text: $instructions)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    .padding(.horizontal)
                    
                    // Schedule
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Schedule")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor.color)
                        
                        VStack(spacing: 16) {
                            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                                .datePickerStyle(CompactDatePickerStyle())
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack {
                                Toggle("Set End Date", isOn: $showingEndDatePicker)
                                    .foregroundColor(themeManager.currentTheme.textColor.color)
                                
                                Spacer()
                            }
                            
                            if showingEndDatePicker {
                                DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                                    .datePickerStyle(CompactDatePickerStyle())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            HStack {
                                Toggle("Active Medication", isOn: $isActive)
                                    .foregroundColor(themeManager.currentTheme.textColor.color)
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Reminders
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Reminders")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor.color)
                        
                        VStack(spacing: 16) {
                            HStack {
                                Toggle("Enable Reminders", isOn: $reminderEnabled)
                                    .foregroundColor(themeManager.currentTheme.textColor.color)
                                
                                Spacer()
                            }
                            
                            if reminderEnabled {
                                DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(CompactDatePickerStyle())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text("You'll receive notifications at this time each day")
                                    .font(.caption)
                                    .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Additional Notes")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor.color)
                        
                        TextField("Notes (side effects, special instructions, etc.)", text: $notes, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 80)
                }
            }
            .scrollTargetBehavior(CustomVerticalPagingBehavior())
            .background(themeManager.currentTheme.mainBackgroundColor.color)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(themeManager.currentTheme.textColor.color)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveMedication()
                }
                .foregroundColor(.red)
                .disabled(name.isEmpty)
            }
        }
    }
    
    private func saveMedication() {
        guard !name.isEmpty else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        let medicationData = MedicationCreate(
            name: name,
            dosage: dosage.isEmpty ? nil : dosage,
            frequency: frequency.isEmpty ? nil : frequency,
            instructions: instructions.isEmpty ? nil : instructions,
            startDate: dateFormatter.string(from: startDate),
            endDate: showingEndDatePicker ? dateFormatter.string(from: endDate) : nil,
            isActive: isActive,
            reminderEnabled: reminderEnabled,
            reminderTime: reminderEnabled ? timeFormatter.string(from: reminderTime) : nil,
            notes: notes.isEmpty ? nil : notes
        )
        
        viewModel.saveMedication(medicationData) { success in
            DispatchQueue.main.async {
                if success {
                    print("✅ Successfully saved medication: \(name)")
                    dismiss()
                } else {
                    print("❌ Failed to save medication: \(name)")
                }
            }
        }
    }
}

struct AddMedicationView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let themeManager = ThemeManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager, themeManager: themeManager)
        
        AddMedicationView()
            .environmentObject(calendarViewModel)
            .environmentObject(themeManager)
    }
} 