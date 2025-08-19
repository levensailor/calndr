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
    @State private var presets: [MedicationPreset] = []
    // -1 = Custom, otherwise index into presets
    @State private var selectedPresetIndex: Int = -1
    
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
                    headerView
                    presetPickerView
                    basicInfoSection
                    scheduleSection
                    remindersSection
                    notesSection
                    Spacer(minLength: 80)
                }
            }
            .scrollTargetBehavior(CustomVerticalPagingBehavior())
            .background(mainBackgroundColor)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
                    .foregroundColor(textColor)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { saveMedication() }
                    .foregroundColor(.red)
                    .disabled(name.isEmpty)
            }
        }
        .onAppear { fetchPresets() }
    }

    // MARK: - Computed Theme Colors
    private var textColor: Color { themeManager.currentTheme.textColor.color }
    private var subduedTextColor: Color { themeManager.currentTheme.textColor.color.opacity(0.7) }
    private var faintTextStrokeColor: Color { themeManager.currentTheme.textColor.color.opacity(0.3) }
    private var captionTextColor: Color { themeManager.currentTheme.textColor.color.opacity(0.6) }
    private var mainBackgroundColor: Color { themeManager.currentTheme.mainBackgroundColor.color }

    // MARK: - Subviews
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Medication")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(textColor)
            Text("Add a new medication with tracking and reminders")
                .font(.subheadline)
                .foregroundColor(subduedTextColor)
        }
        .padding(.horizontal)
        .padding(.top)
    }

    private var presetPickerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose from common medications (or enter custom)")
                .font(.subheadline)
                .foregroundColor(subduedTextColor)
            Picker("Medication Preset", selection: $selectedPresetIndex) {
                Text("Custom").tag(-1)
                ForEach(presets.indices, id: \.self) { idx in
                    Text(presets[idx].name).tag(idx)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(faintTextStrokeColor, lineWidth: 1)
            )
            .onChange(of: selectedPresetIndex) {
                applySelectedPreset()
            }
        }
        .padding(.horizontal)
    }

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic Information")
                .font(.headline)
                .foregroundColor(textColor)
            VStack(spacing: 16) {
                FloatingLabelTextField(
                    title: "Medication Name *",
                    text: $name,
                    isSecure: false
                )
                dosageInput
                frequencyInput
                FloatingLabelTextField(
                    title: "Instructions (e.g., Take with food)",
                    text: $instructions,
                    isSecure: false
                )
            }
        }
        .padding(.horizontal)
    }

    private var dosageInput: some View {
        Group {
            if selectedPresetIndex >= 0 && selectedPresetIndex < presets.count {
                Picker("Dosage", selection: $dosage) {
                    Text("Select dosage").tag("")
                    ForEach(presets[selectedPresetIndex].common_dosages, id: \.self) { d in
                        Text(d).tag(d)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(faintTextStrokeColor, lineWidth: 1)
                )
            } else {
                FloatingLabelTextField(
                    title: "Dosage (e.g., 500mg, 1 tablet)",
                    text: $dosage,
                    isSecure: false
                )
            }
        }
    }

    private var frequencyInput: some View {
        Group {
            if selectedPresetIndex >= 0 && selectedPresetIndex < presets.count {
                Picker("Frequency", selection: $frequency) {
                    Text("Select frequency").tag("")
                    ForEach(presets[selectedPresetIndex].common_frequencies, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
            } else {
                Picker("Frequency", selection: $frequency) {
                    Text("Select frequency").tag("")
                    ForEach(frequencyOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
            }
        }
        .pickerStyle(MenuPickerStyle())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(faintTextStrokeColor, lineWidth: 1)
        )
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Schedule")
                .font(.headline)
                .foregroundColor(textColor)
            VStack(spacing: 16) {
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(CompactDatePickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Toggle("Set End Date", isOn: $showingEndDatePicker)
                        .foregroundColor(textColor)
                    Spacer()
                }
                if showingEndDatePicker {
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Toggle("Active Medication", isOn: $isActive)
                        .foregroundColor(textColor)
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
    }

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reminders")
                .font(.headline)
                .foregroundColor(textColor)
            VStack(spacing: 16) {
                HStack {
                    Toggle("Enable Reminders", isOn: $reminderEnabled)
                        .foregroundColor(textColor)
                    Spacer()
                }
                if reminderEnabled {
                    DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(CompactDatePickerStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("You'll receive notifications at this time each day")
                        .font(.caption)
                        .foregroundColor(captionTextColor)
                }
            }
        }
        .padding(.horizontal)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Additional Notes")
                .font(.headline)
                .foregroundColor(textColor)
            FloatingLabelTextField(
                title: "Notes (side effects, special instructions, etc.)",
                text: $notes,
                isSecure: false
            )
        }
        .padding(.horizontal)
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

    private func fetchPresets() {
        APIService.shared.fetchMedicationPresets { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let presetList):
                    self.presets = presetList
                case .failure(let error):
                    print("❌ Failed to load medication presets: \(error.localizedDescription)")
                }
            }
        }
    }

    private func applySelectedPreset() {
        guard selectedPresetIndex >= 0 && selectedPresetIndex < presets.count else { return }
        let preset = presets[selectedPresetIndex]
        if name.isEmpty { name = preset.name }
        if dosage.isEmpty, let def = preset.default_dosage { dosage = def }
        if frequency.isEmpty, let defF = preset.default_frequency { frequency = defF }
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