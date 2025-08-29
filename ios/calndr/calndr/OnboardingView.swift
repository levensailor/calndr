import SwiftUI

struct OnboardingView: View {
    @State private var currentStep = 1
    @State private var coparentName: String = ""
    @Binding var isOnboardingComplete: Bool
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var themeManager: ThemeManager

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
                .environmentObject(themeManager)
            } else if currentStep == 2 {
                OnboardingStepTwoView(onNext: {
                    currentStep = 3
                }, onSkip: {
                    currentStep = 3
                })
                .environmentObject(themeManager)
            } else if currentStep == 3 {
                OnboardingStepThreeView(
                    primaryParentName: authManager.userProfile?.first_name ?? "You",
                    coparentName: coparentName.isEmpty ? nil : coparentName,
                    onComplete: {
                        // Complete onboarding and transition to main app
                        authManager.completeOnboarding()
                        isOnboardingComplete = true
                    }
                )
                .environmentObject(themeManager)
            }
        }
        .environmentObject(authManager)
    }
} 