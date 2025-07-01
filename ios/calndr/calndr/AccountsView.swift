import SwiftUI

struct AccountsView: View {
    @StateObject private var passwordViewModel = PasswordViewModel()
    @State private var userProfile: UserProfile?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showPasswordModal = false
    @State private var showBillingModal = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("Loading profile...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("Unable to load profile")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        Button("Retry") {
                            fetchUserProfile()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let profile = userProfile {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Profile Header
                            VStack(spacing: 12) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.blue)
                                
                                Text("\(profile.first_name) \(profile.last_name)")
                                    .font(.title2.bold())
                                
                                Text(profile.email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top)
                            
                            // Profile Information
                            VStack(spacing: 16) {
                                ProfileRowView(title: "First Name", value: profile.first_name)
                                ProfileRowView(title: "Last Name", value: profile.last_name)
                                ProfileRowView(title: "Email", value: profile.email)
                                ProfileRowView(title: "Phone Number", value: profile.phone_number ?? "Not provided")
                                ProfileRowView(title: "Subscription", value: formatSubscription(profile))
                            }
                            .padding(.horizontal)
                            
                            Spacer(minLength: 40)
                            
                            // Action Buttons
                            VStack(spacing: 12) {
                                Button(action: {
                                    showBillingModal = true
                                }) {
                                    HStack {
                                        Image(systemName: "creditcard")
                                        Text("Manage Billing")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                
                                Button(action: {
                                    showPasswordModal = true
                                }) {
                                    HStack {
                                        Image(systemName: "key")
                                        Text("Change Password")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                                    .foregroundColor(.primary)
                                    .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle("Account")
            .onAppear {
                fetchUserProfile()
            }
            .sheet(isPresented: $showPasswordModal) {
                PasswordChangeModal(viewModel: passwordViewModel)
            }
            .sheet(isPresented: $showBillingModal) {
                BillingManagementModal()
            }
        }
    }
    
    private func fetchUserProfile() {
        isLoading = true
        errorMessage = nil
        
        APIService.shared.fetchUserProfile { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let profile):
                    self.userProfile = profile
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func formatSubscription(_ profile: UserProfile) -> String {
        let type = profile.subscription_type ?? "Free"
        let status = profile.subscription_status ?? "Active"
        return "\(type) (\(status))"
    }
}

struct ProfileRowView: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct PasswordChangeModal: View {
    @ObservedObject var viewModel: PasswordViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Change your account password")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Password")
                            .font(.headline)
                        SecureField("Enter current password", text: $viewModel.currentPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("New Password")
                            .font(.headline)
                        SecureField("Enter new password", text: $viewModel.newPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Confirm New Password")
                            .font(.headline)
                        SecureField("Confirm new password", text: $viewModel.confirmPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    if !viewModel.passwordUpdateMessage.isEmpty {
                        Text(viewModel.passwordUpdateMessage)
                            .font(.caption)
                            .foregroundColor(viewModel.isPasswordUpdateSuccessful ? .green : .red)
                            .padding(.top, 8)
                    }
                }
                .padding()
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button("Update Password") {
                        viewModel.updatePassword()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(viewModel.currentPassword.isEmpty || 
                             viewModel.newPassword.isEmpty || 
                             viewModel.confirmPassword.isEmpty)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: viewModel.isPasswordUpdateSuccessful) { success in
                if success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct BillingManagementModal: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    Image(systemName: "creditcard.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Billing Management")
                        .font(.title2.bold())
                    
                    Text("Manage your subscription, payment methods, and billing history.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                VStack(spacing: 12) {
                    Button("View Subscription Details") {
                        // TODO: Implement subscription details
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button("Update Payment Method") {
                        // TODO: Implement payment method update
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button("Billing History") {
                        // TODO: Implement billing history
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button("Cancel Subscription") {
                        // TODO: Implement subscription cancellation
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("Billing")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct AccountsView_Previews: PreviewProvider {
    static var previews: some View {
        AccountsView()
    }
} 