import SwiftUI

struct SittersView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAddBabysitter = false
    @State private var showingAddEmergencyContact = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sitters & Contacts")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.currentTheme.textColor)
                        
                        Text("Manage babysitters and emergency contacts")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                    }
                    .padding(.horizontal)
                    
                    // Babysitters Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Babysitters")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(themeManager.currentTheme.textColor)
                            
                            Spacer()
                            
                            Button(action: { showingAddBabysitter = true }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.horizontal)
                        
                        if viewModel.babysitters.isEmpty {
                            Text("No babysitters added yet")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                                .padding(.horizontal)
                        } else {
                            ForEach(viewModel.babysitters) { babysitter in
                                BabysitterCard(babysitter: babysitter)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Emergency Contacts Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Emergency Contacts")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(themeManager.currentTheme.textColor)
                            
                            Spacer()
                            
                            Button(action: { showingAddEmergencyContact = true }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal)
                        
                        if viewModel.emergencyContacts.isEmpty {
                            Text("No emergency contacts added yet")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                                .padding(.horizontal)
                        } else {
                            ForEach(viewModel.emergencyContacts) { contact in
                                EmergencyContactCard(contact: contact)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    
                    Spacer(minLength: 80)
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor)
            .navigationTitle("Sitters & Contacts")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingAddBabysitter) {
            AddBabysitterView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingAddEmergencyContact) {
            AddEmergencyContactView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
    }
}

struct BabysitterCard: View {
    let babysitter: Babysitter
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.crop.circle")
                    .font(.title2)
                    .foregroundColor(.orange)
                    .frame(width: 30, height: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(babysitter.fullName)
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor)
                    
                    Text(babysitter.formattedRate)
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                }
                
                Spacer()
                
                Button(action: {
                    if let phoneURL = URL(string: "tel:\(babysitter.phone_number)") {
                        UIApplication.shared.open(phoneURL)
                    }
                }) {
                    Image(systemName: "phone.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                }
            }
            
            if let notes = babysitter.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.otherMonthBackgroundColor)
                .shadow(color: themeManager.currentTheme.textColor.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

struct EmergencyContactCard: View {
    let contact: EmergencyContact
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                    .frame(width: 30, height: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(contact.fullName)
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor)
                    
                    Text(contact.displayRelationship)
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                }
                
                Spacer()
                
                Button(action: {
                    if let phoneURL = URL(string: "tel:\(contact.phone_number)") {
                        UIApplication.shared.open(phoneURL)
                    }
                }) {
                    Image(systemName: "phone.fill")
                        .font(.title3)
                        .foregroundColor(.red)
                }
            }
            
            if let notes = contact.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.otherMonthBackgroundColor)
                .shadow(color: themeManager.currentTheme.textColor.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

struct AddBabysitterView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phoneNumber = ""
    @State private var rate = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Babysitter Information") {
                    FloatingLabelTextField(
                        title: "First Name",
                        text: $firstName,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    
                    FloatingLabelTextField(
                        title: "Last Name",
                        text: $lastName,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    
                    FloatingLabelTextField(
                        title: "Phone Number",
                        text: $phoneNumber,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    .keyboardType(.phonePad)
                    
                    FloatingLabelTextField(
                        title: "Hourly Rate (Optional)",
                        text: $rate,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    .keyboardType(.decimalPad)
                    
                    FloatingLabelTextField(
                        title: "Notes (Optional)",
                        text: $notes,
                        isSecure: false,
                        themeManager: themeManager
                    )
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor)
            .navigationTitle("Add Babysitter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // TODO: Implement save functionality
                        dismiss()
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty || phoneNumber.isEmpty)
                }
            }
        }
    }
}

struct AddEmergencyContactView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phoneNumber = ""
    @State private var relationship = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Emergency Contact Information") {
                    FloatingLabelTextField(
                        title: "First Name",
                        text: $firstName,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    
                    FloatingLabelTextField(
                        title: "Last Name",
                        text: $lastName,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    
                    FloatingLabelTextField(
                        title: "Phone Number",
                        text: $phoneNumber,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    .keyboardType(.phonePad)
                    
                    FloatingLabelTextField(
                        title: "Relationship (Optional)",
                        text: $relationship,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    
                    FloatingLabelTextField(
                        title: "Notes (Optional)",
                        text: $notes,
                        isSecure: false,
                        themeManager: themeManager
                    )
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor)
            .navigationTitle("Add Emergency Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // TODO: Implement save functionality
                        dismiss()
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty || phoneNumber.isEmpty)
                }
            }
        }
    }
}

struct SittersView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager)
        
        SittersView()
            .environmentObject(calendarViewModel)
            .environmentObject(ThemeManager())
    }
} 