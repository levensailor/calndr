import SwiftUI

struct OnboardingView: View {
    @State private var currentStep = 1
    @Binding var isOnboardingComplete: Bool

    var body: some View {
        VStack {
            if currentStep == 1 {
                OnboardingStepOneView(onNext: {
                    currentStep = 2
                }, onSkip: {
                    currentStep = 2
                })
            } else if currentStep == 2 {
                OnboardingStepTwoView(onNext: {
                    currentStep = 3
                }, onSkip: {
                    currentStep = 3
                })
            } else if currentStep == 3 {
                OnboardingStepThreeView(onComplete: {
                    isOnboardingComplete = true
                })
            }
        }
    }
} 