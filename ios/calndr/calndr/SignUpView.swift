import SwiftUI

struct SignUpView: View {
    @StateObject private var viewModel = SignUpViewModel()
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            themeManager.currentTheme.mainBackgroundColor.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 20) {
                    Text("Create Account")
                        .font(.custom(themeManager.currentTheme.fontName, size: 32))
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.currentTheme.textColor)
                        .padding(.top, 40)
                    
                    VStack(spacing: 15) {
                        TextField("Enter your first name", text: $viewModel.firstName)
                            .padding()
                            .background(themeManager.currentTheme.otherMonthBackgroundColor)
                            .cornerRadius(8)
                            .foregroundColor(themeManager.currentTheme.textColor)
                            .autocapitalization(.words)

                        TextField("Enter your last name", text: $viewModel.lastName)
                            .padding()
                            .background(themeManager.currentTheme.otherMonthBackgroundColor)
                            .cornerRadius(8)
                            .foregroundColor(themeManager.currentTheme.textColor)
                            .autocapitalization(.words)

                        TextField("Enter your email address", text: $viewModel.email)
                            .padding()
                            .background(themeManager.currentTheme.otherMonthBackgroundColor)
                            .cornerRadius(8)
                            .foregroundColor(themeManager.currentTheme.textColor)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)

                        SecureField("Enter your password", text: $viewModel.password)
                            .padding()
                            .background(themeManager.currentTheme.otherMonthBackgroundColor)
                            .cornerRadius(8)
                            .foregroundColor(themeManager.currentTheme.textColor)

                        SecureField("Confirm your password", text: $viewModel.confirmPassword)
                            .padding()
                            .background(themeManager.currentTheme.otherMonthBackgroundColor)
                            .cornerRadius(8)
                            .foregroundColor(themeManager.currentTheme.textColor)

                        TextField("Phone number (optional)", text: $viewModel.phoneNumber)
                            .padding()
                            .background(themeManager.currentTheme.otherMonthBackgroundColor)
                            .cornerRadius(8)
                            .foregroundColor(themeManager.currentTheme.textColor)
                            .keyboardType(.phonePad)

                        TextField("Family name (optional)", text: $viewModel.familyName)
                            .padding()
                            .background(themeManager.currentTheme.otherMonthBackgroundColor)
                            .cornerRadius(8)
                            .foregroundColor(themeManager.currentTheme.textColor)
                            .autocapitalization(.words)
                    }
                    .padding(.horizontal)
                    
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Button(action: {
                        viewModel.signUp(authManager: authManager)
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
                        .background(themeManager.currentTheme.todayBorderColor)
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    .disabled(viewModel.isLoading)
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Already have an account? Sign In")
                            .font(.footnote)
                            .foregroundColor(themeManager.currentTheme.textColor)
                            .padding()
                    }
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationBarHidden(true)
    }
} 