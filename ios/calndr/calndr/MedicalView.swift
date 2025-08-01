import SwiftUI
import CoreLocation
import MapKit

struct MedicalView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab = 0
    @State private var showingAddDoctor = false
    @State private var showingAddMedication = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Medical")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                    
                    Text("Manage doctors, medications, and health tracking")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Tab Picker
                Picker("Medical Section", selection: $selectedTab) {
                    Text("Doctors").tag(0)
                    Text("Medications").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Tab Content
                TabView(selection: $selectedTab) {
                    // Doctors Tab
                    DoctorsTabView(
                        showingAddDoctor: $showingAddDoctor
                    )
                    .tag(0)
                    
                    // Medications Tab
                    MedicationsTabView(
                        showingAddMedication: $showingAddMedication
                    )
                    .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .background(themeManager.currentTheme.mainBackgroundColor.color)
        }
        .sheet(isPresented: $showingAddDoctor) {
            AddDoctorView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingAddMedication) {
            AddMedicationView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
    }
}

// MARK: - Doctors Tab View
struct DoctorsTabView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var showingAddDoctor: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Add Button
                HStack {
                    Spacer()
                    Button(action: { showingAddDoctor = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Doctor")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Medical Providers List
                if viewModel.medicalProviders.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "cross.case.fill")
                            .font(.largeTitle)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.3))
                        
                        Text("No doctors added yet")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                        
                        Text("Add your first doctor to get started")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(viewModel.medicalProviders) { provider in
                        MedicalProviderCard(provider: provider)
                            .padding(.horizontal)
                            .environmentObject(viewModel)
                    }
                }
                
                Spacer(minLength: 80)
            }
        }
        .scrollTargetBehavior(CustomVerticalPagingBehavior())
    }
}

// MARK: - Medications Tab View
struct MedicationsTabView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var showingAddMedication: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Add Button
                HStack {
                    Spacer()
                    Button(action: { showingAddMedication = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Medication")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Medications List
                if viewModel.medications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "pills.fill")
                            .font(.largeTitle)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.3))
                        
                        Text("No medications added yet")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                        
                        Text("Add your first medication to get started")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(viewModel.medications) { medication in
                        MedicationCard(medication: medication)
                            .padding(.horizontal)
                            .environmentObject(viewModel)
                    }
                }
                
                Spacer(minLength: 80)
            }
        }
        .scrollTargetBehavior(CustomVerticalPagingBehavior())
    }
}

// MARK: - Medical Provider Card
struct MedicalProviderCard: View {
    let provider: MedicalProvider
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: CalendarViewModel
    @State private var showingDeleteAlert = false
    
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
                
                Button(action: { showingDeleteAlert = true }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            if let address = provider.address {
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                    Text(address)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.8))
                }
            }
            
            if let phone = provider.phone {
                HStack {
                    Image(systemName: "phone")
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                    Text(phone)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.8))
                }
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
    }
}

// MARK: - Medication Card
struct MedicationCard: View {
    let medication: Medication
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: CalendarViewModel
    @State private var showingDeleteAlert = false
    
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
                        Text(dosage)
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Active/Inactive indicator
                Circle()
                    .fill(medication.isActive ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                
                Button(action: { showingDeleteAlert = true }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            if let frequency = medication.frequency {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                    Text(frequency)
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