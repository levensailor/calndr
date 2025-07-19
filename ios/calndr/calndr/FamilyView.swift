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
    let canGroupText: Bool
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onGroupText: (() -> Void)?
    @EnvironmentObject var themeManager: ThemeManager
    
    init(title: String, subtitle: String, detail: String? = nil, phoneNumber: String? = nil, email: String? = nil, icon: String, color: Color, canEdit: Bool = false, canDelete: Bool = false, canGroupText: Bool = false, onEdit: (() -> Void)? = nil, onDelete: (() -> Void)? = nil, onGroupText: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.phoneNumber = phoneNumber
        self.email = email
        self.icon = icon
        self.color = color
        self.canEdit = canEdit
        self.canDelete = canDelete
        self.canGroupText = canGroupText
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onGroupText = onGroupText
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
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    if canEdit {
                        Button(action: { onEdit?() }) {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color.blue.opacity(0.1)))
                        }
                    }
                    
                    if canDelete {
                        Button(action: { onDelete?() }) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color.red.opacity(0.1)))
                        }
                    }
                    if canGroupText {
                        Button(action: { onGroupText?() }) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(Color.blue.opacity(0.1)))
                            .foregroundColor(.blue)
//                            .padding(.horizontal, 8)
//                            .padding(.vertical, 4)
//                            .background(Capsule().fill(Color.blue.opacity(0.1)))
                        }
                    }
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
                    
                }
                .padding(.top, 4)
            } else if let email = email {
                HStack {
                    Image(systemName: "envelope.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Button(action: { 
                        if let url = URL(string: "mailto:\(email)") {
                            UIApplication.shared.open(url)
                        }
                    }) {
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
                .fill(themeManager.currentTheme.secondaryBackgroundColor.color)
                .shadow(color: themeManager.currentTheme.textColor.color.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private func makePhoneCall(_ phoneNumber: String) {
        let cleanedNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let url = URL(string: "tel:\(cleanedNumber)") {
            UIApplication.shared.open(url)
        }
    }
}

struct FamilyView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAddChild = false
    @State private var showingAddEmergencyContact = false
    @State private var showingContactPicker = false
    @State private var showingAddOptionsSheet = false
    @State private var selectedContact: CNContact?
    @State private var showingContactPermissionAlert = false
    @State private var showingEditChild = false
    @State private var showingEditEmergencyContact = false
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

    // Precompute filtered co-parents
    private var filteredCoParents: [FamilyMember] {
        familyMembers.filter { $0.id != viewModel.currentUserID }
    }
    private var filteredEmergencyContacts: [EmergencyContact] {
        viewModel.emergencyContacts
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Family")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.currentTheme.textColor.color)
                        
                        Text("Manage your family members and relationships")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                    }
                    .padding(.horizontal)
                    
                    // Coparents Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Coparents")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(themeManager.currentTheme.textColor.color)
                            
                            Spacer()
                            
//                            Button(action: {
//                                // Request location for co-parent
//                                if let firstCoParent = filteredCoParents.first {
//                                    requestLocation(for: firstCoParent)
//                                }
//                            }) {
//                                Image(systemName: "location.circle.fill")
//                                    .font(.title3)
//                                    .foregroundColor(.blue)
//                            }
                        }
                        .padding(.horizontal)
                        
                        if filteredCoParents.isEmpty {
                            Text("No coparents found")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                                .padding(.horizontal)
                        } else {
                            ForEach(filteredCoParents) { member in
                                CoParentRow(member: member, onRequestLocation: {
                                    requestLocation(for: member)
                                })
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Children Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Children")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(themeManager.currentTheme.textColor.color)
                            
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
                                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                                .padding(.horizontal)
                        } else {
                            ForEach(viewModel.children) { child in
                                FamilyMemberCard(
                                    title: child.firstName,
                                    subtitle: "\(child.age) years old",
                                    detail: "\(child.age) years old",
                                    icon: "figure.child",
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
                    
                    // Emergency Contacts Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Emergency Contacts")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(themeManager.currentTheme.textColor.color)
                            
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
                                Text("Loading emergency contacts...")
                                    .font(.subheadline)
                                    .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                                Spacer()
                            }
                            .padding(.horizontal)
                        } else if filteredEmergencyContacts.isEmpty {
                            Text("No emergency contacts added yet")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                                .padding(.horizontal)
                        } else {
                            ForEach(filteredEmergencyContacts) { contact in
                                FamilyMemberCard(
                                    title: contact.fullName,
                                    subtitle: contact.displayRelationship,
                                    phoneNumber: contact.phone_number,
                                    email: contact.notes,
                                    icon: "person.badge.key",
                                    color: .purple,
                                    canEdit: true,
                                    canDelete: true,
                                    canGroupText: true,
                                    onEdit: { editEmergencyContact(contact) },
                                    onDelete: { deleteEmergencyContact(contact) },
                                    onGroupText: { startGroupText(contact: contact) }
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    Spacer(minLength: 80)
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor.color)
        }
        .sheet(isPresented: $showingAddChild) {
            AddChildView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingAddEmergencyContact) {
            AddEmergencyContactView(prefilledContact: selectedContact)
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
        .onChange(of: showingAddEmergencyContact) { oldValue, newValue in
            if !newValue {
                selectedContact = nil
            }
        }
        .confirmationDialog("Add Emergency Contact", isPresented: $showingAddOptionsSheet) {
            Button("Add Manually") {
                showingAddEmergencyContact = true
            }
            Button("Choose from Contacts") {
                requestContactsPermission()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("How would you like to add an emergency contact?")
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
            Text("To add emergency contacts from your contacts, please enable Contacts access in Settings.")
        }
        .sheet(isPresented: $showingEditChild) {
            if let child = selectedChild {
                EditChildView(child: child)
                    .environmentObject(viewModel)
                    .environmentObject(themeManager)
            }
        }
        .sheet(isPresented: $showingEditEmergencyContact) {
            if let contact = selectedEmergencyContact {
                EditEmergencyContactView(contact: contact)
                    .environmentObject(viewModel)
                    .environmentObject(themeManager)
            }
        }
        .onChange(of: showingEditEmergencyContact) { oldValue, newValue in
            if !newValue {
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
    
    // MARK: - Helper Functions
    
    private func requestLocation(for member: FamilyMember) {
        APIService.shared.requestLocation(for: member.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("Successfully requested location for \(member.fullName)")
                case .failure(let error):
                    print("Failed to request location for \(member.fullName): \(error.localizedDescription)")
                }
            }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if self.selectedContact != nil {
                showingAddEmergencyContact = true
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
        selectedEmergencyContact = contact
        showingEditEmergencyContact = true
    }
    
    private func deleteEmergencyContact(_ contact: EmergencyContact) {
        itemToDelete = contact
        deleteAlertTitle = "Delete Emergency Contact"
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
    
    private func startGroupText(contact: EmergencyContact) {
        print("🚀 FamilyView startGroupText() called for \(contact.fullName)")
        
        guard MFMessageComposeViewController.canSendText() else {
            print("❌ Device cannot send text messages")
            return
        }
        
        let familyPhoneNumbers = getFamilyPhoneNumbers()
        var allNumbers = [contact.phone_number]
        allNumbers.append(contentsOf: familyPhoneNumbers)
        let uniqueNumbers = Array(Set(allNumbers)).filter { !$0.isEmpty && $0 != "N/A" }
        
        guard !uniqueNumbers.isEmpty else {
            print("❌ No phone numbers available for group text")
            return
        }
        
        APIService.shared.createOrGetGroupChat(contactType: "emergency", contactId: contact.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    self.groupTextDataStore.setData(
                        contact: (name: contact.fullName, phone: contact.phone_number),
                        recipients: uniqueNumbers
                    )
                    self.showMessageComposer = true
                case .failure(let error):
                    print("❌ API call failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func getFamilyPhoneNumbers() -> [String] {
        let currentUserID = viewModel.currentUserID
        return familyMembers.compactMap { member -> String? in
            if member.id == currentUserID { return nil }
            let phone = member.phone_number?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (phone?.isEmpty == false) ? phone : nil
        }
    }

    private func formattedTimestamp(from dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let relativeFormatter = RelativeDateTimeFormatter()
            relativeFormatter.unitsStyle = .full
            return relativeFormatter.localizedString(for: date, relativeTo: Date())
        }
        
        return "recently"
    }
}

struct CoParentRow: View {
    let member: FamilyMember
    let onRequestLocation: () -> Void
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.blue)
                VStack(alignment: .leading) {
                    Text(member.fullName)
                        .font(.headline)
                    Text(member.email)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
                Button(action: onRequestLocation) {
                    Image(systemName: "location.circle.fill")
                        .foregroundColor(.blue)
                        .imageScale(.large)
                }
                .buttonStyle(PlainButtonStyle())
            }
            if let location = member.last_known_location, !location.isEmpty, let timestamp = member.last_known_location_timestamp {
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("Last seen: \(formattedTimestamp(from: timestamp))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.leading, 50)
            }
        }
        .padding(.vertical, 5)
    }
    
    private func formattedTimestamp(from dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let relativeFormatter = RelativeDateTimeFormatter()
            relativeFormatter.unitsStyle = .full
            return relativeFormatter.localizedString(for: date, relativeTo: Date())
        }
        return "recently"
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
                        isSecure: false
                    )
                    
                    FloatingLabelTextField(
                        title: "Last Name",
                        text: $lastName,
                        isSecure: false
                    )
                    
                    DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor.color)
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
                        isSecure: false
                    )
                    
                    FloatingLabelTextField(
                        title: "Last Name",
                        text: $lastName,
                        isSecure: false
                    )
                    
                    DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor.color)
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

// MARK: - Add Emergency Contact View
struct AddEmergencyContactView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    let prefilledContact: CNContact?
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var relationship = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Emergency Contact Information") {
                    FloatingLabelTextField(
                        title: "First Name",
                        text: $firstName,
                        isSecure: false
                    )
                    
                    FloatingLabelTextField(
                        title: "Last Name",
                        text: $lastName,
                        isSecure: false
                    )
                    
                    FloatingLabelTextField(
                        title: "Email (Optional)",
                        text: $email,
                        isSecure: false
                    )
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    
                    FloatingLabelTextField(
                        title: "Phone Number",
                        text: $phoneNumber,
                        isSecure: false
                    )
                    .keyboardType(.phonePad)
                    
                    FloatingLabelTextField(
                        title: "Relationship",
                        text: $relationship,
                        isSecure: false
                    )
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor.color)
            .navigationTitle("Add Emergency Contact")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let contact = prefilledContact {
                    firstName = contact.givenName
                    lastName = contact.familyName
                    email = contact.emailAddresses.first?.value as String? ?? ""
                    phoneNumber = contact.phoneNumbers.first?.value.stringValue ?? ""
                    relationship = "Emergency Contact"
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
                        saveEmergencyContact()
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty || phoneNumber.isEmpty || relationship.isEmpty)
                }
            }
        }
    }
    
    private func saveEmergencyContact() {
        let contactData = EmergencyContactCreate(
            first_name: firstName,
            last_name: lastName,
            phone_number: phoneNumber,
            relationship: relationship,
            notes: email.isEmpty ? nil : email
        )
        
        viewModel.saveEmergencyContact(contactData) { success in
            DispatchQueue.main.async {
                if success {
                    print("✅ Emergency contact saved successfully")
                    dismiss()
                } else {
                    print("❌ Failed to save emergency contact")
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Edit Emergency Contact View
struct EditEmergencyContactView: View {
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
                Section("Emergency Contact Information") {
                    FloatingLabelTextField(
                        title: "First Name",
                        text: $firstName,
                        isSecure: false
                    )
                    
                    FloatingLabelTextField(
                        title: "Last Name",
                        text: $lastName,
                        isSecure: false
                    )
                    
                    FloatingLabelTextField(
                        title: "Email (Optional)",
                        text: $email,
                        isSecure: false
                    )
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    
                    FloatingLabelTextField(
                        title: "Phone Number",
                        text: $phoneNumber,
                        isSecure: false
                    )
                    .keyboardType(.phonePad)
                    
                    FloatingLabelTextField(
                        title: "Relationship",
                        text: $relationship,
                        isSecure: false
                    )
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor.color)
            .navigationTitle("Edit Emergency Contact")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                firstName = contact.first_name
                lastName = contact.last_name
                email = contact.notes ?? ""
                phoneNumber = contact.phone_number == "N/A" ? "" : contact.phone_number
                relationship = contact.relationship ?? ""
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEmergencyContact()
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty || phoneNumber.isEmpty || relationship.isEmpty)
                }
            }
        }
    }
    
    private func saveEmergencyContact() {
        let contactData = EmergencyContactCreate(
            first_name: firstName,
            last_name: lastName,
            phone_number: phoneNumber,
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

// MARK: - Supporting Views for Group Text

struct FamilyMessageComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let messageBody: String
    @Binding var result: Result<MessageComposeResult, Error>?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = context.coordinator
        
        let validRecipients = recipients.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        controller.recipients = validRecipients
        controller.body = messageBody
        
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

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
                parent.result = .success(.cancelled)
            case .sent:
                parent.result = .success(.sent)
            case .failed:
                parent.result = .failure(NSError(domain: "MessageComposeError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to send message"]))
            @unknown default:
                parent.result = .failure(NSError(domain: "MessageComposeError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unknown result"]))
            }
            
            parent.dismiss()
        }
    }
}

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
                }
                .padding()
            }
        }
    }
    
    private func getFamilyName() -> String {
        return familyMembers.first?.last_name ?? "Family"
    }
}

struct ContactPickerView: UIViewControllerRepresentable {
    let onContactSelected: (CNContact) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactEmailAddressesKey, CNContactPhoneNumbersKey]
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
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

#Preview {
    FamilyView()
        .environmentObject(ThemeManager())
} 
