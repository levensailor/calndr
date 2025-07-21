import SwiftUI

struct PhoneVerificationView: View {
    let phoneNumber: String
    let onVerificationComplete: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var pin = ""
    @State private var isLoading = false
    @State private var isResending = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var resendCooldown = 0
    @State private var timer: Timer?
    
    private let pinLength = 6
    
    var body: some View {
        ZStack {
            themeManager.currentTheme.mainBackgroundColorSwiftUI.ignoresSafeArea()
            
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    // Icon
                    Image(systemName: "iphone.and.arrow.forward")
                        .font(.system(size: 60))
                        .foregroundColor(themeManager.currentTheme.accentColorSwiftUI)
                    
                    // Title and Description
                    VStack(spacing: 8) {
                        Text("Verify Your Phone Number")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                            .multilineTextAlignment(.center)
                        
                        Text("We've sent a 6-digit verification code to")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
                            .multilineTextAlignment(.center)
                        
                        Text(formatPhoneNumber(phoneNumber))
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                    }
                }
                .padding(.top, 40)
                
                // PIN Input
                VStack(spacing: 20) {
                    HStack(spacing: 12) {
                        ForEach(0..<pinLength, id: \.self) { index in
                            PinDigitView(
                                digit: index < pin.count ? String(pin[pin.index(pin.startIndex, offsetBy: index)]) : "",
                                isActive: index == pin.count
                            )
                        }
                    }
                    
                    // Hidden text field for input
                    TextField("", text: $pin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .onChange(of: pin) { oldValue, newValue in
                            // Limit to pin length and only digits
                            let filtered = String(newValue.prefix(pinLength).filter { $0.isNumber })
                            if filtered != newValue {
                                pin = filtered
                            }
                            
                            // Auto-verify when PIN is complete
                            if pin.count == pinLength {
                                verifyPin()
                            }
                        }
                        .opacity(0)
                        .frame(width: 1, height: 1)
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
                        Button(action: resendPin) {
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
                        dismiss()
                    }) {
                        Text("Change Phone Number")
                            .font(.footnote)
                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Manual Verify Button (if needed)
                if pin.count == pinLength && !isLoading {
                    Button(action: verifyPin) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Verify")
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
            .padding()
        }
        .navigationBarHidden(true)
        .onAppear {
            // Start resend cooldown
            startResendCooldown()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func verifyPin() {
        guard pin.count == pinLength && !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        APIService.shared.verifyPhonePin(phoneNumber: phoneNumber, pin: pin) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let response):
                    if response.success {
                        successMessage = response.message
                        // Small delay to show success message
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            onVerificationComplete()
                        }
                    } else {
                        errorMessage = response.message
                        // Clear PIN on error
                        pin = ""
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    pin = ""
                }
            }
        }
    }
    
    private func resendPin() {
        guard !isResending else { return }
        
        isResending = true
        errorMessage = nil
        successMessage = nil
        pin = ""
        
        APIService.shared.sendPhoneVerificationPin(phoneNumber: phoneNumber) { result in
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
    
    private func formatPhoneNumber(_ phone: String) -> String {
        let cleaned = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if cleaned.count == 10 {
            return "(\(cleaned.prefix(3))) \(cleaned.dropFirst(3).prefix(3))-\(cleaned.suffix(4))"
        } else if cleaned.count == 11 && cleaned.hasPrefix("1") {
            let withoutCountryCode = String(cleaned.dropFirst())
            return "+1 (\(withoutCountryCode.prefix(3))) \(withoutCountryCode.dropFirst(3).prefix(3))-\(withoutCountryCode.suffix(4))"
        }
        return phone
    }
}

struct PinDigitView: View {
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

struct PhoneVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        let themeManager = ThemeManager()
        
        PhoneVerificationView(
            phoneNumber: "+1234567890",
            onVerificationComplete: {}
        )
        .environmentObject(themeManager)
    }
} 