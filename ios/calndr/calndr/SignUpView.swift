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

struct SignUpView: View {
    @StateObject private var viewModel = SignUpViewModel()
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            themeManager.currentTheme.mainBackgroundColor.ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 20) {
                    Text("Create Account")
                        .font(.custom(themeManager.currentTheme.fontName, size: 32))
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.currentTheme.textColor)
                        .padding(.top, 40)
                    
                    VStack(spacing: 15) {
                        FloatingLabelTextField(
                            title: "First Name",
                            text: $viewModel.firstName,
                            isSecure: false,
                            themeManager: themeManager
                        )
                        .autocapitalization(.words)

                        FloatingLabelTextField(
                            title: "Last Name",
                            text: $viewModel.lastName,
                            isSecure: false,
                            themeManager: themeManager
                        )
                        .autocapitalization(.words)

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

                        FloatingLabelTextField(
                            title: "Confirm Password",
                            text: $viewModel.confirmPassword,
                            isSecure: true,
                            themeManager: themeManager
                        )

                        FloatingLabelTextField(
                            title: "Phone Number (Optional)",
                            text: $viewModel.phoneNumber,
                            isSecure: false,
                            themeManager: themeManager
                        )
                        .keyboardType(.phonePad)

                        FloatingLabelTextField(
                            title: "Family Name (Optional)",
                            text: $viewModel.familyName,
                            isSecure: false,
                            themeManager: themeManager
                        )
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
                    .padding(.bottom, 40)
                }
                .padding(.bottom, 20)
            }
        }
        .navigationBarHidden(true)
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            hideKeyboard()
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
} 
