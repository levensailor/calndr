import SwiftUI

struct SecuritySettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var biometricEnabled = false
    @State private var sessionTimeout = 30.0

    var body: some View {
        Form {
            Section(header: Text("Authentication")) {
                HStack {
                    Image(systemName: "faceid")
                        .foregroundColor(.blue)
                    Toggle("Enable Biometric Authentication", isOn: $biometricEnabled)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Timeout")
                    Text("\(Int(sessionTimeout)) minutes")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Slider(value: $sessionTimeout, in: 5...120, step: 5)
                }
            }
            
            Section(header: Text("Privacy")) {
                HStack {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.green)
                    VStack(alignment: .leading) {
                        Text("App Lock")
                        Text("Require authentication to open app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: .constant(false))
                }
                
                HStack {
                    Image(systemName: "eye.slash")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading) {
                        Text("Hide Sensitive Content")
                        Text("Hide event details in notifications")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: .constant(false))
                }
            }

            Section(header: Text("Account"), footer: Text("Password changes have been moved to the Account tab")) {
                Button(action: {
                    authManager.logout()
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                        Text("Logout")
                            .foregroundColor(.red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .navigationTitle("Security")
    }
} 