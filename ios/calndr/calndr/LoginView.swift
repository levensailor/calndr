import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingSignUp = false

    var body: some View {
        ZStack {
            themeManager.currentTheme.mainBackgroundColorSwiftUI
                .ignoresSafeArea()
                .onTapGesture {
                    // Dismiss keyboard when tapping outside
                    hideKeyboard()
                }
            
            VStack(spacing: 20) {
                Text("calndr")
                    .font(.system(size: 60, weight: .bold, design: .default))
                    .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                
                VStack(spacing: 15) {
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
                    .background(themeManager.currentTheme.accentColorSwiftUI)
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                .disabled(viewModel.isLoading)
                
                Button(action: {
                    showingSignUp = true
                }) {
                    Text("Don't have an account? Sign Up")
                        .font(.footnote)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                        .padding()
                }
                
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success(let authResults):
                        print("Apple sign-in success: \(authResults)")
                        if let credential = authResults.credential as? ASAuthorizationAppleIDCredential,
                           let codeData = credential.authorizationCode,
                           let code = String(data: codeData, encoding: .utf8) {
                            authManager.loginWithApple(authorizationCode: code) { success in
                                // handle UI if needed
                            }
                        }
                    case .failure(let error):
                        print("Apple login failed: \(error.localizedDescription)")
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 45)
                .padding(.horizontal)

                GoogleSignInButton {
                    handleGoogleSignIn()
                }
                .frame(height: 45)
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showingSignUp) {
            SignUpView()
                .environmentObject(authManager)
                .environmentObject(themeManager)
        }
    }
    
    private func handleGoogleSignIn() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("Could not find root view controller.")
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { gidSignInResult, error in
            guard error == nil else {
                viewModel.errorMessage = error?.localizedDescription
                return
            }

            guard let gidSignInResult = gidSignInResult else {
                viewModel.errorMessage = "Google Sign-In failed."
                return
            }
            
            let user = gidSignInResult.user
            let idToken = user.idToken?.tokenString

            // Send idToken to your backend
            if let idToken = idToken {
                authManager.loginWithGoogle(idToken: idToken) { success in
                    if !success {
                        viewModel.errorMessage = "Failed to log in with Google."
                    }
                }
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
} 
