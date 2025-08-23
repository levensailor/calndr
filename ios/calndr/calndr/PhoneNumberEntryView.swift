import SwiftUI

struct PhoneNumberEntryView: View {
    @ObservedObject var viewModel: SignUpViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.presentationMode) var presentationMode
    let onPhoneVerified: (String) -> Void
    
    var body: some View {
        ZStack {
            themeManager.currentTheme.mainBackgroundColorSwiftUI.ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Back button
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    Text("Enter Your Phone Number")
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                        .padding(.top, 20)
                    
                    Text("We'll send you a verification code to confirm your number")
                        .font(.body)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(spacing: 15) {
                        FloatingLabelTextField(
                            title: "Phone Number",
                            text: $viewModel.phoneNumber,
                            isSecure: false
                        )
                        .frame(height: 56)
                        .keyboardType(.phonePad)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // Transactional SMS consent fine print
                    Text("By providing your number, you agree to receive a one-time text message from Calndr Club for account verification. Message and data rates may apply.")
                        .font(.caption2)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Button(action: {
                        viewModel.validateAndSendPin { success, phoneNumber in
                            if success {
                                onPhoneVerified(phoneNumber)
                            }
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Send Confirmation Code")
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
                    .padding(.top, 20)
                    
                    Spacer(minLength: 40)
                }
                .padding(.bottom, 20)
            }
            .scrollTargetBehavior(CustomVerticalPagingBehavior())
            .navigationBarHidden(true)
            .onTapGesture {
                // Dismiss keyboard when tapping outside
                hideKeyboard()
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
