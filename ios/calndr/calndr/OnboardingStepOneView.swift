import SwiftUI

struct OnboardingStepOneView: View {
    @State private var coparentFirstName = ""
    @State private var coparentLastName = ""
    @State private var coparentEmail = ""
    @State private var coparentPhone = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAlert = false

    var onNext: (String) -> Void  // Pass coparent first name
    var onSkip: () -> Void

    var body: some View {
        VStack {
            Text("Add Your Co-Parent").font(.largeTitle).padding()
            
            VStack(spacing: 15) {
                FloatingLabelTextField(title: "First Name", text: $coparentFirstName, isSecure: false)
                    .frame(height: 56)
                    .autocapitalization(.words)
                
                FloatingLabelTextField(title: "Last Name", text: $coparentLastName, isSecure: false)
                    .frame(height: 56)
                    .autocapitalization(.words)
                
                FloatingLabelTextField(title: "Email", text: $coparentEmail, isSecure: false)
                    .frame(height: 56)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                FloatingLabelTextField(title: "Phone Number", text: $coparentPhone, isSecure: false)
                    .frame(height: 56)
                    .keyboardType(.phonePad)
            }
            .padding(.horizontal)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            HStack {
                Button(action: onSkip) {
                    Text("Skip")
                        .padding()
                }
                
                Spacer()
                
                Button(action: {
                    if allFieldsFilled() {
                        inviteCoParent()
                    } else {
                        onNext("")
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(allFieldsFilled() ? "Invite & Next" : "Next")
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isLoading)
            }
            .padding()
            
            Spacer()
        }
        .padding()
        .alert("Invitation Result", isPresented: $showingAlert) {
            Button("OK") {
                onNext(coparentFirstName.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        } message: {
            Text(errorMessage ?? "Co-parent invitation sent successfully!")
        }
    }
    
    private func allFieldsFilled() -> Bool {
        return !coparentFirstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !coparentLastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !coparentEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func inviteCoParent() {
        isLoading = true
        errorMessage = nil
        
        let phoneNumber = coparentPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : coparentPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        
        APIService.shared.inviteCoParent(
            firstName: coparentFirstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: coparentLastName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: coparentEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: phoneNumber
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(_):
                    errorMessage = nil
                    showingAlert = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
}
