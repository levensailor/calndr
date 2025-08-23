import SwiftUI

struct SignUpView: View {
    @StateObject private var viewModel = SignUpViewModel()
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.presentationMode) var presentationMode
    @State private var isOnboardingPresented = false
    @State private var showingPhoneVerification = false
    @State private var phoneToVerify = ""
    
    var body: some View {
        ZStack {
            themeManager.currentTheme.mainBackgroundColorSwiftUI.ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 20) {
                    Text("Create Account")
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                        .padding(.top, 40)
                    
                    VStack(spacing: 15) {
                        FloatingLabelTextField(
                            title: "First Name",
                            text: $viewModel.firstName,
                            isSecure: false
                        )
                        .frame(height: 56)
                        .autocapitalization(.words)
                        
                        FloatingLabelTextField(
                            title: "Last Name",
                            text: $viewModel.lastName,
                            isSecure: false
                        )
                        .frame(height: 56)
                        .autocapitalization(.words)
                        
                        FloatingLabelTextField(
                            title: "Email",
                            text: $viewModel.email,
                            isSecure: false
                        )
                        .frame(height: 56)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        
                        FloatingLabelTextField(
                            title: "Password",
                            text: $viewModel.password,
                            isSecure: true
                        )
                        .frame(height: 56)
                        
                        FloatingLabelTextField(
                            title: "Confirm Password",
                            text: $viewModel.confirmPassword,
                            isSecure: true
                        )
                        .frame(height: 56)
                        
                        FloatingLabelTextField(
                            title: "Phone Number",
                            text: $viewModel.phoneNumber,
                            isSecure: false
                        )
                        .frame(height: 56)
                        .keyboardType(.phonePad)
                    }
                    .padding(.horizontal)
                    
                    // SMS consent fine print
                    Text("By providing your number, you agree to receive a one-time text message from Calndr Club for account verification. Message and data rates may apply.")
                        .font(.caption2)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 5)
                    
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Button(action: {
                        // First validate phone number and send PIN
                        viewModel.validateAndSendPin { success, phoneNumber in
                            if success {
                                phoneToVerify = phoneNumber
                                showingPhoneVerification = true
                            }
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Create Account")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(themeManager.currentTheme.accentColorSwiftUI)
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    .disabled(viewModel.isLoading)
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Already have an account? Sign In")
                            .font(.footnote)
                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                            .padding()
                    }
                    .padding(.bottom, 40)
                }
                .padding(.bottom, 20)
            }
            .scrollTargetBehavior(CustomVerticalPagingBehavior())
            .navigationBarHidden(true)
            .onTapGesture {
                // Dismiss keyboard when tapping outside
                hideKeyboard()
            }
            .fullScreenCover(isPresented: $showingPhoneVerification) {
                PhoneVerificationView(phoneNumber: phoneToVerify) {
                    // Phone verified, now complete signup
                    viewModel.completeSignUp(authManager: authManager) { success in
                        if success {
                            showingPhoneVerification = false
                            isOnboardingPresented = true
                        }
                    }
                }
                .environmentObject(themeManager)
            }
            .fullScreenCover(isPresented: $isOnboardingPresented) {
                OnboardingView(isOnboardingComplete: $isOnboardingPresented)
                    .environmentObject(authManager)
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
