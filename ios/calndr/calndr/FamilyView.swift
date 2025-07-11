import SwiftUI
import MessageUI

struct FamilyView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = FamilyViewModel()
    
    // State for presenting sheets
    @State private var showingAddEmergencyContact = false
    @State private var showingAddBabysitter = false

    var body: some View {
        NavigationView {
            List {
                CoParentsSection(viewModel: viewModel)
                EmergencyContactsList(viewModel: viewModel, showingAddContact: $showingAddEmergencyContact)
                BabysittersList(viewModel: viewModel, showingAddContact: $showingAddBabysitter)
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Family")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingAddEmergencyContact = true }) {
                            Label("Add Emergency Contact", systemImage: "person.crop.circle.badge.plus")
                        }
                        Button(action: { showingAddBabysitter = true }) {
                            Label("Add Babysitter", systemImage: "figure.2.and.child.holdinghands")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear(perform: viewModel.fetchFamilyData)
            .sheet(isPresented: $showingAddEmergencyContact) {
                // AddContactView will be created here
                Text("Add Emergency Contact (View Pending)")
            }
            .sheet(isPresented: $showingAddBabysitter) {
                // AddContactView will be created here
                Text("Add Babysitter (View Pending)")
            }
            .alert(isPresented: .constant(viewModel.errorMessage != nil), content: {
                Alert(title: Text("Error"), message: Text(viewModel.errorMessage ?? "An unknown error occurred."), dismissButton: .default(Text("OK"), action: {
                    viewModel.errorMessage = nil
                }))
            })
        }
    }
}

// MARK: - Subviews
struct CoParentsSection: View {
    @ObservedObject var viewModel: FamilyViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Section {
            if viewModel.familyMembers.isEmpty && !viewModel.isLoading {
                Text("No co-parents found.")
            } else if viewModel.isLoading {
                ProgressView()
            }
            
            ForEach(viewModel.familyMembers.filter { $0.id != viewModel.currentUserID }, id: \.id) { member in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(themeManager.selectedTheme.secondaryColor)

                        VStack(alignment: .leading) {
                            Text(member.fullName)
                                .font(.headline)
                            Text(member.email)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        
                        Button(action: {
                            viewModel.requestLocation(for: member)
                        }) {
                            Image(systemName: "location.circle.fill")
                                .foregroundColor(themeManager.selectedTheme.accentColor)
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
        } header: {
            Text("CO-PARENTS").font(.headline)
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

struct EmergencyContactsList: View {
    @ObservedObject var viewModel: FamilyViewModel
    @Binding var showingAddContact: Bool
    
    var body: some View {
        Section {
            if viewModel.emergencyContacts.isEmpty && !viewModel.isLoading {
                Text("No emergency contacts found.")
            } else {
                ForEach(viewModel.emergencyContacts) { contact in
                    Text(contact.first_name) // Placeholder
                }
                .onDelete(perform: viewModel.deleteEmergencyContact)
            }
        } header: {
            Text("EMERGENCY CONTACTS").font(.headline)
        }
    }
}

struct BabysittersList: View {
    @ObservedObject var viewModel: FamilyViewModel
    @Binding var showingAddContact: Bool

    var body: some View {
        Section {
            if viewModel.babysitters.isEmpty && !viewModel.isLoading {
                Text("No babysitters found.")
            } else {
                ForEach(viewModel.babysitters) { sitter in
                    Text(sitter.first_name) // Placeholder
                }
                .onDelete(perform: viewModel.deleteBabysitter)
            }
        } header: {
            Text("BABYSITTERS").font(.headline)
        }
    }
}


// MARK: - ViewModel
class FamilyViewModel: ObservableObject {
    @Published var familyMembers: [FamilyMember] = []
    @Published var emergencyContacts: [EmergencyContact] = []
    @Published var babysitters: [Babysitter] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Assuming you have a way to get the current user's ID
    let currentUserID: String = "" // This needs to be fetched from your auth manager

    private let apiService = APIService.shared
    
    func fetchFamilyData() {
        isLoading = true
        errorMessage = nil
        let dispatchGroup = DispatchGroup()
        
        // Fetch Family Members
        dispatchGroup.enter()
        apiService.fetchFamilyMembers { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let members):
                    self?.familyMembers = members
                case .failure(let error):
                    self?.handleError(error, context: "family members")
                }
                dispatchGroup.leave()
            }
        }
        
        // Fetch Emergency Contacts
        dispatchGroup.enter()
        apiService.fetchEmergencyContacts { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let contacts):
                    self?.emergencyContacts = contacts
                case .failure(let error):
                    self?.handleError(error, context: "emergency contacts")
                }
                dispatchGroup.leave()
            }
        }
        
        // Fetch Babysitters
        dispatchGroup.enter()
        apiService.fetchBabysitters { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let sitters):
                    self?.babysitters = sitters
                case .failure(let error):
                    self?.handleError(error, context: "babysitters")
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            self?.isLoading = false
        }
    }
    
    func requestLocation(for member: FamilyMember) {
        apiService.requestLocation(for: member.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("Successfully requested location for \(member.fullName)")
                case .failure(let error):
                    self?.errorMessage = "Failed to request location for \(member.fullName): \(error.localizedDescription)"
                }
            }
        }
    }
    
    func deleteEmergencyContact(at offsets: IndexSet) {
        let contactsToDelete = offsets.map { self.emergencyContacts[$0] }
        for contact in contactsToDelete {
            apiService.deleteEmergencyContact(id: contact.id) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.emergencyContacts.removeAll { $0.id == contact.id }
                    case .failure(let error):
                        self?.errorMessage = "Failed to delete contact: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    func deleteBabysitter(at offsets: IndexSet) {
        let sittersToDelete = offsets.map { self.babysitters[$0] }
        for sitter in sittersToDelete {
            apiService.deleteBabysitter(id: sitter.id) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.babysitters.removeAll { $0.id == sitter.id }
                    case .failure(let error):
                        self?.errorMessage = "Failed to delete babysitter: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func handleError(_ error: Error, context: String) {
        let message = "Failed to load \(context): \(error.localizedDescription)"
        if self.errorMessage == nil {
            self.errorMessage = message
        } else {
            self.errorMessage?.append("\n" + message)
        }
    }
}

// MARK: - Preview
#Preview {
    FamilyView()
        .environmentObject(ThemeManager())
} 
