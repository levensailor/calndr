import SwiftUI
import CoreLocation
import MapKit

struct MedicalView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var activeSheet: MedicalSheet?

    enum MedicalSheet: Identifiable {
        case doctor
        case medication
        case pharmacy

        var id: String {
            switch self {
            case .doctor: return "doctor"
            case .medication: return "medication"
            case .pharmacy: return "pharmacy"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Medical Providers Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Medical Providers")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.currentTheme.textColor.color)
                        
                        Spacer()
                        
                        Button(action: {
                            activeSheet = .doctor
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(themeManager.currentTheme.accentColor.color)
                        }
                    }
                    
                    if viewModel.medicalProviders.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "cross.case.fill")
                                .font(.largeTitle)
                                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.3))
                            
                            Text("No Medical Providers")
                                .font(.headline)
                                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                            
                            Button(action: {
                                activeSheet = .doctor
                            }) {
                                Text("Add Provider")
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(themeManager.currentTheme.accentColor.color)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                        .cornerRadius(12)
                    } else {
                        ForEach(viewModel.medicalProviders) { provider in
                            MedicalProviderCard(provider: provider)
                        }
                    }
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.horizontal)
                
                // Medications Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Medications")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.currentTheme.textColor.color)
                        
                        Spacer()
                        
                        Button(action: {
                            activeSheet = .medication
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(themeManager.currentTheme.accentColor.color)
                        }
                    }
                    
                    if viewModel.medications.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "pills.fill")
                                .font(.largeTitle)
                                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.3))
                            
                            Text("No Medications")
                                .font(.headline)
                                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                            
                            Button(action: {
                                activeSheet = .medication
                            }) {
                                Text("Add Medication")
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(themeManager.currentTheme.accentColor.color)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                        .cornerRadius(12)
                    } else {
                        ForEach(viewModel.medications) { medication in
                            MedicationCard(medication: medication)
                        }
                    }
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.horizontal)
                
                // Pharmacies Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Pharmacies")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.currentTheme.textColor.color)
                        
                        Spacer()
                        
                        Button(action: {
                            activeSheet = .pharmacy
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(themeManager.currentTheme.accentColor.color)
                        }
                    }
                    
                    if viewModel.pharmacies.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "cross.vial.fill")
                                .font(.largeTitle)
                                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.3))
                            
                            Text("No Pharmacies")
                                .font(.headline)
                                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                            
                            Button(action: {
                                activeSheet = .pharmacy
                            }) {
                                Text("Add Pharmacy")
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(themeManager.currentTheme.accentColor.color)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                        .cornerRadius(12)
                    } else {
                        ForEach(viewModel.pharmacies) { pharmacy in
                            PharmacyCard(pharmacy: pharmacy)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(themeManager.currentTheme.mainBackgroundColor.color)
        .navigationTitle("Medical")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel.medicalProviders.isEmpty {
                viewModel.fetchMedicalProviders()
            }
            if viewModel.medications.isEmpty {
                viewModel.fetchMedications()
            }
        }
        .sheet(item: $activeSheet) { item in
            switch item {
            case .doctor:
                AddDoctorView()
                    .environmentObject(viewModel)
                    .environmentObject(themeManager)
            case .medication:
                AddMedicationView()
                    .environmentObject(viewModel)
                    .environmentObject(themeManager)
            case .pharmacy:
                AddPharmacyView()
                    .environmentObject(viewModel)
                    .environmentObject(themeManager)
            }
        }
    }
}



// MARK: - Medical Provider Card
struct MedicalProviderCard: View {
    let provider: MedicalProvider
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: CalendarViewModel
    @State private var showingDeleteAlert = false
    @State private var showingEditView = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cross.case.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                    .frame(width: 30, height: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.name)
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                    
                    if let specialty = provider.specialty {
                        Text(specialty)
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: { showingEditView = true }) {
                        Image(systemName: "pencil")
                            .foregroundColor(themeManager.currentTheme.accentColor.color)
                    }
                    
                    Button(action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            
            if let address = provider.address {
                Button(action: {
                    openMapsForDirections(to: address)
                }) {
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(themeManager.currentTheme.accentColor.color)
                        Text(address)
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.8))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundColor(themeManager.currentTheme.accentColor.color)
                            .font(.caption2)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if let phone = provider.phone {
                Button(action: {
                    makePhoneCall(to: phone)
                }) {
                    HStack {
                        Image(systemName: "phone")
                            .foregroundColor(themeManager.currentTheme.accentColor.color)
                        Text(phone)
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.8))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundColor(themeManager.currentTheme.accentColor.color)
                            .font(.caption2)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if let notes = provider.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                .shadow(color: themeManager.currentTheme.textColor.color.opacity(0.1), radius: 3, x: 0, y: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture { showingEditView = true }
        .alert("Delete Doctor", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteMedicalProvider(provider) { success in
                    if success {
                        print("✅ Successfully deleted medical provider: \(provider.name)")
                    } else {
                        print("❌ Failed to delete medical provider: \(provider.name)")
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete \(provider.name)? This action cannot be undone.")
        }
        .sheet(isPresented: $showingEditView) {
            EditMedicalProviderView(provider: provider)
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
    }
    
    private func makePhoneCall(to phoneNumber: String) {
        // Clean the phone number - remove spaces, dashes, parentheses
        let cleanNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        if let phoneURL = URL(string: "tel://\(cleanNumber)") {
            if UIApplication.shared.canOpenURL(phoneURL) {
                UIApplication.shared.open(phoneURL)
                print("📞 Opening phone call to: \(phoneNumber)")
            } else {
                print("❌ Device cannot make phone calls")
            }
        }
    }
    
    private func openMapsForDirections(to address: String) {
        // URL encode the address
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Try to open in Apple Maps first
        if let mapsURL = URL(string: "http://maps.apple.com/?daddr=\(encodedAddress)") {
            if UIApplication.shared.canOpenURL(mapsURL) {
                UIApplication.shared.open(mapsURL)
                print("🗺️ Opening Apple Maps for directions to: \(address)")
                return
            }
        }
        
        // Fallback to Google Maps if available
        if let googleMapsURL = URL(string: "comgooglemaps://?daddr=\(encodedAddress)") {
            if UIApplication.shared.canOpenURL(googleMapsURL) {
                UIApplication.shared.open(googleMapsURL)
                print("🗺️ Opening Google Maps for directions to: \(address)")
                return
            }
        }
        
        // Final fallback to web-based maps
        if let webMapsURL = URL(string: "https://maps.google.com/maps?daddr=\(encodedAddress)") {
            UIApplication.shared.open(webMapsURL)
            print("🗺️ Opening web maps for directions to: \(address)")
        }
    }
}

// MARK: - Medication Card
struct MedicationCard: View {
    let medication: Medication
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: CalendarViewModel
    @State private var showingDeleteAlert = false
    @State private var showingEditView = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "pills.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                    .frame(width: 30, height: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(medication.name)
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                    
                    if let dosage = medication.dosage {
                        Text(formattedDosage(dosage))
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Active/Inactive indicator
                Circle()
                    .fill(medication.isActive ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                
                Button(action: { showingEditView = true }) {
                    Image(systemName: "pencil")
                        .foregroundColor(themeManager.currentTheme.accentColor.color)
                }
                
                Button(action: { showingDeleteAlert = true }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            if let frequency = medication.frequency {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                    Text(formattedFrequency(frequency))
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.8))
                }
            }
            
            if let instructions = medication.instructions {
                HStack {
                    Image(systemName: "text.alignleft")
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                    Text(instructions)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.8))
                }
            }
            
            if medication.reminderEnabled, let reminderTime = medication.reminderTime {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.orange)
                    Text("Reminder: \(reminderTime)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            if let notes = medication.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                .shadow(color: themeManager.currentTheme.textColor.color.opacity(0.1), radius: 3, x: 0, y: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture { showingEditView = true }
        .alert("Delete Medication", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteMedication(medication) { success in
                    if success {
                        print("✅ Successfully deleted medication: \(medication.name)")
                    } else {
                        print("❌ Failed to delete medication: \(medication.name)")
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete \(medication.name)? This action cannot be undone.")
        }
        .sheet(isPresented: $showingEditView) {
            EditMedicationView(medication: medication)
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
    }
}

// MARK: - MedicationCard helpers
extension MedicationCard {
    private func formattedDosage(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        // If dosage already includes units like mg/ml/g, return as-is
        if lower.contains("mg") || lower.contains("ml") || lower.contains("g") {
            return trimmed
        }
        // If it's purely numeric (optionally with decimal), append mg
        let digits = lower.replacingOccurrences(of: " ", with: "")
        if CharacterSet(charactersIn: digits).isSubset(of: CharacterSet(charactersIn: "+-0123456789.,")) {
            return "\(trimmed) mg"
        }
        return "\(trimmed) mg"
    }

    private func formattedFrequency(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        // If already includes hour wording, leave as-is
        if lower.contains("hour") {
            return trimmed
        }
        // If numeric hours like "6" or "8", append " hours"
        if Int(lower) != nil {
            return "\(trimmed) hours"
        }
        // Fallback: append hours
        return "\(trimmed) hours"
    }
}

// MARK: - Edit Medication View
struct EditMedicationView: View {
    let medication: Medication
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var dosage: String
    @State private var frequency: String
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date
    @State private var notes: String
    @State private var isActive: Bool

    init(medication: Medication) {
        self.medication = medication
        _name = State(initialValue: medication.name)
        _dosage = State(initialValue: medication.dosage ?? "")
        _frequency = State(initialValue: medication.frequency ?? "")
        _reminderEnabled = State(initialValue: medication.reminderEnabled)
        // Parse HH:mm into Date (today) if available; else now
        if let hhmm = medication.reminderTime,
           let date = EditMedicationView.parseHHMMToToday(hhmm) {
            _reminderTime = State(initialValue: date)
        } else {
            _reminderTime = State(initialValue: Date())
        }
        _notes = State(initialValue: medication.notes ?? "")
        _isActive = State(initialValue: medication.isActive)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Medication Details")
                    .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))) {
                    FloatingLabelTextField(title: "Name", text: $name, isSecure: false)
                    FloatingLabelTextField(title: "Dosage", text: $dosage, isSecure: false)
                    FloatingLabelTextField(title: "Frequency", text: $frequency, isSecure: false)
                    FloatingLabelTextField(title: "Notes", text: $notes, isSecure: false)
                    Toggle("Active", isOn: $isActive)
                        .tint(themeManager.currentTheme.accentColor.color)
                }

                Section(header: Text("Reminders")
                    .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))) {
                    Toggle("Enable Reminders", isOn: $reminderEnabled)
                        .tint(themeManager.currentTheme.accentColor.color)
                    if reminderEnabled {
                        DatePicker("Next Dose", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(CompactDatePickerStyle())
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(themeManager.currentTheme.mainBackgroundColorSwiftUI)
            .preferredColorScheme(themeManager.currentTheme.preferredColorScheme)
            .navigationTitle("Edit Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveChanges() }
                        .foregroundColor(themeManager.currentTheme.accentColor.color)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveChanges() {
        // Normalize reminder time HH:mm
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let reminderHHMM = reminderEnabled ? timeFormatter.string(from: reminderTime) : nil

        // Normalize frequency to numeric hours where possible
        let normalizedFreq = normalizedFrequencyValue(from: frequency)

        let update = MedicationUpdate(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            dosage: dosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : dosage,
            frequency: normalizedFreq,
            instructions: nil,
            startDate: nil,
            endDate: nil,
            isActive: isActive,
            reminderEnabled: reminderEnabled,
            reminderTime: reminderHHMM,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        )

        viewModel.updateMedication(id: Int(medication.id) ?? 0, medication: update)
    }

    private func normalizedFrequencyValue(from uiLabel: String) -> String? {
        let trimmed = uiLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let lower = trimmed.lowercased()
        switch lower {
        case "once daily": return String(24)
        case "twice daily": return String(12)
        case "three times daily": return String(8)
        case "as needed": return nil
        case "weekly": return String(7 * 24)
        case "monthly": return String(30 * 24)
        default:
            if lower.hasPrefix("every ") && lower.hasSuffix(" hours") {
                let middle = lower.dropFirst("every ".count).dropLast(" hours".count)
                if let hours = Int(middle.trimmingCharacters(in: .whitespaces)) {
                    return String(hours)
                }
            }
            if let hours = Int(lower) { return String(hours) }
            return nil
        }
    }

    private static func parseHHMMToToday(_ hhmm: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let calendar = Calendar.current
        if let timeDate = formatter.date(from: hhmm) {
            let comps = calendar.dateComponents([.hour, .minute], from: timeDate)
            var today = calendar.dateComponents([.year, .month, .day], from: Date())
            today.hour = comps.hour
            today.minute = comps.minute
            return calendar.date(from: today)
        }
        return nil
    }
}

// MARK: - Edit Medical Provider View
struct EditMedicalProviderView: View {
    let provider: MedicalProvider
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var specialty: String
    @State private var address: String
    @State private var phone: String
    @State private var email: String
    @State private var website: String
    @State private var notes: String
    
    init(provider: MedicalProvider) {
        self.provider = provider
        self._name = State(initialValue: provider.name)
        self._specialty = State(initialValue: provider.specialty ?? "")
        self._address = State(initialValue: provider.address ?? "")
        self._phone = State(initialValue: provider.phone ?? "")
        self._email = State(initialValue: provider.email ?? "")
        self._website = State(initialValue: provider.website ?? "")
        self._notes = State(initialValue: provider.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Medical Provider Information")
                    .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))) {
                    FloatingLabelTextField(
                        title: "Provider Name",
                        text: $name,
                        isSecure: false
                    )
                    
                    FloatingLabelTextField(
                        title: "Specialty (Optional)",
                        text: $specialty,
                        isSecure: false
                    )
                    
                    FloatingLabelTextField(
                        title: "Address (Optional)",
                        text: $address,
                        isSecure: false
                    )
                    
                    FloatingLabelTextField(
                        title: "Phone Number (Optional)",
                        text: $phone,
                        isSecure: false
                    )
                    .keyboardType(.phonePad)
                    
                    FloatingLabelTextField(
                        title: "Email (Optional)",
                        text: $email,
                        isSecure: false
                    )
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    
                    FloatingLabelTextField(
                        title: "Website (Optional)",
                        text: $website,
                        isSecure: false
                    )
                    .keyboardType(.URL)
                    .autocapitalization(.none)

                    FloatingLabelTextField(
                        title: "Notes (Optional)",
                        text: $notes,
                        isSecure: false
                    )
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
            }
            .scrollContentBackground(.hidden)
            .background(themeManager.currentTheme.mainBackgroundColorSwiftUI)
            .preferredColorScheme(themeManager.currentTheme.preferredColorScheme)
            .navigationTitle("Edit Provider")
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
                        saveChanges()
                    }
                    .disabled(name.isEmpty)
                    .foregroundColor(themeManager.currentTheme.accentColor.color)
                }
            }
        }
    }
    
    private func saveChanges() {
        let updatedProvider = MedicalProviderUpdate(
            name: name,
            specialty: specialty.isEmpty ? nil : specialty,
            address: address.isEmpty ? nil : address,
            phone: phone.isEmpty ? nil : phone,
            email: email.isEmpty ? nil : email,
            website: website.isEmpty ? nil : website,
            latitude: provider.latitude,
            longitude: provider.longitude,
            zipCode: provider.zipCode,
            notes: notes.isEmpty ? nil : notes
        )
        
        viewModel.updateMedicalProvider(id: provider.id, provider: updatedProvider) { success in
            DispatchQueue.main.async {
                if success {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Pharmacy Card
struct PharmacyCard: View {
    let pharmacy: MedicalProvider
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: CalendarViewModel
    @State private var showingDeleteAlert = false
    @State private var showingEditView = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cross.vial.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 30, height: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(pharmacy.name)
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                    
                    if let specialty = pharmacy.specialty {
                        Text(specialty)
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: { showingEditView = true }) {
                        Image(systemName: "pencil")
                            .foregroundColor(themeManager.currentTheme.accentColor.color)
                    }
                    
                    Button(action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            
            if let address = pharmacy.address {
                Button(action: {
                    openMapsForDirections(to: address)
                }) {
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(themeManager.currentTheme.accentColor.color)
                        Text(address)
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.8))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundColor(themeManager.currentTheme.accentColor.color)
                            .font(.caption2)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if let phone = pharmacy.phone {
                Button(action: {
                    makePhoneCall(to: phone)
                }) {
                    HStack {
                        Image(systemName: "phone")
                            .foregroundColor(themeManager.currentTheme.accentColor.color)
                        Text(phone)
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.8))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundColor(themeManager.currentTheme.accentColor.color)
                            .font(.caption2)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if let notes = pharmacy.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                .shadow(color: themeManager.currentTheme.textColor.color.opacity(0.1), radius: 3, x: 0, y: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture { showingEditView = true }
        .alert("Delete Pharmacy", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteMedicalProvider(pharmacy) { success in
                    if success {
                        print("✅ Successfully deleted pharmacy: \(pharmacy.name)")
                    } else {
                        print("❌ Failed to delete pharmacy: \(pharmacy.name)")
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete \(pharmacy.name)? This action cannot be undone.")
        }
        .sheet(isPresented: $showingEditView) {
            EditMedicalProviderView(provider: pharmacy)
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
    }
    
    private func makePhoneCall(to phoneNumber: String) {
        let cleanNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        if let phoneURL = URL(string: "tel://\(cleanNumber)") {
            if UIApplication.shared.canOpenURL(phoneURL) {
                UIApplication.shared.open(phoneURL)
                print("📞 Opening phone call to: \(phoneNumber)")
            } else {
                print("❌ Device cannot make phone calls")
            }
        }
    }
    
    private func openMapsForDirections(to address: String) {
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let mapsURL = URL(string: "http://maps.apple.com/?daddr=\(encodedAddress)") {
            if UIApplication.shared.canOpenURL(mapsURL) {
                UIApplication.shared.open(mapsURL)
                print("🗺️ Opening Apple Maps for directions to: \(address)")
                return
            }
        }
        
        if let googleMapsURL = URL(string: "comgooglemaps://?daddr=\(encodedAddress)") {
            if UIApplication.shared.canOpenURL(googleMapsURL) {
                UIApplication.shared.open(googleMapsURL)
                print("🗺️ Opening Google Maps for directions to: \(address)")
                return
            }
        }
        
        if let webMapsURL = URL(string: "https://maps.google.com/maps?daddr=\(encodedAddress)") {
            UIApplication.shared.open(webMapsURL)
            print("🗺️ Opening web maps for directions to: \(address)")
        }
    }
}

struct MedicalView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let themeManager = ThemeManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager, themeManager: themeManager)
        
        MedicalView()
            .environmentObject(calendarViewModel)
            .environmentObject(themeManager)
    }
} 