import SwiftUI

struct OnboardingStepOneView: View {
    @State private var coparentFirstName = ""
    @State private var coparentLastName = ""
    @State private var coparentEmail = ""
    @State private var coparentPhone = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAlert = false
    @State private var activeField: Field? = nil
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var keyboardHeight: CGFloat = 0
    @EnvironmentObject var themeManager: ThemeManager
    
    // Enum to track which field is active
    enum Field: Int, Hashable {
        case firstName, lastName, email, phone
    }

    var onNext: (String) -> Void  // Pass coparent first name
    var onSkip: () -> Void
    var onBack: () -> Void  // Go back to previous step
    var generatedCode: String? // Optional enrollment code to display

    var body: some View {
        // Extract the background color to simplify the expression
        let backgroundColor = themeManager.currentTheme.mainBackgroundColorSwiftUI
        
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            // Use ScrollView with ScrollViewReader to programmatically scroll to active field
            ScrollView(.vertical, showsIndicators: true) {
                ScrollViewReader { proxy in
                    // Store the proxy for later use
                    // Use onAppear instead of direct assignment to avoid View builder issues
                    Color.clear
                        .onAppear {
                            scrollProxy = proxy
                        }
                VStack(spacing: 20) {
                    Text("Add Your Co-Parent")
                        .font(.largeTitle)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                        .padding()
                    
                    // Display enrollment code if available
                    if let code = generatedCode {
                        enrollmentCodeView(code: code)
                    }
                
                    // Form fields
                    formFieldsView()
                    .padding(.horizontal)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Add spacer to push content up when keyboard appears
                    Spacer(minLength: 80)
                    
                    // Navigation buttons
                    navigationButtonsView()
                    .padding()
                }
                .padding()
                }
            }
            // Add tap gesture to dismiss keyboard instead of using toolbar
            .gesture(
                TapGesture()
                    .onEnded { _ in
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
            )
        }
        // Adjust for keyboard
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // Add keyboard observer
        .onAppear(perform: setupKeyboardObservers)
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
        .alert("Invitation Result", isPresented: $showingAlert) {
            Button("OK") {
                onNext(coparentFirstName.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        } message: {
            Text(errorMessage ?? "Co-parent invitation sent successfully!")
        }
    }
    
    private func allFieldsFilled() -> Bool {
        return !coparentFirstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !coparentLastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !coparentEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !coparentPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func inviteCoParent() {
        isLoading = true
        errorMessage = nil
        
        // First, update the enrollment code with coparent information
        if let code = generatedCode {
            // Update the enrollment code with coparent information
            let firstName = coparentFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
            let lastName = coparentLastName.trimmingCharacters(in: .whitespacesAndNewlines)
            let email = coparentEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            let phone = coparentPhone.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Create a new enrollment code with coparent information
            SignUpViewModel().createEnrollmentCode(
                coparentFirstName: firstName,
                coparentLastName: lastName,
                coparentEmail: email,
                coparentPhone: phone
            ) { success, newCode in
                if success {
                    // Now send the invitation
                    self.sendInvitation(firstName: firstName, lastName: lastName, email: email, phone: phone)
                } else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Failed to update enrollment information"
                        self.showingAlert = true
                    }
                }
            }
        } else {
            // No code generated yet, just send the invitation
            let firstName = coparentFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
            let lastName = coparentLastName.trimmingCharacters(in: .whitespacesAndNewlines)
            let email = coparentEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            let phone = coparentPhone.trimmingCharacters(in: .whitespacesAndNewlines)
            
            sendInvitation(firstName: firstName, lastName: lastName, email: email, phone: phone)
        }
    }
    
    private func sendInvitation(firstName: String, lastName: String, email: String, phone: String?) {
        let phoneNumber = phone?.isEmpty == true ? nil : phone
        
        APIService.shared.inviteCoParent(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phoneNumber: phoneNumber
        ) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(_):
                    self.errorMessage = nil
                    self.showingAlert = true
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.showingAlert = true
                }
            }
        }
    }
    
    // Function to scroll to the active field
    private func scrollToField(_ field: Field) {
        withAnimation {
            scrollProxy?.scrollTo(field, anchor: .center)
        }
    }
    
    // Extract enrollment code view to reduce complexity
    @ViewBuilder
    private func enrollmentCodeView(code: String) -> some View {
        let textColor = themeManager.currentTheme.textColorSwiftUI
        let accentColor = themeManager.currentTheme.accentColorSwiftUI
        let backgroundColor = themeManager.currentTheme.mainBackgroundColorSwiftUI
        let secondaryBackgroundColor = themeManager.currentTheme.secondaryBackgroundColorSwiftUI
        
        VStack(spacing: 8) {
            Text("Your Enrollment Code")
                .font(.headline)
                .foregroundColor(textColor)
            
            Text(code)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(accentColor)
                .padding(10)
                .background(secondaryBackgroundColor)
                .cornerRadius(8)
            
            Text("Share this code with your co-parent")
                .font(.subheadline)
                .foregroundColor(textColor.opacity(0.7))
            
            Button(action: {
                UIPasteboard.general.string = code
            }) {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("Copy Code")
                }
                .font(.footnote)
                .foregroundColor(accentColor)
            }
            .padding(.bottom, 10)
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    // Extract form fields view to reduce complexity
    @ViewBuilder
    private func formFieldsView() -> some View {
        VStack(spacing: 15) {
            // First Name field with ID for scrolling
            CustomTextField(title: "First Name", text: $coparentFirstName, field: .firstName, activeField: $activeField)
                .id(Field.firstName)
                .frame(height: 56)
                .autocapitalization(.words)
                .onChange(of: activeField) { oldValue, newValue in
                    if newValue == .firstName {
                        scrollToField(.firstName)
                    }
                }
            
            // Last Name field with ID for scrolling
            CustomTextField(title: "Last Name", text: $coparentLastName, field: .lastName, activeField: $activeField)
                .id(Field.lastName)
                .frame(height: 56)
                .autocapitalization(.words)
                .onChange(of: activeField) { oldValue, newValue in
                    if newValue == .lastName {
                        scrollToField(.lastName)
                    }
                }
            
            // Email field with ID for scrolling
            CustomTextField(title: "Email", text: $coparentEmail, field: .email, activeField: $activeField)
                .id(Field.email)
                .frame(height: 56)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .onChange(of: activeField) { oldValue, newValue in
                    if newValue == .email {
                        scrollToField(.email)
                    }
                }
            
            // Phone field with ID for scrolling
            CustomTextField(title: "Phone Number", text: $coparentPhone, field: .phone, activeField: $activeField)
                .id(Field.phone)
                .frame(height: 56)
                .keyboardType(.phonePad)
                .onChange(of: activeField) { oldValue, newValue in
                    if newValue == .phone {
                        scrollToField(.phone)
                    }
                }
        }
        .padding(.horizontal)
    }
    
    // Extract navigation buttons view to reduce complexity
    @ViewBuilder
    private func navigationButtonsView() -> some View {
        HStack {
            Button(action: onBack) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .padding()
            }
            
            Spacer()
            
            // Remove Skip button - coparent information is now required
            
            Button(action: {
                // Dismiss keyboard when button is tapped
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                
                if allFieldsFilled() {
                    inviteCoParent()
                } else {
                    // Show error message if fields are not filled
                    errorMessage = "Please fill in all required fields"
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Invite & Next")
                    }
                }
                .padding()
                .background(allFieldsFilled() ? themeManager.currentTheme.accentColorSwiftUI : themeManager.currentTheme.accentColorSwiftUI.opacity(0.5))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(isLoading || !allFieldsFilled())
        }
        .padding()
    }
    
    // Setup keyboard observers
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
                // Scroll to active field when keyboard appears
                if let field = activeField {
                    scrollToField(field)
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            keyboardHeight = 0
        }
    }
}

// Custom TextField that tracks focus state
struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let field: OnboardingStepOneView.Field
    @Binding var activeField: OnboardingStepOneView.Field?
    @FocusState private var isFocused: Bool
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        FloatingLabelTextField(title: title, text: $text, isSecure: false, disableAutofill: true)
            .focused($isFocused)
            .onChange(of: isFocused) { oldValue, newValue in
                if newValue {
                    activeField = field
                }
            }
    }
}
