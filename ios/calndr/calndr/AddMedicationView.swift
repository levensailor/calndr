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

    // Wheel options and selections for dosage
    @State private var dosageNumberOptions: [String] = ["2.5","5","6.25","10","12.5","25","50","80","100","125","160","200","240","250","320","400","500"]
    @State private var dosageUnitOptions: [String] = ["mg","ml","tablet","puff"]
    @State private var dosageNumberSelection: String = "160"
    @State private var dosageUnitSelection: String = "mg"

    // Wheel options and selections for frequency (every X [hours|days])
    @State private var frequencyNumberSelection: Int = 6
    @State private var frequencyUnitOptions: [String] = ["hours","days"]
    @State private var frequencyUnitSelection: String = "hours"
    
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
            // Sticky bottom submit bar for clear action
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button(action: { saveMedication() }) {
                        Text(name.isEmpty ? "Enter name to add" : "Add Medication")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .disabled(name.isEmpty)
                    .background((name.isEmpty ? Color.gray : themeManager.currentTheme.accentColor.color))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(.ultraThinMaterial)
            }
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
                combinedDosageFrequencyInput
            }
        }
        .padding(.horizontal)
    }

    private var dosageInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dosage")
                .font(.subheadline)
                .foregroundColor(subduedTextColor)
            HStack(alignment: .center, spacing: 16) {
                Picker("Dosage Number", selection: $dosageNumberSelection) {
                    ForEach(dosageNumberOptions, id: \.self) { val in
                        Text(val)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(maxWidth: .infinity)
                .clipped()

                Picker("Dosage Unit", selection: $dosageUnitSelection) {
                    ForEach(dosageUnitOptions, id: \.self) { unit in
                        Text(unit)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(faintTextStrokeColor, lineWidth: 1)
            )
        }
        .onChange(of: dosageNumberSelection) { updateDosageFromWheel() }
        .onChange(of: dosageUnitSelection) { updateDosageFromWheel() }
    }

    private var frequencyInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Frequency")
                .font(.subheadline)
                .foregroundColor(subduedTextColor)
            HStack(alignment: .center, spacing: 16) {
                Text("Every")
                    .foregroundColor(textColor)
                Picker("Frequency Number", selection: $frequencyNumberSelection) {
                    ForEach(1...24, id: \.self) { n in
                        Text("\(n)")
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(maxWidth: .infinity)
                .clipped()

                Picker("Frequency Unit", selection: $frequencyUnitSelection) {
                    ForEach(frequencyUnitOptions, id: \.self) { unit in
                        Text(unit)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(faintTextStrokeColor, lineWidth: 1)
            )
        }
        .onChange(of: frequencyNumberSelection) { updateFrequencyFromWheel() }
        .onChange(of: frequencyUnitSelection) { updateFrequencyFromWheel() }
    }

    // Combined dosage + frequency wheels with assumed units (mg, hours)
    private var combinedDosageFrequencyInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Dosage & Frequency")
                    .font(.subheadline)
                    .foregroundColor(subduedTextColor)
                Spacer()
                Text("mg / hours assumed")
                    .font(.caption)
                    .foregroundColor(captionTextColor)
            }
            HStack(alignment: .center, spacing: 16) {
                // Dose number wheel
                VStack {
                    Text("Dose")
                        .font(.caption)
                        .foregroundColor(subduedTextColor)
                    Picker("Dosage Number", selection: $dosageNumberSelection) {
                        ForEach(dosageNumberOptions, id: \.self) { val in
                            Text(val)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                }
                .frame(maxWidth: .infinity)
                .clipped()

                // Every hours wheel
                VStack {
                    Text("Every")
                        .font(.caption)
                        .foregroundColor(subduedTextColor)
                    Picker("Frequency Number", selection: $frequencyNumberSelection) {
                        ForEach(1...24, id: \.self) { n in
                            Text("\(n)")
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                }
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(faintTextStrokeColor, lineWidth: 1)
            )
            HStack(spacing: 16) {
                Label("mg assumed", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(captionTextColor)
                Label("hours assumed", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(captionTextColor)
            }
        }
        .onChange(of: dosageNumberSelection) { updateDosageFromWheel() }
        .onChange(of: frequencyNumberSelection) { updateFrequencyFromWheel() }
        .onAppear {
            if !dosage.isEmpty { parseDosageToWheel(dosage) }
            if !frequency.isEmpty { parseFrequencyToWheel(frequency) }
            updateDosageFromWheel()
            updateFrequencyFromWheel()
        }
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
            frequency: normalizedFrequencyValue(from: frequency),
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
        if dosage.isEmpty, let def = preset.default_dosage {
            dosage = def
            parseDosageToWheel(def)
        }
        if frequency.isEmpty, let defF = preset.default_frequency {
            frequency = defF
            parseFrequencyToWheel(defF)
        }
    }

    // MARK: - Frequency normalization
    // Convert UI labels like "Every 6 hours" to numeric hour string expected by backend (e.g., "6").
    // Returns nil for PRN/as-needed and when not set.
    private func normalizedFrequencyValue(from uiLabel: String) -> String? {
        let trimmed = uiLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let lower = trimmed.lowercased()
        switch lower {
        case "once daily":
            return String(24)
        case "twice daily":
            return String(12)
        case "three times daily":
            return String(8)
        case "as needed":
            return nil
        case "weekly":
            return String(7 * 24)
        case "monthly":
            return String(30 * 24)
        default:
            // Parse patterns like "every X hours"
            if lower.hasPrefix("every ") && lower.hasSuffix(" hours") {
                let middle = lower.dropFirst("every ".count).dropLast(" hours".count)
                if let hours = Int(middle.trimmingCharacters(in: .whitespaces)) {
                    return String(hours)
                }
            }
            // Parse patterns like "every X days"
            if lower.hasPrefix("every ") && lower.hasSuffix(" days") {
                let middle = lower.dropFirst("every ".count).dropLast(" days".count)
                if let days = Int(middle.trimmingCharacters(in: .whitespaces)) {
                    return String(days * 24)
                }
            }
            // If preset provided plain number already, pass through
            if let hours = Int(lower) { return String(hours) }
            return nil
        }
    }

    // MARK: - Wheel helpers
    private func updateDosageFromWheel() {
        dosage = "\(dosageNumberSelection) mg"
    }
    private func updateFrequencyFromWheel() {
        frequency = "Every \(frequencyNumberSelection) hours"
    }
    private func parseDosageToWheel(_ value: String) {
        let parts = value.split(separator: " ")
        if let first = parts.first { dosageNumberSelection = String(first) }
    }
    private func parseFrequencyToWheel(_ value: String) {
        let lower = value.lowercased().trimmingCharacters(in: .whitespaces)
        if lower.hasPrefix("every ") {
            if lower.hasSuffix(" hours") {
                let middle = lower.dropFirst("every ".count).dropLast(" hours".count)
                if let n = Int(middle.trimmingCharacters(in: .whitespaces)) {
                    frequencyNumberSelection = n
                }
            }
        } else if let n = Int(lower) {
            frequencyNumberSelection = n
        }
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