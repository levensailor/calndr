import SwiftUI
import FacebookLogin

struct FacebookSignInButton: View {
    var body: some View {
        Button(action: {
            // Action will be handled in LoginView
        }) {
            HStack {
                Text("f")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text("Sign in with Facebook")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(red: 24/255, green: 119/255, blue: 242/255))
            .cornerRadius(8)
        }
    }
}
