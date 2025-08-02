import SwiftUI
import CoreLocation
import MapKit

struct MedicalView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAddDoctor = false
    @State private var showingAddMedication = false
    
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
                            showingAddDoctor = true
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
                                showingAddDoctor = true
                            }) {
                                Text("Add Provider")
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(themeManager.currentTheme.accentColor.color)
                                    .foregroundColor(themeManager.currentTheme.textOnAccentColor.color)
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
                            showingAddMedication = true
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
                                showingAddMedication = true
                            }) {
                                Text("Add Medication")
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(themeManager.currentTheme.accentColor.color)
                                    .foregroundColor(themeManager.currentTheme.textOnAccentColor.color)
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
            }
            .padding(.vertical)
        }
        .background(themeManager.currentTheme.mainBackgroundColor.color)
        .navigationTitle("Medical")
        .navigationBarTitleDisplayMode(.inline)
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