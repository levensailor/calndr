import SwiftUI

struct ContactsView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @State private var familyEmails: [FamilyMemberEmail] = []
    @State private var isLoading = true
    
    var body: some View {
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
                        Text("Loading family contacts...")
                            .foregroundColor(.gray)
                    }
                }
            } else {
                Section(header: Text("Family Members"), footer: Text("Contact information for family members in your calendar.")) {
                    ForEach(familyEmails, id: \.id) { member in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(member.first_name)
                                    .font(.headline)
                                Text(member.email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Add contact buttons
                            HStack(spacing: 12) {
                                Button(action: {
                                    // Email action
                                    if let emailURL = URL(string: "mailto:\(member.email)") {
                                        if UIApplication.shared.canOpenURL(emailURL) {
                                            UIApplication.shared.open(emailURL)
                                        }
                                    }
                                }) {
                                    Image(systemName: "envelope")
                                        .foregroundColor(.blue)
                                }
                                
                                Button(action: {
                                    // Copy email to clipboard
                                    UIPasteboard.general.string = member.email
                                    // Could add a toast notification here
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                if familyEmails.isEmpty {
                    Section {
                        Text("No family members found.")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .navigationTitle("Contacts")
        .onAppear(perform: loadContacts)
        .refreshable {
            await refreshContacts()
        }
    }
    
    private func loadContacts() {
        isLoading = true
        APIService.shared.fetchFamilyMemberEmails { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let emails):
                    self.familyEmails = emails
                case .failure(let error):
                    print("Error fetching family member emails: \(error.localizedDescription)")
                    self.familyEmails = []
                }
            }
        }
    }
    
    private func refreshContacts() async {
        await withCheckedContinuation { continuation in
            APIService.shared.fetchFamilyMemberEmails { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let emails):
                        self.familyEmails = emails
                    case .failure(let error):
                        print("Error refreshing family member emails: \(error.localizedDescription)")
                    }
                    continuation.resume()
                }
            }
        }
    }
} 