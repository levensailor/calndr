import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ZStack {
            themeManager.currentTheme.mainBackgroundColor.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("calndr")
                    .font(.custom(themeManager.currentTheme.fontName, size: 60))
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.currentTheme.textColor)
                
                VStack(spacing: 15) {
                    TextField("Email", text: $viewModel.email)
                        .padding()
                        .background(themeManager.currentTheme.otherMonthBackgroundColor)
                        .cornerRadius(8)
                        .foregroundColor(themeManager.currentTheme.textColor)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField("Password", text: $viewModel.password)
                        .padding()
                        .background(themeManager.currentTheme.otherMonthBackgroundColor)
                        .cornerRadius(8)
                        .foregroundColor(themeManager.currentTheme.textColor)
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
            }
        }
    }
} 