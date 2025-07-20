import SwiftUI

struct GoogleSignInButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text("G")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 219/255, green: 68/255, blue: 55/255))
                    .frame(width: 20, height: 20)
                Text("Sign in with Google")
                    .font(.headline)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
}
