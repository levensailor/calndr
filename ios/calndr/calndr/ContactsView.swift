import SwiftUI
import MessageUI

struct ContactsView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @State private var familyEmails: [FamilyMemberEmail] = []
    @State private var babysitters: [Babysitter] = []
    @State private var emergencyContacts: [EmergencyContact] = []
    @State private var isLoading = true
    @State private var showAddBabysitter = false
    @State private var showAddEmergencyContact = false
    @State private var showEditBabysitter: Babysitter?
    @State private var showEditEmergencyContact: EmergencyContact?
    @State private var errorMessage: String?
    @State private var showMailComposer = false
    @State private var mailComposeResult: Result<MFMailComposeResult, Error>?
    @State private var currentFamilyMember: FamilyMemberEmail?
    @State private var selectedContactForGroupText: (contactType: String, contactId: Int, name: String, phone: String)?
    
    private let apiService = APIService.shared
    
    var body: some View {
        NavigationView {
            Form {
                if viewModel.isOffline {
                    Section {
                        Text("You are currently offline. Contact information is not available.")
                            .foregroundColor(.gray)
                    }
                } else if isLoading {
                    Section {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Loading contacts...")
                                .foregroundColor(.gray)
                        }
                    }
                } else {
                    // Family Members Section
                    Section(header: Text("Family Members")) {
                        ForEach(familyEmails, id: \.id) { member in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(member.first_name)
                                        .font(.headline)
                                    Text(member.email)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                // Get phone number from user profile if available
                                if let phoneNumber = getPhoneNumber(for: member) {
                                    Button("Text") {
                                        sendTextMessage(to: phoneNumber)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                    
                    // Babysitters Section
                    Section(header: 
                        HStack {
                            Text("Babysitters")
                            Spacer()
                            Button("Add") {
                                showAddBabysitter = true
                            }
                            .font(.caption)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    ) {
                        if babysitters.isEmpty {
                            Text("No babysitters added yet")
                                .foregroundColor(.gray)
                                .italic()
                        } else {
                            ForEach(babysitters) { babysitter in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(babysitter.fullName)
                                            .font(.headline)
                                        Spacer()
                                        Text(babysitter.formattedRate)
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                    
                                    HStack {
                                        Text(babysitter.phone_number)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        
                                        Spacer()
                                        
                                        // Action buttons
                                        HStack(spacing: 8) {
                                            Button("Text") {
                                                sendTextMessage(to: babysitter.phone_number)
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                            
                                            Button("Group Text") {
                                                selectedContactForGroupText = ("babysitter", babysitter.id, babysitter.fullName, babysitter.phone_number)
                                                startGroupText()
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                            
                                            Button("Edit") {
                                                showEditBabysitter = babysitter
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                        }
                                    }
                                    
                                    if let notes = babysitter.notes, !notes.isEmpty {
                                        Text(notes)
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                            .italic()
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button("Delete", role: .destructive) {
                                        deleteBabysitter(babysitter)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Emergency Contacts Section
                    Section(header:
                        HStack {
                            Text("Emergency Contacts")
                            Spacer()
                            Button("Add") {
                                showAddEmergencyContact = true
                            }
                            .font(.caption)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    ) {
                        if emergencyContacts.isEmpty {
                            Text("No emergency contacts added yet")
                                .foregroundColor(.gray)
                                .italic()
                        } else {
                            ForEach(emergencyContacts) { contact in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(contact.fullName)
                                            .font(.headline)
                                        Spacer()
                                        Text(contact.displayRelationship)
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    
                                    HStack {
                                        Text(contact.phone_number)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        
                                        Spacer()
                                        
                                        // Action buttons
                                        HStack(spacing: 8) {
                                            Button("Call") {
                                                makePhoneCall(to: contact.phone_number)
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                            
                                            Button("Text") {
                                                sendTextMessage(to: contact.phone_number)
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                            
                                            Button("Group Text") {
                                                selectedContactForGroupText = ("emergency", contact.id, contact.fullName, contact.phone_number)
                                                startGroupText()
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                            
                                            Button("Edit") {
                                                showEditEmergencyContact = contact
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                        }
                                    }
                                    
                                    if let notes = contact.notes, !notes.isEmpty {
                                        Text(notes)
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                            .italic()
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button("Delete", role: .destructive) {
                                        deleteEmergencyContact(contact)
                                    }
                                }
                            }
                        }
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Contacts")
            .onAppear {
                loadContacts()
            }
            .sheet(isPresented: $showAddBabysitter) {
                AddBabysitterView { babysitter in
                    createBabysitter(babysitter)
                }
            }
            .sheet(isPresented: $showAddEmergencyContact) {
                AddEmergencyContactView { contact in
                    createEmergencyContact(contact)
                }
            }
            .sheet(item: $showEditBabysitter) { babysitter in
                EditBabysitterView(babysitter: babysitter) { updatedBabysitter in
                    updateBabysitter(babysitter.id, with: updatedBabysitter)
                }
            }
            .sheet(item: $showEditEmergencyContact) { contact in
                EditEmergencyContactView(contact: contact) { updatedContact in
                    updateEmergencyContact(contact.id, with: updatedContact)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadContacts() {
        isLoading = true
        errorMessage = nil
        
        let group = DispatchGroup()
        
        // Load family emails
        group.enter()
        apiService.fetchFamilyMemberEmails { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let emails):
                    self.familyEmails = emails
                case .failure(let error):
                    self.errorMessage = "Failed to load family members: \(error.localizedDescription)"
                }
                group.leave()
            }
        }
        
        // Load babysitters
        group.enter()
        apiService.fetchBabysitters { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let sitters):
                    self.babysitters = sitters
                case .failure(let error):
                    self.errorMessage = "Failed to load babysitters: \(error.localizedDescription)"
                }
                group.leave()
            }
        }
        
        // Load emergency contacts
        group.enter()
        apiService.fetchEmergencyContacts { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let contacts):
                    self.emergencyContacts = contacts
                case .failure(let error):
                    self.errorMessage = "Failed to load emergency contacts: \(error.localizedDescription)"
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.isLoading = false
        }
    }
    
    private func getPhoneNumber(for member: FamilyMemberEmail) -> String? {
        // This would need to be implemented based on how phone numbers are stored
        // For now, returning nil since we don't have phone numbers in family emails
        return nil
    }
    
    private func sendTextMessage(to phoneNumber: String) {
        guard let url = URL(string: "sms:\(phoneNumber)") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    private func makePhoneCall(to phoneNumber: String) {
        guard let url = URL(string: "tel:\(phoneNumber)") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    private func startGroupText() {
        guard let contact = selectedContactForGroupText else { return }
        
        apiService.createOrGetGroupChat(contactType: contact.contactType, contactId: contact.contactId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let chatResponse):
                    // Create group text with unique identifier
                    let familyPhoneNumbers = getFamilyPhoneNumbers()
                    let allNumbers = [contact.phone] + familyPhoneNumbers
                    let numbersString = allNumbers.joined(separator: ",")
                    
                    guard let url = URL(string: "sms:\(numbersString)&body=Hi \(contact.name)! This is a group chat from the \(getFamilyName()) family.") else { return }
                    
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                    
                case .failure(let error):
                    self.errorMessage = "Failed to create group chat: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func getFamilyPhoneNumbers() -> [String] {
        // This would get phone numbers from family members
        // Placeholder implementation
        return []
    }
    
    private func getFamilyName() -> String {
        // This would get the family name
        return "Smith" // Placeholder
    }
    
    // MARK: - CRUD Operations
    
    private func createBabysitter(_ babysitter: BabysitterCreate) {
        apiService.createBabysitter(babysitter) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.loadContacts() // Refresh the list
                case .failure(let error):
                    self.errorMessage = "Failed to add babysitter: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func updateBabysitter(_ id: Int, with babysitter: BabysitterCreate) {
        apiService.updateBabysitter(id: id, babysitter: babysitter) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.loadContacts() // Refresh the list
                case .failure(let error):
                    self.errorMessage = "Failed to update babysitter: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func deleteBabysitter(_ babysitter: Babysitter) {
        apiService.deleteBabysitter(id: babysitter.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.loadContacts() // Refresh the list
                case .failure(let error):
                    self.errorMessage = "Failed to delete babysitter: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func createEmergencyContact(_ contact: EmergencyContactCreate) {
        apiService.createEmergencyContact(contact) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.loadContacts() // Refresh the list
                case .failure(let error):
                    self.errorMessage = "Failed to add emergency contact: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func updateEmergencyContact(_ id: Int, with contact: EmergencyContactCreate) {
        apiService.updateEmergencyContact(id: id, contact: contact) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.loadContacts() // Refresh the list
                case .failure(let error):
                    self.errorMessage = "Failed to update emergency contact: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func deleteEmergencyContact(_ contact: EmergencyContact) {
        apiService.deleteEmergencyContact(id: contact.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.loadContacts() // Refresh the list
                case .failure(let error):
                    self.errorMessage = "Failed to delete emergency contact: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Add/Edit Views

struct AddBabysitterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phoneNumber = ""
    @State private var rate = ""
    @State private var notes = ""
    
    let onSave: (BabysitterCreate) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Babysitter Information")) {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Hourly Rate (optional)", text: $rate)
                        .keyboardType(.decimalPad)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }
            }
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
                        let rateValue = Double(rate.isEmpty ? "0" : rate)
                        let babysitter = BabysitterCreate(
                            first_name: firstName,
                            last_name: lastName,
                            phone_number: phoneNumber,
                            rate: rateValue,
                            notes: notes.isEmpty ? nil : notes
                        )
                        onSave(babysitter)
                        dismiss()
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty || phoneNumber.isEmpty)
                }
            }
        }
    }
}

struct EditBabysitterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String
    @State private var lastName: String
    @State private var phoneNumber: String
    @State private var rate: String
    @State private var notes: String
    
    let babysitter: Babysitter
    let onSave: (BabysitterCreate) -> Void
    
    init(babysitter: Babysitter, onSave: @escaping (BabysitterCreate) -> Void) {
        self.babysitter = babysitter
        self.onSave = onSave
        self._firstName = State(initialValue: babysitter.first_name)
        self._lastName = State(initialValue: babysitter.last_name)
        self._phoneNumber = State(initialValue: babysitter.phone_number)
        self._rate = State(initialValue: babysitter.rate != nil ? String(format: "%.2f", babysitter.rate!) : "")
        self._notes = State(initialValue: babysitter.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Babysitter Information")) {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Hourly Rate (optional)", text: $rate)
                        .keyboardType(.decimalPad)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle("Edit Babysitter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let rateValue = Double(rate.isEmpty ? "0" : rate)
                        let updatedBabysitter = BabysitterCreate(
                            first_name: firstName,
                            last_name: lastName,
                            phone_number: phoneNumber,
                            rate: rateValue,
                            notes: notes.isEmpty ? nil : notes
                        )
                        onSave(updatedBabysitter)
                        dismiss()
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty || phoneNumber.isEmpty)
                }
            }
        }
    }
}

struct AddEmergencyContactView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phoneNumber = ""
    @State private var relationship = ""
    @State private var notes = ""
    
    let onSave: (EmergencyContactCreate) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Emergency Contact Information")) {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Relationship (optional)", text: $relationship)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }
            }
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
                        let contact = EmergencyContactCreate(
                            first_name: firstName,
                            last_name: lastName,
                            phone_number: phoneNumber,
                            relationship: relationship.isEmpty ? nil : relationship,
                            notes: notes.isEmpty ? nil : notes
                        )
                        onSave(contact)
                        dismiss()
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty || phoneNumber.isEmpty)
                }
            }
        }
    }
}

struct EditEmergencyContactView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String
    @State private var lastName: String
    @State private var phoneNumber: String
    @State private var relationship: String
    @State private var notes: String
    
    let contact: EmergencyContact
    let onSave: (EmergencyContactCreate) -> Void
    
    init(contact: EmergencyContact, onSave: @escaping (EmergencyContactCreate) -> Void) {
        self.contact = contact
        self.onSave = onSave
        self._firstName = State(initialValue: contact.first_name)
        self._lastName = State(initialValue: contact.last_name)
        self._phoneNumber = State(initialValue: contact.phone_number)
        self._relationship = State(initialValue: contact.relationship ?? "")
        self._notes = State(initialValue: contact.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Emergency Contact Information")) {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Relationship (optional)", text: $relationship)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle("Edit Emergency Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let updatedContact = EmergencyContactCreate(
                            first_name: firstName,
                            last_name: lastName,
                            phone_number: phoneNumber,
                            relationship: relationship.isEmpty ? nil : relationship,
                            notes: notes.isEmpty ? nil : notes
                        )
                        onSave(updatedContact)
                        dismiss()
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty || phoneNumber.isEmpty)
                }
            }
        }
    }
} 