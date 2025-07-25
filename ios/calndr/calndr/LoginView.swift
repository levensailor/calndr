import SwiftUI
import AuthenticationServices
import GoogleSignIn


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
            
            VStack(spacing: 30) {
                // Brutalist app title
                VStack(spacing: 8) {
                    Text("CALNDR")
                        .font(.system(size: 48, weight: .black, design: .default))
                        .tracking(3.0)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                    
                    Rectangle()
                        .fill(themeManager.currentTheme.accentColorSwiftUI)
                        .frame(height: 6)
                        .frame(maxWidth: 200)
                }
                
                VStack(spacing: 20) {
                    BrutalistTextField(
                        title: "Email",
                        text: $viewModel.email,
                        isSecure: false
                    )
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)

                    BrutalistTextField(
                        title: "Password",
                        text: $viewModel.password,
                        isSecure: true
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
                
                BrutalistButton(
                    title: viewModel.isLoading ? "LOADING..." : "LOGIN",
                    action: {
                        viewModel.login(authManager: authManager)
                    },
                    style: .primary
                )
                .disabled(viewModel.isLoading)
                .padding(.horizontal)
                
                BrutalistButton(
                    title: "SIGN UP",
                    action: {
                        showingSignUp = true
                    },
                    style: .secondary
                )
                .padding(.horizontal)
                
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
