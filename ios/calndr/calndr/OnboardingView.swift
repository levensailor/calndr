import SwiftUI

struct OnboardingView: View {
    @State private var currentStep = 1
    @State private var coparentName: String = ""
    @Binding var isOnboardingComplete: Bool
    @EnvironmentObject var authManager: AuthenticationManager

    var body: some View {
        VStack {
            if currentStep == 1 {
                OnboardingStepOneView(
                    onNext: { coparentFirstName in
                        coparentName = coparentFirstName
                        currentStep = 2
                    }, 
                    onSkip: {
                        coparentName = ""
                        currentStep = 2
                    }
                )
            } else if currentStep == 2 {
                OnboardingStepTwoView(onNext: {
                    currentStep = 3
                }, onSkip: {
                    currentStep = 3
                })
            } else if currentStep == 3 {
                OnboardingStepThreeView(
                    primaryParentName: authManager.username ?? "You",
                    coparentName: coparentName.isEmpty ? nil : coparentName,
                    onComplete: {
                        // Complete onboarding and transition to main app
                        authManager.completeOnboarding()
                        isOnboardingComplete = true
                    }
                )
            }
        }
        .environmentObject(authManager)
    }
} 