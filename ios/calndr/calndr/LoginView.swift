import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingSignUp = false

    var body: some View {
        ZStack {
            themeManager.currentTheme.mainBackgroundColor.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("calndr")
                    .font(.custom(themeManager.currentTheme.fontName, size: 60))
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.currentTheme.textColor)
                
                VStack(spacing: 15) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Email")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor)
                        TextField("Enter your email address", text: $viewModel.email)
                            .padding()
                            .background(themeManager.currentTheme.otherMonthBackgroundColor)
                            .cornerRadius(8)
                            .foregroundColor(themeManager.currentTheme.textColor)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Password")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor)
                        SecureField("Enter your password", text: $viewModel.password)
                            .padding()
                            .background(themeManager.currentTheme.otherMonthBackgroundColor)
                            .cornerRadius(8)
                            .foregroundColor(themeManager.currentTheme.textColor)
                    }
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
                    viewModel.login(authManager: authManager)
                }) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Login")
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
                    showingSignUp = true
                }) {
                    Text("Don't have an account? Sign Up")
                        .font(.footnote)
                        .foregroundColor(themeManager.currentTheme.textColor)
                        .padding()
                }
            }
        }
        .sheet(isPresented: $showingSignUp) {
            SignUpView()
                .environmentObject(authManager)
                .environmentObject(themeManager)
        }
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            hideKeyboard()
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
} 
