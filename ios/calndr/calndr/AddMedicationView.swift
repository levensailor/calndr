import SwiftUI

struct AddMedicationView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var dosage = ""
    @State private var frequency = ""
    // Removed instructions/start/end date from UI; use sensible defaults on save
    @State private var startDate = Date()
    @State private var isActive = true
    @State private var reminderEnabled = false
    @State private var reminderTime = Date()
    @State private var notes = ""
    @State private var presets: [MedicationPreset] = [] // From backend
    // -1 = Custom, otherwise index into presets
    @State private var selectedPresetIndex: Int = -1
    @State private var familyCustomPresetNames: [String] = []
    
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
    
    // User-requested common medications prepopulated
    private let defaultCommonMedicationNames: [String] = [
        "Acetaminophen (Tylenol)",
        "Ibuprofen (Motrin)",
        "Diphenhydramine (Dimetapp)",
        "Amoxicillin",
        "Prednisone",
        "Albuterol",
        "Zyrtec",
        "Allegra"
    ]
    
    // Combined presets list built from defaults + backend + family custom list
    private var allPresetList: [MedicationPreset] {
        var combined: [MedicationPreset] = []
        // Defaults
        for n in defaultCommonMedicationNames {
            combined.append(MedicationPreset(name: n, common_dosages: [], common_frequencies: [], default_dosage: nil, default_frequency: nil, aliases: nil))
        }
        // Backend presets
        combined.append(contentsOf: presets)
        // Family custom names
        for n in familyCustomPresetNames {
            // Avoid duplicating if already present
            if !combined.contains(where: { $0.name.caseInsensitiveCompare(n) == .orderedSame }) {
                combined.append(MedicationPreset(name: n, common_dosages: [], common_frequencies: [], default_dosage: nil, default_frequency: nil, aliases: nil))
            }
        }
        // Deduplicate by name while preserving order
        var seen = Set<String>()
        let deduped = combined.filter { preset in
            let key = preset.name.lowercased()
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
        return deduped
    }
    
    private var currentSelectedPreset: MedicationPreset? {
        guard selectedPresetIndex >= 0 && selectedPresetIndex < allPresetList.count else { return nil }
        return allPresetList[selectedPresetIndex]
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerView
                    presetPickerView
                    basicInfoSection
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
            Text("Choose a medication or enter a custom one")
                .font(.subheadline)
                .foregroundColor(subduedTextColor)
            Picker("Medication Preset", selection: $selectedPresetIndex) {
                Text("Custom").tag(-1)
                ForEach(allPresetList.indices, id: \.self) { idx in
                    Text(allPresetList[idx].name).tag(idx)
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
            // Quick helper text for custom entries
            if selectedPresetIndex == -1 {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(themeManager.currentTheme.accentColor.color)
                    Text("Type a custom name below. You can add it to your family's list for future use.")
                        .font(.caption)
                        .foregroundColor(subduedTextColor)
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.horizontal)
    }

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Medication Details")
                .font(.headline)
                .foregroundColor(textColor)
            VStack(spacing: 16) {
                FloatingLabelTextField(
                    title: "Medication Name *",
                    text: $name,
                    isSecure: false
                )
                // Add to My List button for custom names
                if selectedPresetIndex == -1 && !name.isEmpty {
                    Button(action: addCustomNameToFamilyList) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.white)
                            Text("Add to My Family List")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(themeManager.currentTheme.accentColor.color)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                dosageInput
                frequencyInput
            }
        }
        .padding(.horizontal)
    }

    private var dosageInput: some View {
        Group {
            if let preset = currentSelectedPreset, !preset.common_dosages.isEmpty {
                Picker("Dosage", selection: $dosage) {
                    Text("Select dosage").tag("")
                    ForEach(preset.common_dosages, id: \.self) { d in
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
            if let preset = currentSelectedPreset, !preset.common_frequencies.isEmpty {
                Picker("Frequency", selection: $frequency) {
                    Text("Select frequency").tag("")
                    ForEach(preset.common_frequencies, id: \.self) { option in
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
                    DatePicker("Next Dose", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(CompactDatePickerStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("You'll receive reminders for each dose")
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
            instructions: nil,
            startDate: dateFormatter.string(from: startDate),
            endDate: nil,
            isActive: isActive,
            reminderEnabled: reminderEnabled,
            reminderTime: reminderEnabled ? timeFormatter.string(from: reminderTime) : nil,
            notes: notes.isEmpty ? nil : notes
        )
        
        viewModel.saveMedication(medicationData) { success in
            DispatchQueue.main.async {
                if success {
                    print("✅ Successfully saved medication: \(name)")
                    if reminderEnabled {
                        NotificationManager.shared.scheduleMedicationReminders(
                            medicationName: name,
                            nextDose: reminderTime,
                            frequency: frequency
                        )
                    }
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
                    self.familyCustomPresetNames = loadFamilyCustomPresetNames()
                case .failure(let error):
                    print("❌ Failed to load medication presets: \(error.localizedDescription)")
                    self.familyCustomPresetNames = loadFamilyCustomPresetNames()
                }
            }
        }
    }

    private func applySelectedPreset() {
        guard let preset = currentSelectedPreset else { return }
        if name.isEmpty { name = preset.name }
        if dosage.isEmpty, let def = preset.default_dosage { dosage = def }
        if frequency.isEmpty, let defF = preset.default_frequency { frequency = defF }
    }

    // MARK: - Family custom preset persistence (local, per-family)
    private func addCustomNameToFamilyList() {
        let customName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !customName.isEmpty else { return }
        var current = loadFamilyCustomPresetNames()
        if !current.contains(where: { $0.caseInsensitiveCompare(customName) == .orderedSame }) {
            current.append(customName)
            saveFamilyCustomPresetNames(current)
            familyCustomPresetNames = current
            print("✅ Added custom medication to family list: \(customName)")
        }
    }
    
    private func loadFamilyCustomPresetNames() -> [String] {
        guard let familyId = AuthenticationService.shared.familyId else { return [] }
        let key = "family.custom.medication.presets.\(familyId)"
        if let data = UserDefaults.standard.array(forKey: key) as? [String] {
            return data
        }
        return []
    }
    
    private func saveFamilyCustomPresetNames(_ names: [String]) {
        guard let familyId = AuthenticationService.shared.familyId else { return }
        let key = "family.custom.medication.presets.\(familyId)"
        UserDefaults.standard.set(names, forKey: key)
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