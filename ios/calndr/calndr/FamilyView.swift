import SwiftUI
import Contacts
import ContactsUI

struct FamilyMemberCard: View {
    let title: String
    let subtitle: String
    let detail: String?
    let icon: String
    let color: Color
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                }
                
                Spacer()
                
                if let detail = detail {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Last active:")
                            .font(.caption2)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.5))
                        
                        Text(detail)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                            .multilineTextAlignment(.trailing)
                    }
                    .frame(minWidth: 80, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(themeManager.currentTheme.otherMonthBackgroundColor)
                .shadow(color: themeManager.currentTheme.textColor.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

struct FamilyView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAddCoparent = false
    @State private var showingAddChild = false
    @State private var showingAddOtherFamily = false
    @State private var showingContactPicker = false
    @State private var showingAddOptionsSheet = false
    @State private var selectedContact: CNContact?
    @State private var showingContactPermissionAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Family")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.currentTheme.textColor)
                        
                        Text("Manage your family members and relationships")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                    }
                    .padding(.horizontal)
                    
                    // Coparents Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Coparents")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(themeManager.currentTheme.textColor)
                            
                            Spacer()
                            
                            Button(action: { showingAddCoparent = true }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        if viewModel.coparents.isEmpty {
                            Text("No coparents added yet")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                                .padding(.horizontal)
                        } else {
                            ForEach(viewModel.coparents) { coparent in
                                FamilyMemberCard(
                                    title: coparent.fullName,
                                    subtitle: coparent.phone_number ?? coparent.email,
                                    detail: coparent.lastSignin != nil ? formatRelativeTime(coparent.lastSignin!) : "Never",
                                    icon: "person.crop.circle",
                                    color: .blue
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Children Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Children")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(themeManager.currentTheme.textColor)
                            
                            Spacer()
                            
                            Button(action: { showingAddChild = true }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.horizontal)
                        
                        if viewModel.children.isEmpty {
                            Text("No children added yet")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                                .padding(.horizontal)
                        } else {
                            ForEach(viewModel.children) { child in
                                FamilyMemberCard(
                                    title: child.firstName,
                                    subtitle: "Born: \(formatDate(child.dateOfBirth))",
                                    detail: "\(child.age) years old",
                                    icon: "figure.2.and.child.holdinghands",
                                    color: .green
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Other Family Members Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Other Family")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(themeManager.currentTheme.textColor)
                            
                            Spacer()
                            
                            Button(action: { showingAddOptionsSheet = true }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.purple)
                            }
                        }
                        .padding(.horizontal)
                        
                        if viewModel.emergencyContacts.isEmpty {
                            Text("No other family members added yet")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                                .padding(.horizontal)
                        } else {
                            ForEach(viewModel.emergencyContacts) { contact in
                                FamilyMemberCard(
                                    title: contact.fullName,
                                    subtitle: contact.displayRelationship,
                                    detail: contact.notes ?? contact.phone_number,
                                    icon: "person.3",
                                    color: .purple
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    Spacer(minLength: 80)
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor)
        }
        .sheet(isPresented: $showingAddCoparent) {
            AddCoparentView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingAddChild) {
            AddChildView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingAddOtherFamily) {
            AddOtherFamilyView(prefilledContact: selectedContact)
                .environmentObject(viewModel)
                .environmentObject(themeManager)
                .onDisappear {
                    selectedContact = nil
                }
        }
        .confirmationDialog("Add Family Member", isPresented: $showingAddOptionsSheet) {
            Button("Add Manually") {
                showingAddOtherFamily = true
            }
            Button("Choose from Contacts") {
                requestContactsPermission()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("How would you like to add a family member?")
        }
        .sheet(isPresented: $showingContactPicker) {
            ContactPickerView { contact in
                handleSelectedContact(contact)
            }
        }
        .alert("Contacts Access Required", isPresented: $showingContactPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To add family members from your contacts, please enable Contacts access in Settings.")
        }
        .onAppear {
            // Ensure emergency contacts are loaded for the "Other Family" section
            viewModel.fetchEmergencyContacts()
        }
    }
    
    private func requestContactsPermission() {
        let store = CNContactStore()
        
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            showingContactPicker = true
        case .denied, .restricted:
            showingContactPermissionAlert = true
        case .limited:
            showingContactPicker = true
        case .notDetermined:
            store.requestAccess(for: .contacts) { granted, error in
                DispatchQueue.main.async {
                    if granted {
                        self.showingContactPicker = true
                    } else {
                        print("Contacts access denied by user.")
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    private func handleSelectedContact(_ contact: CNContact) {
        selectedContact = contact
        showingAddOtherFamily = true
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func formatRelativeTime(_ dateString: String) -> String {
        // Try different date formats that might be returned from the API
        let formatters = [
            "yyyy-MM-dd HH:mm:ss:SSSSSS",    // Format like "2025-07-01 11:33:37:522876"
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",  // ISO format with microseconds
            "yyyy-MM-dd'T'HH:mm:ss",         // ISO format without microseconds
            "yyyy-MM-dd HH:mm:ss.SSSSSS",    // SQL datetime with microseconds (dot)
            "yyyy-MM-dd HH:mm:ss",           // SQL datetime format
            "yyyy-MM-dd"                     // Date only format
        ]
        
        var date: Date?
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.timeZone = TimeZone.current
            if let parsedDate = formatter.date(from: dateString) {
                date = parsedDate
                print("✅ Successfully parsed date '\(dateString)' using format '\(format)'")
                break
            }
        }
        
        guard let lastSigninDate = date else { 
            // If we can't parse the date, return a fallback message
            print("⚠️ Could not parse date: \(dateString)")
            return "Never"
        }
        
        let now = Date()
        let timeInterval = now.timeIntervalSince(lastSigninDate)
        
        // If in the future, show "Just now"
        if timeInterval < 0 {
            return "Just now"
        }
        
        let seconds = Int(timeInterval)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        
        if seconds < 300 { // Less than 5 minutes
            return "Just now"
        } else if hours < 24 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else if days < 7 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        } else {
            return "Over a week ago"
        }
    }
}

// MARK: - Add Coparent View
struct AddCoparentView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Coparent Information") {
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
                        title: "Email",
                        text: $email,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    
                    FloatingLabelTextField(
                        title: "Notes (Optional)",
                        text: $notes,
                        isSecure: false,
                        themeManager: themeManager
                    )
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor)
            .navigationTitle("Add Coparent")
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
                    .disabled(firstName.isEmpty || lastName.isEmpty || email.isEmpty)
                }
            }
        }
    }
}

// MARK: - Add Child View
struct AddChildView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section("Child Information") {
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
                    
                    DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                        .foregroundColor(themeManager.currentTheme.textColor)
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor)
            .navigationTitle("Add Child")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChild()
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty)
                }
            }
        }
    }
    
    private func saveChild() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dobString = dateFormatter.string(from: dateOfBirth)
        
        let childData = ChildCreate(
            first_name: firstName,
            last_name: lastName,
            dob: dobString
        )
        
        viewModel.saveChild(childData) { success in
            if success {
                print("✅ Child saved successfully")
            } else {
                print("❌ Failed to save child")
            }
            dismiss()
        }
    }
}

// MARK: - Add Other Family View
struct AddOtherFamilyView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    let prefilledContact: CNContact?
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var relationship = ""
    
    init(prefilledContact: CNContact? = nil) {
        self.prefilledContact = prefilledContact
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Family Member Information") {
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
                        title: "Email (Optional)",
                        text: $email,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    
                    FloatingLabelTextField(
                        title: "Phone Number (Optional)",
                        text: $phoneNumber,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    .keyboardType(.phonePad)
                    
                    FloatingLabelTextField(
                        title: "Relationship",
                        text: $relationship,
                        isSecure: false,
                        themeManager: themeManager
                    )
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor)
            .navigationTitle("Add Family Member")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let contact = prefilledContact {
                    firstName = contact.givenName
                    lastName = contact.familyName
                    email = contact.emailAddresses.first?.value as String? ?? ""
                    phoneNumber = contact.phoneNumbers.first?.value.stringValue ?? ""
                    relationship = "Family Member" // Default relationship
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveOtherFamilyMember()
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty || relationship.isEmpty)
                }
            }
        }
    }
    
    private func saveOtherFamilyMember() {
        // Create emergency contact data (using emergency contacts API as temporary solution)
        let contactData = EmergencyContactCreate(
            first_name: firstName,
            last_name: lastName,
            phone_number: phoneNumber.isEmpty ? "N/A" : phoneNumber,
            relationship: relationship,
            notes: email.isEmpty ? nil : email // Store email in notes field temporarily
        )
        
        viewModel.saveEmergencyContact(contactData) { success in
            DispatchQueue.main.async {
                if success {
                    print("✅ Other family member saved successfully")
                    dismiss()
                } else {
                    print("❌ Failed to save other family member")
                    // For now, just dismiss. In a real app, you'd show an error message
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Contact Picker View
struct ContactPickerView: UIViewControllerRepresentable {
    let onContactSelected: (CNContact) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactEmailAddressesKey, CNContactPhoneNumbersKey]
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactPickerView
        
        init(_ parent: ContactPickerView) {
            self.parent = parent
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.onContactSelected(contact)
            parent.dismiss()
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.dismiss()
        }
    }
}

struct FamilyView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let themeManager = ThemeManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager, themeManager: themeManager)
        
        FamilyView()
            .environmentObject(calendarViewModel)
            .environmentObject(themeManager)
    }
} 