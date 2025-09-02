import SwiftUI

struct OnboardingView: View {
    @State private var currentStep = 0 // Start with step 0 (FamilyEnrollment)
    @State private var coparentName: String = ""
    @State private var showingFamilyEnrollment = true
    @Binding var isOnboardingComplete: Bool
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var signUpViewModel = SignUpViewModel()
    @State private var generatedCode: String? = nil
    
    // Function to go back to the previous step
    private func goBack() {
        if currentStep > 0 {
            currentStep -= 1
        }
    }
    
    // Initialize with the first step as family enrollment when coming from authenticated state
    init(isOnboardingComplete: Binding<Bool>) {
        self._isOnboardingComplete = isOnboardingComplete
        self._currentStep = State(initialValue: 0) // Always start with family enrollment
    }

    var body: some View {
        VStack {
            if currentStep == 0 {
                // Step 0: Family Enrollment (first step)
                FamilyEnrollmentView(viewModel: signUpViewModel) { success in
                    if success {
                        // If they entered a valid code, complete onboarding
                        if signUpViewModel.enteredValidCode {
                            authManager.completeOnboarding()
                            isOnboardingComplete = true
                        } else if signUpViewModel.generatedCode != nil {
                            // If they generated a code, save it and continue to next step
                            generatedCode = signUpViewModel.generatedCode
                            currentStep = 1
                        } else {
                            // If they skipped, go directly to step 2
                            currentStep = 2
                        }
                    }
                }
                .environmentObject(themeManager)
                .environmentObject(authManager)
            } else if currentStep == 1 {
                // Step 1: Co-parent invitation (original step 1)
                OnboardingStepOneView(
                    onNext: { coparentFirstName in
                        coparentName = coparentFirstName
                        // Email the code to co-parent if we have one
                        if let code = generatedCode {
                            signUpViewModel.emailEnrollmentCode(to: coparentFirstName, code: code)
                        }
                        currentStep = 2
                    }, 
                    onSkip: {
                        coparentName = ""
                        currentStep = 2
                    },
                    onBack: goBack,
                    generatedCode: generatedCode
                )
                .environmentObject(themeManager)
                .environmentObject(signUpViewModel)
            } else if currentStep == 2 {
                // Step 2: Schedule setup (original step 2)
                OnboardingStepTwoView(onNext: {
                    currentStep = 3
                }, onSkip: {
                    currentStep = 3
                }, onBack: goBack)
                .environmentObject(themeManager)
            } else if currentStep == 3 {
                // Step 3: Final step (original step 3)
                OnboardingStepThreeView(
                    primaryParentName: authManager.userProfile?.first_name ?? "You",
                    coparentName: coparentName.isEmpty ? nil : coparentName,
                    onComplete: {
                        // Complete onboarding and transition to main app
                        // Note: The custody records are already created in OnboardingStepThreeView
                        // before this callback is triggered
                        authManager.completeOnboarding()
                        isOnboardingComplete = true
                    },
                    onBack: goBack
                )
                .environmentObject(themeManager)
            }
        }
        .environmentObject(authManager)
    }
} 