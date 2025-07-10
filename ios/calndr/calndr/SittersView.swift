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
    @State private var showingAddEmergencyContact = false
    @State private var familyMembers: [FamilyMember] = []
    @State private var isLoading = true
    @State private var selectedContactForGroupText: (contactType: String, contactId: Int, name: String, phone: String)?
    @State private var showMessageComposer = false
    @State private var messageComposeResult: Result<MessageComposeResult, Error>?
    @StateObject private var groupTextDataStore = SittersGroupTextDataStore()
    
    private let apiService = APIService.shared
    
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
                                BabysitterCard(
                                    babysitter: babysitter,
                                    onGroupText: {
                                        selectedContactForGroupText = ("babysitter", babysitter.id, babysitter.fullName, babysitter.phone_number)
                                        startGroupText()
                                    }
                                )
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
        .sheet(isPresented: $showingAddEmergencyContact) {
            AddEmergencyContactView { contact in
                viewModel.saveEmergencyContact(contact) { success in
                    if success {
                        print("✅ Emergency contact saved successfully")
                    } else {
                        print("❌ Failed to save emergency contact")
                    }
                }
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
}

struct BabysitterCard: View {
    let babysitter: Babysitter
    let onGroupText: () -> Void
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