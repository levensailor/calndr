import SwiftUI
import Contacts
import ContactsUI
import MessageUI

// MARK: - Family Group Text Data Store
class FamilyGroupTextDataStore: ObservableObject {
    @Published var contact: (name: String, phone: String)?
    @Published var recipients: [String] = []
    
    func setData(contact: (name: String, phone: String), recipients: [String]) {
        print("📦 FamilyGroupTextDataStore: Setting data - contact: \(contact), recipients: \(recipients)")
        self.contact = contact
        self.recipients = recipients
    }
    
    func clearData() {
        print("📦 FamilyGroupTextDataStore: Clearing data")
        self.contact = nil
        self.recipients = []
    }
    
    var hasValidData: Bool {
        let isValid = contact != nil && !recipients.isEmpty
        print("📦 FamilyGroupTextDataStore: hasValidData = \(isValid)")
        return isValid
    }
}

struct FamilyMemberCard: View {
    let title: String
    let subtitle: String
    let detail: String?
    let phoneNumber: String?
    let email: String?
    let icon: String
    let color: Color
    let canEdit: Bool
    let canDelete: Bool
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    @EnvironmentObject var themeManager: ThemeManager
    
    init(title: String, subtitle: String, detail: String? = nil, phoneNumber: String? = nil, email: String? = nil, icon: String, color: Color, canEdit: Bool = false, canDelete: Bool = false, onEdit: (() -> Void)? = nil, onDelete: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.phoneNumber = phoneNumber
        self.email = email
        self.icon = icon
        self.color = color
        self.canEdit = canEdit
        self.canDelete = canDelete
        self.onEdit = onEdit
        self.onDelete = onDelete
    }
    
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
                
                // Action buttons
                if canEdit || canDelete {
                    HStack(spacing: 8) {
                        if canEdit {
                            Button(action: { onEdit?() }) {
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(Color.blue.opacity(0.1)))
                            }
                        }
                        
                        if canDelete {
                            Button(action: { onDelete?() }) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(Color.red.opacity(0.1)))
                            }
                        }
                    }
                }
                
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
            
            // Contact information with clickable phone numbers
            if let phoneNumber = phoneNumber, phoneNumber != "N/A" {
                HStack {
                    Image(systemName: "phone.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Button(action: { makePhoneCall(phoneNumber) }) {
                        Text(phoneNumber)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .underline()
                    }
                    
                    Spacer()
                    
                    Button(action: { sendGroupMessage(phoneNumber) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "message.fill")
                                .font(.caption)
                            Text("Text")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.blue.opacity(0.1)))
                    }
                }
                .padding(.top, 4)
            } else if let email = email {
                HStack {
                    Image(systemName: "envelope.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Button(action: { sendEmail(email) }) {
                        Text(email)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .underline()
                    }
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(themeManager.currentTheme.otherMonthBackgroundColor)
                .shadow(color: themeManager.currentTheme.textColor.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private func makePhoneCall(_ phoneNumber: String) {
        let cleanedNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let url = URL(string: "tel:\(cleanedNumber)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func sendGroupMessage(_ phoneNumber: String) {
        // Simple SMS fallback - parent view will handle group text functionality
        let cleanedNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let url = URL(string: "sms:\(cleanedNumber)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func sendEmail(_ email: String) {
        if let url = URL(string: "mailto:\(email)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func startGroupText() {
        print("🚀 FamilyView startGroupText() called")
        
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
        APIService.shared.createOrGetGroupChat(contactType: contact.contactType, contactId: contact.contactId) { result in
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
    @State private var showingEditChild = false
    @State private var showingEditOtherFamily = false
    @State private var selectedChild: Child?
    @State private var selectedEmergencyContact: EmergencyContact?
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: Any?
    @State private var deleteAlertTitle = ""
    @State private var deleteAlertMessage = ""
    @State private var selectedContactForGroupText: (contactType: String, contactId: Int, name: String, phone: String)?
    @State private var showMessageComposer = false
    @State private var messageComposeResult: Result<MessageComposeResult, Error>?
    @State private var familyMembers: [FamilyMember] = []
    @StateObject private var groupTextDataStore = FamilyGroupTextDataStore()
    
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
                                    phoneNumber: coparent.phone_number,
                                    email: coparent.email,
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
                                    color: .green,
                                    canEdit: true,
                                    canDelete: true,
                                    onEdit: { editChild(child) },
                                    onDelete: { deleteChild(child) }
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
                        
                        if viewModel.isDataLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading family members...")
                                    .font(.subheadline)
                                    .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                                Spacer()
                            }
                            .padding(.horizontal)
                        } else if viewModel.emergencyContacts.isEmpty {
                            Text("No other family members added yet")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                                .padding(.horizontal)
                        } else {
                            ForEach(viewModel.emergencyContacts) { contact in
                                FamilyMemberCard(
                                    title: contact.fullName,
                                    subtitle: contact.displayRelationship,
                                    phoneNumber: contact.phone_number,
                                    email: contact.notes, // Email is stored in notes field
                                    icon: "person.3",
                                    color: .purple,
                                    canEdit: true,
                                    canDelete: true,
                                    onEdit: { editEmergencyContact(contact) },
                                    onDelete: { deleteEmergencyContact(contact) }
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
        }
        .onChange(of: showingAddOtherFamily) { oldValue, newValue in
            if !newValue {
                // Reset selectedContact when sheet is dismissed
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
        .sheet(isPresented: $showingEditChild) {
            if let child = selectedChild {
                EditChildView(child: child)
                    .environmentObject(viewModel)
                    .environmentObject(themeManager)
            }
        }
        .sheet(isPresented: $showingEditOtherFamily) {
            if let contact = selectedEmergencyContact {
                print("🏗️ Creating EditOtherFamilyView with contact: \(contact.fullName)")
                EditOtherFamilyView(contact: contact)
                    .environmentObject(viewModel)
                    .environmentObject(themeManager)
            } else {
                print("⚠️ No selectedEmergencyContact available for EditOtherFamilyView")
            }
        }
        .onChange(of: showingEditOtherFamily) { oldValue, newValue in
            if !newValue {
                // Reset selectedEmergencyContact when sheet is dismissed
                selectedEmergencyContact = nil
            }
        }
        .alert(deleteAlertTitle, isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                confirmDelete()
            }
            Button("Cancel", role: .cancel) {
                itemToDelete = nil
            }
        } message: {
            Text(deleteAlertMessage)
        }
        .sheet(isPresented: $showMessageComposer, onDismiss: {
            print("🗂️ Sheet dismissed - cleaning up state")
            groupTextDataStore.clearData()
            selectedContactForGroupText = nil
        }) {
            FamilyGroupTextSheetView(
                dataStore: groupTextDataStore,
                familyMembers: familyMembers,
                messageComposeResult: $messageComposeResult,
                showMessageComposer: $showMessageComposer
            )
        }
        .onAppear {
            loadFamilyData()
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
        print("📱 Contact selected: \(contact.givenName) \(contact.familyName)")
        selectedContact = contact
        print("✅ Selected contact stored: \(selectedContact?.givenName ?? "nil")")
        // Add a small delay to ensure the contact picker is fully dismissed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            print("📱 About to show AddOtherFamilyView with contact: \(self.selectedContact?.givenName ?? "nil")")
            if self.selectedContact != nil {
                showingAddOtherFamily = true
            } else {
                print("❌ selectedContact is nil when trying to show AddOtherFamilyView")
            }
        }
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
    
    // MARK: - Edit and Delete Functions
    
    private func editChild(_ child: Child) {
        selectedChild = child
        showingEditChild = true
    }
    
    private func deleteChild(_ child: Child) {
        itemToDelete = child
        deleteAlertTitle = "Delete Child"
        deleteAlertMessage = "Are you sure you want to delete \(child.firstName)? This action cannot be undone."
        showingDeleteAlert = true
    }
    
    private func editEmergencyContact(_ contact: EmergencyContact) {
        print("📱 Emergency contact selected for editing: \(contact.fullName)")
        selectedEmergencyContact = contact
        print("✅ Selected emergency contact stored: \(selectedEmergencyContact?.fullName ?? "nil")")
        // Add a small delay to ensure the contact data is properly set before showing the edit view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("📱 Showing EditOtherFamilyView with contact: \(self.selectedEmergencyContact?.fullName ?? "nil")")
            showingEditOtherFamily = true
        }
    }
    
    private func deleteEmergencyContact(_ contact: EmergencyContact) {
        itemToDelete = contact
        deleteAlertTitle = "Delete Family Member"
        deleteAlertMessage = "Are you sure you want to delete \(contact.fullName)? This action cannot be undone."
        showingDeleteAlert = true
    }
    
    private func confirmDelete() {
        if let child = itemToDelete as? Child {
            viewModel.deleteChild(child.id) { success in
                DispatchQueue.main.async {
                    if success {
                        print("✅ Child deleted successfully")
                        viewModel.fetchChildren()
                    } else {
                        print("❌ Failed to delete child")
                    }
                }
            }
        } else if let contact = itemToDelete as? EmergencyContact {
            viewModel.deleteEmergencyContact(contact.id) { success in
                DispatchQueue.main.async {
                    if success {
                        print("✅ Emergency contact deleted successfully")
                        viewModel.fetchEmergencyContacts()
                    } else {
                        print("❌ Failed to delete emergency contact")
                    }
                }
            }
        }
        itemToDelete = nil
    }
    
    // MARK: - Group Text Functions
    
    private func loadFamilyData() {
        APIService.shared.fetchFamilyMembers { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let members):
                    self.familyMembers = members
                    print("✅ Successfully loaded \(members.count) family members for group text")
                case .failure(let error):
                    print("❌ Failed to load family members: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func startGroupText() {
        print("🚀 FamilyView startGroupText() called")
        
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
        APIService.shared.createOrGetGroupChat(contactType: contact.contactType, contactId: contact.contactId) { result in
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
        if let contact = prefilledContact {
            print("🏗️ AddOtherFamilyView init with contact: \(contact.givenName) \(contact.familyName)")
        } else {
            print("🏗️ AddOtherFamilyView init with no contact")
        }
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
                    print("📱 Prefilling form with contact: \(contact.givenName) \(contact.familyName)")
                    firstName = contact.givenName
                    lastName = contact.familyName
                    email = contact.emailAddresses.first?.value as String? ?? ""
                    phoneNumber = contact.phoneNumbers.first?.value.stringValue ?? ""
                    relationship = "Family Member" // Default relationship
                    print("✅ Form prefilled - First: \(firstName), Last: \(lastName)")
                } else {
                    print("⚠️ No prefilled contact available")
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

// MARK: - Family Message Compose View

struct FamilyMessageComposeView: UIViewControllerRepresentable {
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
        
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let parent: FamilyMessageComposeView

        init(_ parent: FamilyMessageComposeView) {
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

// MARK: - Family Group Text Sheet View

struct FamilyGroupTextSheetView: View {
    @ObservedObject var dataStore: FamilyGroupTextDataStore
    let familyMembers: [FamilyMember]
    @Binding var messageComposeResult: Result<MessageComposeResult, Error>?
    @Binding var showMessageComposer: Bool
    
    var body: some View {
        Group {
            if dataStore.hasValidData, let contact = dataStore.contact {
                FamilyMessageComposeView(
                    recipients: dataStore.recipients,
                    messageBody: "Hi \(contact.name)! This is a group message from the \(getFamilyName()) family.",
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
            print("🗂️ FamilyGroupTextSheetView appeared")
            print("   dataStore.contact: \(String(describing: dataStore.contact))")
            print("   dataStore.recipients: \(dataStore.recipients)")
            print("   dataStore.hasValidData: \(dataStore.hasValidData)")
        }
    }
    
    private func getFamilyName() -> String {
        return familyMembers.first?.last_name ?? "Family"
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

// MARK: - Edit Child View
struct EditChildView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    let child: Child
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
            .navigationTitle("Edit Child")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                firstName = child.firstName
                lastName = child.lastName
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                if let date = dateFormatter.date(from: child.dateOfBirth) {
                    dateOfBirth = date
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
        
        viewModel.updateChild(child.id, childData: childData) { success in
            DispatchQueue.main.async {
                if success {
                    print("✅ Child updated successfully")
                    viewModel.fetchChildren()
                } else {
                    print("❌ Failed to update child")
                }
                dismiss()
            }
        }
    }
}

// MARK: - Edit Other Family View
struct EditOtherFamilyView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    let contact: EmergencyContact
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var relationship = ""
    
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
            .navigationTitle("Edit Family Member")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                print("🏗️ EditOtherFamilyView onAppear with contact: \(contact.fullName)")
                firstName = contact.first_name
                lastName = contact.last_name
                email = contact.notes ?? ""
                phoneNumber = contact.phone_number == "N/A" ? "" : contact.phone_number
                relationship = contact.relationship ?? ""
                print("✅ Form prefilled - First: \(firstName), Last: \(lastName), Relationship: \(relationship)")
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
        let contactData = EmergencyContactCreate(
            first_name: firstName,
            last_name: lastName,
            phone_number: phoneNumber.isEmpty ? "N/A" : phoneNumber,
            relationship: relationship,
            notes: email.isEmpty ? nil : email
        )
        
        viewModel.updateEmergencyContact(contact.id, contactData: contactData) { success in
            DispatchQueue.main.async {
                if success {
                    print("✅ Emergency contact updated successfully")
                    viewModel.fetchEmergencyContacts()
                } else {
                    print("❌ Failed to update emergency contact")
                }
                dismiss()
            }
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
