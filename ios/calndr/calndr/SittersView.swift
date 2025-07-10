import SwiftUI
import MessageUI

// MARK: - Group Text Data Store
class SittersGroupTextDataStore: ObservableObject {
    @Published var contact: (name: String, phone: String)?
    @Published var recipients: [String] = []
    
    func setData(contact: (name: String, phone: String), recipients: [String]) {
        print("📦 SittersGroupTextDataStore: Setting data - contact: \(contact), recipients: \(recipients)")
        self.contact = contact
        self.recipients = recipients
    }
    
    func clearData() {
        print("📦 SittersGroupTextDataStore: Clearing data")
        self.contact = nil
        self.recipients = []
    }
    
    var hasValidData: Bool {
        let isValid = contact != nil && !recipients.isEmpty
        print("📦 SittersGroupTextDataStore: hasValidData = \(isValid)")
        return isValid
    }
}

struct SittersView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAddBabysitter = false
    @State private var familyMembers: [FamilyMember] = []
    @State private var isLoading = true
    @State private var selectedContactForGroupText: (contactType: String, contactId: Int, name: String, phone: String)?
    @State private var showMessageComposer = false
    @State private var messageComposeResult: Result<MessageComposeResult, Error>?
    @StateObject private var groupTextDataStore = SittersGroupTextDataStore()
    
    // Edit/Delete state
    @State private var selectedBabysitter: Babysitter?
    @State private var showingEditBabysitter = false
    @State private var showingDeleteAlert = false
    @State private var babysitterToDelete: Babysitter?
    @State private var deleteAlertTitle = ""
    @State private var deleteAlertMessage = ""
    
    private let apiService = APIService.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Babysitters")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.currentTheme.textColor)
                        
                        Text("Manage your trusted babysitters")
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
                                BabysitterCard(
                                    babysitter: babysitter,
                                    onGroupText: {
                                        selectedContactForGroupText = ("babysitter", babysitter.id, babysitter.fullName, babysitter.phone_number)
                                        startGroupText()
                                    },
                                    onEdit: {
                                        editBabysitter(babysitter)
                                    },
                                    onDelete: {
                                        deleteBabysitter(babysitter)
                                    }
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Find Babysitters Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Find Babysitters")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(themeManager.currentTheme.textColor)
                            
                            Spacer()
                            
                            Image(systemName: "magnifyingglass")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            FindBabysitterCard(
                                title: "Care.com",
                                subtitle: "Find trusted babysitters in your area",
                                icon: "heart.fill",
                                color: .pink,
                                url: "https://www.care.com/babysitters"
                            )
                            
                            FindBabysitterCard(
                                title: "Sittercity.com",
                                subtitle: "Connect with local childcare providers",
                                icon: "house.fill",
                                color: .blue,
                                url: "https://www.sittercity.com"
                            )
                            
                            FindBabysitterCard(
                                title: "Nextdoor",
                                subtitle: "Ask your neighbors for recommendations",
                                icon: "person.2.fill",
                                color: .green,
                                url: "https://nextdoor.com"
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 80)
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor)
            .onAppear {
                loadFamilyData()
            }
        }
        .sheet(isPresented: $showingAddBabysitter) {
            AddBabysitterView { babysitter in
                viewModel.saveBabysitter(babysitter) { success in
                    if success {
                        print("✅ Babysitter saved successfully")
                    } else {
                        print("❌ Failed to save babysitter")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditBabysitter) {
            if let babysitter = selectedBabysitter {
                EditBabysitterView(babysitter: babysitter) { updatedBabysitter in
                    viewModel.updateBabysitter(updatedBabysitter) { success in
                        if success {
                            print("✅ Babysitter updated successfully")
                        } else {
                            print("❌ Failed to update babysitter")
                        }
                    }
                }
                .environmentObject(viewModel)
                .environmentObject(themeManager)
            }
        }
        .sheet(isPresented: $showMessageComposer, onDismiss: {
            print("🗂️ Sheet dismissed - cleaning up state")
            groupTextDataStore.clearData()
            selectedContactForGroupText = nil
        }) {
            SittersGroupTextSheetView(
                dataStore: groupTextDataStore,
                familyMembers: familyMembers,
                children: viewModel.children,
                messageComposeResult: $messageComposeResult,
                showMessageComposer: $showMessageComposer
            )
        }
        .alert(deleteAlertTitle, isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let babysitter = babysitterToDelete {
                    viewModel.deleteBabysitter(babysitter) { success in
                        if success {
                            print("✅ Babysitter deleted successfully")
                        } else {
                            print("❌ Failed to delete babysitter")
                        }
                    }
                }
                babysitterToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                babysitterToDelete = nil
            }
        } message: {
            Text(deleteAlertMessage)
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadFamilyData() {
        isLoading = true
        
        apiService.fetchFamilyMembers { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let members):
                    self.familyMembers = members
                    print("✅ Successfully loaded \(members.count) family members for group text")
                case .failure(let error):
                    print("❌ Failed to load family members: \(error.localizedDescription)")
                }
                self.isLoading = false
            }
        }
    }
    
    private func startGroupText() {
        print("🚀 startGroupText() called")
        
        guard let contact = selectedContactForGroupText else {
            print("❌ No contact selected for group text")
            return
        }
        
        print("✅ Contact selected: \(contact.name) - \(contact.phone)")
        
        // Check if device can send messages
        guard MFMessageComposeViewController.canSendText() else {
            print("❌ Device cannot send text messages")
            return
        }
        
        print("✅ Device can send messages")
        
        // Prepare group text data
        let familyPhoneNumbers = getFamilyPhoneNumbers()
        
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
            print("❌ No phone numbers available for group text")
            return
        }
        
        print("🌐 Calling createOrGetGroupChat API...")
        apiService.createOrGetGroupChat(contactType: contact.contactType, contactId: contact.contactId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    print("✅ API call successful")
                    // Store data in persistent data store
                    self.groupTextDataStore.setData(
                        contact: (name: contact.name, phone: contact.phone),
                        recipients: uniqueNumbers
                    )
                    
                    // Present the message composer
                    print("📱 Setting showMessageComposer = true")
                    self.showMessageComposer = true
                    
                case .failure(let error):
                    print("❌ API call failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func getFamilyPhoneNumbers() -> [String] {
        // Get current user ID to exclude from group text
        let currentUserID = viewModel.currentUserID
        
        // Return phone numbers of all family members that have them, excluding current user
        let phoneNumbers = familyMembers.compactMap { member -> String? in
            // Skip the current user
            if member.id == currentUserID {
                print("📱 Skipping current user: \(member.first_name) \(member.last_name) - \(member.id)")
                return nil
            }
            
            let phone = member.phone_number?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let phone = phone, !phone.isEmpty {
                print("📱 Family member: \(member.first_name) \(member.last_name) - Phone: \(phone)")
                return phone
            } else {
                print("📱 Family member: \(member.first_name) \(member.last_name) - No phone number")
                return nil
            }
        }
        
        print("📱 Total family phone numbers found: \(phoneNumbers.count) (excluding current user)")
        return phoneNumbers
    }
    
    // MARK: - Edit and Delete Functions
    
    private func editBabysitter(_ babysitter: Babysitter) {
        selectedBabysitter = babysitter
        showingEditBabysitter = true
    }
    
    private func deleteBabysitter(_ babysitter: Babysitter) {
        babysitterToDelete = babysitter
        deleteAlertTitle = "Delete Babysitter"
        deleteAlertMessage = "Are you sure you want to delete \(babysitter.fullName)? This action cannot be undone."
        showingDeleteAlert = true
    }
}

struct BabysitterCard: View {
    let babysitter: Babysitter
    let onGroupText: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
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
                
                HStack(spacing: 8) {
                    Button(action: {
                        if let phoneURL = URL(string: "tel:\(babysitter.phone_number)") {
                            UIApplication.shared.open(phoneURL)
                        }
                    }) {
                        Image(systemName: "phone.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                    }
                    
                    Button(action: {
                        if let smsURL = URL(string: "sms:\(babysitter.phone_number)") {
                            UIApplication.shared.open(smsURL)
                        }
                    }) {
                        Image(systemName: "message.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: onGroupText) {
                        Image(systemName: "person.3.fill")
                            .font(.title3)
                            .foregroundColor(.purple)
                    }
                    
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.title3)
                            .foregroundColor(.orange)
                    }
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundColor(.red)
                    }
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

struct FindBabysitterCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let url: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: {
            if let websiteURL = URL(string: url) {
                UIApplication.shared.open(websiteURL)
            }
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 30, height: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textColor.opacity(0.5))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.currentTheme.otherMonthBackgroundColor)
                    .shadow(color: themeManager.currentTheme.textColor.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}



// MARK: - Message Compose View

struct SittersMessageComposeView: UIViewControllerRepresentable {
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
        let parent: SittersMessageComposeView

        init(_ parent: SittersMessageComposeView) {
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

// MARK: - Group Text Sheet View

struct SittersGroupTextSheetView: View {
    @ObservedObject var dataStore: SittersGroupTextDataStore
    let familyMembers: [FamilyMember]
    let children: [Child]
    @Binding var messageComposeResult: Result<MessageComposeResult, Error>?
    @Binding var showMessageComposer: Bool
    
    var body: some View {
        Group {
            if dataStore.hasValidData, let contact = dataStore.contact {
                SittersMessageComposeView(
                    recipients: dataStore.recipients,
                    messageBody: createBabysitterMessage(babysitterName: contact.name),
                    result: $messageComposeResult
                )
            } else {
                // Fallback view to prevent blank modal
                VStack(spacing: 16) {
                    Text("Unable to start group message")
                        .font(.headline)
                    
                    Text("Family member data is still loading or unavailable. Please wait a moment and try again.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Button("Close") {
                        showMessageComposer = false
                    }
                    .buttonStyle(.borderedProminent)
                    
                    // Debug info
                    Text("Debug: Contact=\(dataStore.contact?.name ?? "nil"), Recipients=\(dataStore.recipients.count), Family=\(familyMembers.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .onAppear {
            print("🗂️ SittersGroupTextSheetView appeared")
            print("   dataStore.contact: \(String(describing: dataStore.contact))")
            print("   dataStore.recipients: \(dataStore.recipients)")
            print("   dataStore.hasValidData: \(dataStore.hasValidData)")
            
            if dataStore.hasValidData {
                print("✅ Presenting SittersMessageComposeView with data store")
            } else {
                print("❌ Presenting fallback view - no valid data in store")
            }
        }
    }
    
    private func createBabysitterMessage(babysitterName: String) -> String {
        let parentOneFirstName = familyMembers.first?.first_name ?? "Parent 1"
        let parentTwoFirstName = familyMembers.count > 1 ? familyMembers[1].first_name : "Parent 2"
        let childFirstName = children.first?.firstName ?? "our child"
        
        let message = "Hey \(babysitterName), this is \(parentOneFirstName) and \(parentTwoFirstName). Would you be able to babysit \(childFirstName) for us?"
        
        print("📝 Generated babysitter message: \(message)")
        return message
    }
}

// MARK: - Edit Babysitter View

struct EditBabysitterView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    let babysitter: Babysitter
    let onSave: (BabysitterCreate) -> Void
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phoneNumber = ""
    @State private var rate = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Babysitter Information") {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Hourly Rate", text: $rate)
                        .keyboardType(.decimalPad)
                }
                
                Section("Notes") {
                    TextField("Additional notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
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
                        saveBabysitter()
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty || phoneNumber.isEmpty)
                }
            }
        }
        .onAppear {
            firstName = babysitter.first_name
            lastName = babysitter.last_name
            phoneNumber = babysitter.phone_number
            rate = babysitter.rate != nil ? String(format: "%.2f", babysitter.rate!) : ""
            notes = babysitter.notes ?? ""
        }
    }
    
    private func saveBabysitter() {
        let updatedBabysitter = BabysitterCreate(
            first_name: firstName,
            last_name: lastName,
            phone_number: phoneNumber,
            rate: Double(rate) ?? 0.0,
            notes: notes.isEmpty ? nil : notes
        )
        
        onSave(updatedBabysitter)
        dismiss()
    }
}

struct SittersView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let themeManager = ThemeManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager, themeManager: themeManager)
        
        SittersView()
            .environmentObject(calendarViewModel)
            .environmentObject(themeManager)
    }
} 