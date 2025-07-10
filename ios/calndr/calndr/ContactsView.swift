import SwiftUI
import MessageUI

struct ContactsView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @State private var familyEmails: [FamilyMemberEmail] = []
    @State private var familyMembers: [FamilyMember] = []
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
    @State private var showMessageComposer = false
    @State private var messageComposeResult: Result<MessageComposeResult, Error>?
    @State private var groupTextRecipients: [String] = []
    @State private var groupTextContact: (name: String, phone: String)?
    
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
                                            .disabled(isLoading || familyMembers.isEmpty)
                                            
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
                                            .disabled(isLoading || familyMembers.isEmpty)
                                            
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
            .sheet(isPresented: $showMessageComposer, onDismiss: {
                // Clean up state when modal is dismissed
                groupTextContact = nil
                groupTextRecipients = []
                selectedContactForGroupText = nil
            }) {
                if let contact = groupTextContact, !groupTextRecipients.isEmpty {
                    MessageComposeView(
                        recipients: groupTextRecipients,
                        messageBody: "Hi \(contact.name)! This is a group chat from the \(getFamilyName()) family.",
                        result: $messageComposeResult
                    )
                } else {
                    // Fallback view to prevent blank modal
                    VStack {
                        Text("Unable to start group message")
                            .font(.headline)
                            .padding()
                        Text("Family member data is still loading or unavailable. Please wait a moment and try again.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Close") {
                            showMessageComposer = false
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
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
        
        // Load family members with phone numbers
        group.enter()
        apiService.fetchFamilyMembers { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let members):
                    self.familyMembers = members
                case .failure(let error):
                    print("Failed to load family members with phone numbers: \(error.localizedDescription)")
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
        // Find the corresponding family member with phone number using ID
        return familyMembers.first { $0.id == member.id }?.phone_number
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
        
        // Check if device can send messages
        guard MFMessageComposeViewController.canSendText() else {
            self.errorMessage = "This device cannot send text messages"
            return
        }
        
        // Check if we're still loading contacts
        if isLoading {
            self.errorMessage = "Still loading contacts, please try again in a moment"
            return
        }
        
        // If family members are empty, this might be the first load or a loading issue
        if familyMembers.isEmpty {
            print("🔄 Family members not loaded, checking if we need to reload...")
            
            // Try loading if not already in progress
            if !isLoading {
                loadContacts()
                self.errorMessage = "Loading family member data, please try again in a moment"
            }
            return
        }
        
        // Prepare group text data immediately to avoid race conditions
        let familyPhoneNumbers = self.getFamilyPhoneNumbers()
        
        // Debug logging
        print("🔍 Group Text Debug:")
        print("   Contact: \(contact.name) - \(contact.phone)")
        print("   Family members count: \(self.familyMembers.count)")
        print("   Family phone numbers: \(familyPhoneNumbers)")
        
        // Combine contact phone with all family phone numbers
        var allNumbers = [contact.phone]
        allNumbers.append(contentsOf: familyPhoneNumbers)
        
        // Remove duplicates (in case contact phone is same as a family member)
        let uniqueNumbers = Array(Set(allNumbers)).filter { !$0.isEmpty }
        
        print("   Final numbers for group text: \(uniqueNumbers)")
        
        // Validate we have recipients before proceeding
        guard !uniqueNumbers.isEmpty else {
            self.errorMessage = "No phone numbers available for group text"
            return
        }
        
        apiService.createOrGetGroupChat(contactType: contact.contactType, contactId: contact.contactId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    // Capture the contact and recipients data to prevent race conditions
                    self.groupTextContact = (name: contact.name, phone: contact.phone)
                    self.groupTextRecipients = uniqueNumbers
                    
                    // Present the message composer
                    self.showMessageComposer = true
                    
                case .failure(let error):
                    self.errorMessage = "Failed to create group chat: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func getFamilyPhoneNumbers() -> [String] {
        // Return phone numbers of all family members that have them
        let phoneNumbers = familyMembers.compactMap { member -> String? in
            let phone = member.phone_number?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let phone = phone, !phone.isEmpty {
                print("📱 Family member: \(member.first_name) \(member.last_name) - Phone: \(phone)")
                return phone
            } else {
                print("📱 Family member: \(member.first_name) \(member.last_name) - No phone number")
                return nil
            }
        }
        
        print("📱 Total family phone numbers found: \(phoneNumbers.count)")
        return phoneNumbers
    }
    
    private func getFamilyName() -> String {
        // Get the family name from the first family member's last name
        return familyMembers.first?.last_name ?? "Family"
    }
    
    private func getGroupTextRecipients() -> [String] {
        guard let contact = selectedContactForGroupText else { return [] }
        
        let familyPhoneNumbers = getFamilyPhoneNumbers()
        var allNumbers = [contact.phone]
        allNumbers.append(contentsOf: familyPhoneNumbers)
        
        // Remove duplicates and empty numbers
        let uniqueNumbers = Array(Set(allNumbers)).filter { !$0.isEmpty }
        
        print("📱 Group text recipients: \(uniqueNumbers)")
        return uniqueNumbers
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

// MARK: - Message Compose View

struct MessageComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let messageBody: String
    @Binding var result: Result<MessageComposeResult, Error>?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = context.coordinator
        
        // Validate and set recipients
        let validRecipients = recipients.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        controller.recipients = validRecipients
        controller.body = messageBody
        
        print("📱 Creating message composer with \(validRecipients.count) recipients: \(validRecipients)")
        print("📱 Message body: \(messageBody)")
        
        // Additional validation
        if validRecipients.isEmpty {
            print("⚠️ Warning: No valid recipients for message composer")
        }
        
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let parent: MessageComposeView

        init(_ parent: MessageComposeView) {
            self.parent = parent
        }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            switch result {
            case .cancelled:
                print("📱 Message compose cancelled")
                parent.result = .success(.cancelled)
            case .sent:
                print("📱 Message sent successfully")
                parent.result = .success(.sent)
            case .failed:
                print("📱 Message compose failed")
                parent.result = .failure(NSError(domain: "MessageComposeError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to send message"]))
            @unknown default:
                print("📱 Unknown message compose result")
                parent.result = .failure(NSError(domain: "MessageComposeError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unknown result"]))
            }
            
            parent.dismiss()
        }
    }
} 