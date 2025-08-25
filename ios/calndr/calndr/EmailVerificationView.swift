import SwiftUI

struct EmailVerificationView: View {
    let email: String
    let onVerificationComplete: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var verificationCode = ""
    @State private var isLoading = false
    @State private var isResending = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var resendCooldown = 0
    @State private var timer: Timer?
    @FocusState private var isTextFieldFocused: Bool
    @State private var isVerificationComplete = false
    
    private let codeLength = 6
    
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
                        // Icon
                        Image(systemName: "envelope.badge")
                            .font(.system(size: 60))
                            .foregroundColor(themeManager.currentTheme.accentColorSwiftUI)
                        
                        // Title and Description
                        VStack(spacing: 8) {
                            Text("Verify Your Email")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                                .multilineTextAlignment(.center)
                            
                            Text("We've sent a 6-digit verification code to")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
                                .multilineTextAlignment(.center)
                            
                            Text(email)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Code Input
                    VStack(spacing: 20) {
                        ZStack {
                            // Visible code digit boxes
                            HStack(spacing: 12) {
                                ForEach(0..<codeLength, id: \.self) { index in
                                    CodeDigitView(
                                        digit: index < verificationCode.count ? String(verificationCode[verificationCode.index(verificationCode.startIndex, offsetBy: index)]) : "",
                                        isActive: index == verificationCode.count && isTextFieldFocused
                                    )
                                }
                            }
                            
                            // Hidden text field for input - covers the entire code area
                            TextField("", text: $verificationCode)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .focused($isTextFieldFocused)
                                .onChange(of: verificationCode) { oldValue, newValue in
                                    // Limit to code length and only digits
                                    let filtered = String(newValue.prefix(codeLength).filter { $0.isNumber })
                                    if filtered != newValue {
                                        verificationCode = filtered
                                    }
                                    
                                    // Auto-verify when code is complete
                                    if verificationCode.count == codeLength {
                                        verifyCode()
                                    }
                                }
                                .opacity(0.01) // Nearly invisible but still interactive
                                .frame(height: 60) // Match the height of code digit boxes
                                .background(Color.clear)
                        }
                        .onTapGesture {
                            // Immediate focus with haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            isTextFieldFocused = true
                        }
                        
                        // Instruction text
                        if !isTextFieldFocused && verificationCode.isEmpty {
                            Text("Tap above to enter your verification code")
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.6))
                                .padding(.top, 8)
                        }
                    }
                    
                    // Messages
                    VStack(spacing: 8) {
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        
                        if let successMessage = successMessage {
                            Text(successMessage)
                                .font(.footnote)
                                .foregroundColor(.green)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(minHeight: 40)
                    
                    // Resend Button
                    VStack(spacing: 16) {
                        if resendCooldown > 0 {
                            Text("Resend code in \(resendCooldown)s")
                                .font(.footnote)
                                .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.6))
                        } else {
                            Button(action: resendCode) {
                                HStack {
                                    if isResending {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: themeManager.currentTheme.accentColor.color))
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("Resend Code")
                                    }
                                }
                                .font(.footnote)
                                .foregroundColor(themeManager.currentTheme.accentColorSwiftUI)
                            }
                            .disabled(isResending)
                        }
                        
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Change Email Address")
                                .font(.footnote)
                                .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
                        }
                    }
                    
                    Spacer()
                    
                    // Manual Verify Button (if needed)
                    if verificationCode.count == codeLength && !isLoading {
                        Button(action: verifyCode) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Verify Email")
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
                        .disabled(isLoading)
                    }
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
        .onAppear {
            // Send initial verification code
            sendVerificationCode()
            // Start resend cooldown
            startResendCooldown()
            // Focus the text field to show keyboard - reduced delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func sendVerificationCode() {
        APIService.shared.sendEmailVerificationCode(email: email) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if response.success {
                        successMessage = response.message
                        errorMessage = nil
                    } else {
                        errorMessage = response.message
                        successMessage = nil
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    successMessage = nil
                }
            }
        }
    }
    
    private func verifyCode() {
        guard verificationCode.count == codeLength && !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        APIService.shared.verifyEmailCode(email: email, code: verificationCode) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let response):
                    if response.success {
                        successMessage = "Email verified successfully! Please login with your credentials."
                        isVerificationComplete = true
                        // Auto-dismiss after 2 seconds to show login screen
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            onVerificationComplete()
                        }
                    } else {
                        errorMessage = response.message
                        // Clear code on error
                        verificationCode = ""
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    verificationCode = ""
                }
            }
        }
    }
    

    
    private func resendCode() {
        guard !isResending else { return }
        
        isResending = true
        errorMessage = nil
        successMessage = nil
        verificationCode = ""
        
        APIService.shared.resendEmailVerificationCode(email: email) { result in
            DispatchQueue.main.async {
                isResending = false
                
                switch result {
                case .success(let response):
                    if response.success {
                        successMessage = response.message
                        startResendCooldown()
                    } else {
                        errorMessage = response.message
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func startResendCooldown() {
        resendCooldown = 60
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if resendCooldown > 0 {
                resendCooldown -= 1
            } else {
                timer?.invalidate()
                timer = nil
            }
        }
    }
    
    private func hideKeyboard() {
        isTextFieldFocused = false
    }
}

struct CodeDigitView: View {
    let digit: String
    let isActive: Bool
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isActive ? themeManager.currentTheme.accentColor.color : 
                    themeManager.currentTheme.textColor.color.opacity(0.3),
                    lineWidth: isActive ? 2 : 1
                )
                .frame(width: 50, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                )
            
            Text(digit)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
        }
    }
}
