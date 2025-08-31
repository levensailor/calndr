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
    var generatedCode: String? // Optional enrollment code to display

    var body: some View {
        ZStack {
            themeManager.currentTheme.mainBackgroundColorSwiftUI.ignoresSafeArea()
            
            // Use ScrollView with ScrollViewReader to programmatically scroll to active field
            ScrollView {
                ScrollViewProxy { proxy in
                    // Store the proxy for later use
                    if scrollProxy == nil {
                        DispatchQueue.main.async {
                            scrollProxy = proxy
                        }
                    }
                VStack(spacing: 20) {
                    Text("Add Your Co-Parent")
                        .font(.largeTitle)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                        .padding()
                    
                    // Display enrollment code if available
                    if let code = generatedCode {
                        VStack(spacing: 8) {
                            Text("Your Enrollment Code")
                                .font(.headline)
                                .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                            
                            Text(code)
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundColor(themeManager.currentTheme.accentColorSwiftUI)
                                .padding(10)
                                .background(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                                .cornerRadius(8)
                            
                            Text("Share this code with your co-parent")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
                            
                            Button(action: {
                                UIPasteboard.general.string = code
                            }) {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy Code")
                                }
                                .font(.footnote)
                                .foregroundColor(themeManager.currentTheme.accentColorSwiftUI)
                            }
                            .padding(.bottom, 10)
                        }
                        .padding()
                        .background(themeManager.currentTheme.mainBackgroundColorSwiftUI)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(themeManager.currentTheme.accentColorSwiftUI.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }
                
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
                    HStack {
                        Button(action: onSkip) {
                            Text("Skip")
                                .padding()
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            // Dismiss keyboard when button is tapped
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            
                            if allFieldsFilled() {
                                inviteCoParent()
                            } else {
                                onNext("")
                            }
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text(allFieldsFilled() ? "Invite & Next" : "Next")
                                }
                            }
                            .padding()
                            .background(themeManager.currentTheme.accentColorSwiftUI)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(isLoading)
                    }
                    .padding()
                }
                .padding()
                }
            }
            // Add keyboard toolbar with Done button
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
        }
        // Adjust for keyboard
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // Add keyboard observer
        .onAppear {
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
               !coparentEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func inviteCoParent() {
        isLoading = true
        errorMessage = nil
        
        let phoneNumber = coparentPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : coparentPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        
        APIService.shared.inviteCoParent(
            firstName: coparentFirstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: coparentLastName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: coparentEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: phoneNumber
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(_):
                    errorMessage = nil
                    showingAlert = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingAlert = true
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
        FloatingLabelTextField(title: title, text: $text, isSecure: false)
            .focused($isFocused)
            .onChange(of: isFocused) { oldValue, newValue in
                if newValue {
                    activeField = field
                }
            }
    }
}
}
