import SwiftUI

struct FamilyEnrollmentView: View {
    @ObservedObject var viewModel: SignUpViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.presentationMode) var presentationMode
    let onEnrollmentComplete: (Bool) -> Void
    
    @State private var selectedOption: EnrollmentOption?
    @State private var enteredCode = ""
    @State private var showingCodeEntry = false
    @State private var showingCodeCreation = false
    @State private var generatedCode: String?
    
    enum EnrollmentOption {
        case enterCode
        case createCode
    }
    
    var body: some View {
        ZStack {
            themeManager.currentTheme.mainBackgroundColorSwiftUI.ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 30) {
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
                    
                    VStack(spacing: 16) {
                        Text("Family Enrollment")
                            .font(.system(size: 32, weight: .bold, design: .default))
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                        
                        Text("Link with your co-parent to share calendar and messaging")
                            .font(.body)
                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    if selectedOption == nil {
                        // Option selection
                        VStack(spacing: 20) {
                            // Enter Code Option
                            Button(action: {
                                selectedOption = .enterCode
                                showingCodeEntry = true
                            }) {
                                VStack(spacing: 12) {
                                    Image(systemName: "keyboard")
                                        .font(.system(size: 40))
                                        .foregroundColor(themeManager.currentTheme.accentColorSwiftUI)
                                    
                                    Text("Enter Enrollment Code")
                                        .font(.headline)
                                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                                    
                                    Text("I have a code from my co-parent")
                                        .font(.caption)
                                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                }
                                .padding(24)
                                .frame(maxWidth: .infinity)
                                .background(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(themeManager.currentTheme.textColorSwiftUI.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal)
                            
                            // Create Code Option
                            Button(action: {
                                selectedOption = .createCode
                                showingCodeCreation = true
                                // Immediately generate the code when option is selected
                                print("📱 Selected create code option")
                                viewModel.createEnrollmentCode { success, code in
                                    print("📱 Code generation callback - success: \(success), code: \(code ?? "nil")")
                                    if success, let code = code {
                                        print("📱 Setting generated code: \(code)")
                                        generatedCode = code
                                        viewModel.generatedCode = code
                                    }
                                }
                            }) {
                                VStack(spacing: 12) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 40))
                                        .foregroundColor(themeManager.currentTheme.accentColorSwiftUI)
                                    
                                    Text("Create Enrollment Code")
                                        .font(.headline)
                                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                                    
                                    Text("I'm the first parent to enroll")
                                        .font(.caption)
                                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                }
                                .padding(24)
                                .frame(maxWidth: .infinity)
                                .background(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(themeManager.currentTheme.textColorSwiftUI.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal)
                            
                            // Skip Option
                            Button(action: {
                                // Skip enrollment and proceed to onboarding
                                onEnrollmentComplete(true)
                            }) {
                                VStack(spacing: 8) {
                                    Text("Skip for Now")
                                        .font(.headline)
                                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
                                    
                                    Text("I'll set this up later")
                                        .font(.caption)
                                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.5))
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity)
                                .background(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(themeManager.currentTheme.textColorSwiftUI.opacity(0.3), lineWidth: 1)
                                        .background(Color.clear)
                                )
                            }
                            .padding(.horizontal)
                            .padding(.top, 10)
                        }
                    }
                    
                    // Code Entry View
                    if showingCodeEntry {
                        VStack(spacing: 20) {
                            Text("Enter Enrollment Code")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                            
                            Text("Enter the 6-digit code provided by your co-parent")
                                .font(.body)
                                .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            FloatingLabelTextField(
                                title: "Enrollment Code",
                                text: $enteredCode,
                                isSecure: false
                            )
                            .frame(height: 56)
                            .keyboardType(.numberPad)
                            .padding(.horizontal)
                            
                            if let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.footnote)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            
                            Button(action: {
                                viewModel.validateEnrollmentCode(enteredCode) { success in
                                    if success {
                                        viewModel.enteredValidCode = true
                                        completeSignUp()
                                    }
                                }
                            }) {
                                HStack {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Verify Code")
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
                            .disabled(viewModel.isLoading || enteredCode.count != 6)
                            
                            Button(action: {
                                selectedOption = nil
                                showingCodeEntry = false
                                enteredCode = ""
                                viewModel.errorMessage = nil
                            }) {
                                Text("Back to Options")
                                    .font(.footnote)
                                    .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
                            }
                        }
                    }
                    
                    // Code Creation View
                    if showingCodeCreation {
                        VStack(spacing: 20) {
                            if let code = generatedCode {
                                // Use the new EnrollmentCodeDisplayView
                                EnrollmentCodeDisplayView(code: code)
                                    .environmentObject(themeManager)
                                
                                Button(action: {
                                    completeSignUp()
                                }) {
                                    HStack {
                                        if viewModel.isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            Text("Continue")
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
                                
                            } else {
                                // Loading state while generating code
                                VStack(spacing: 20) {
                                    Text("Creating Enrollment Code")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                                    
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: themeManager.currentTheme.accentColorSwiftUI))
                                            .scaleEffect(1.5)
                                        
                                        Text("Generating your enrollment code...")
                                            .font(.body)
                                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal)
                                    }
                                    
                                    if let errorMessage = viewModel.errorMessage {
                                        Text(errorMessage)
                                            .foregroundColor(.red)
                                            .font(.footnote)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal)
                                        
                                        Button(action: {
                                            viewModel.createEnrollmentCode { success, code in
                                                if success, let code = code {
                                                    generatedCode = code
                                                }
                                            }
                                        }) {
                                            Text("Try Again")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .padding()
                                                .frame(maxWidth: .infinity)
                                                .background(themeManager.currentTheme.accentColorSwiftUI)
                                                .cornerRadius(10)
                                                .padding(.horizontal)
                                        }
                                    }
                                    
                                    Button(action: {
                                        selectedOption = nil
                                        showingCodeCreation = false
                                        generatedCode = nil
                                        viewModel.errorMessage = nil
                                    }) {
                                        Text("Back to Options")
                                            .font(.footnote)
                                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
                                    }
                                }
                            }
                        }
                    }
                    
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
    
    private func completeSignUp() {
        print("📱 FamilyEnrollmentView: Completing signup/enrollment")
        viewModel.completeSignUpWithFamily(authManager: authManager) { success in
            print("📱 FamilyEnrollmentView: Signup/enrollment completed with success=\(success)")
            onEnrollmentComplete(success)
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
