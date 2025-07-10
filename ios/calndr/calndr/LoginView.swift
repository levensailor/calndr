import SwiftUI

struct FloatingLabelTextField: View {
    let title: String
    @Binding var text: String
    let isSecure: Bool
    let themeManager: ThemeManager
    @FocusState private var isFocused: Bool
    
    private var shouldPlaceHolderMove: Bool {
        isFocused || !text.isEmpty
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            Text(title)
                .foregroundColor(shouldPlaceHolderMove ? themeManager.currentTheme.accentColor : themeManager.currentTheme.textColor.opacity(0.6))
                .offset(y: shouldPlaceHolderMove ? -25 : 0)
                .scaleEffect(shouldPlaceHolderMove ? 0.8 : 1.0, anchor: .leading)
                .animation(.easeInOut(duration: 0.2), value: shouldPlaceHolderMove)
            
            Group {
                if isSecure {
                    SecureField("", text: $text)
                        .focused($isFocused)
                } else {
                    TextField("", text: $text)
                        .focused($isFocused)
                }
            }
            .padding(.top, shouldPlaceHolderMove ? 15 : 0)
            .animation(.easeInOut(duration: 0.2), value: shouldPlaceHolderMove)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? themeManager.currentTheme.accentColor : themeManager.currentTheme.textColor.opacity(0.3), lineWidth: isFocused ? 2 : 1)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeManager.currentTheme.otherMonthBackgroundColor)
                )
        )
        .foregroundColor(themeManager.currentTheme.textColor)
    }
}

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
                    FloatingLabelTextField(
                        title: "Email",
                        text: $viewModel.email,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)

                    FloatingLabelTextField(
                        title: "Password",
                        text: $viewModel.password,
                        isSecure: true,
                        themeManager: themeManager
                    )
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
