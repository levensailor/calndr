import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            // Header with title and Done button
            HStack {
                Button("Done") {
                    dismiss()
                }
                .padding()
                Spacer()
                Text("Settings").font(.headline)
                Spacer()
                Button("Done") {}.padding().opacity(0) // Dummy for centering
            }
            
            TabView {
                NavigationView { AccountsView() }
                    .tabItem {
                        Label("Account", systemImage: "person.circle")
                    }

                NavigationView { PreferencesView().environmentObject(viewModel) }
                    .tabItem {
                        Label("Preferences", systemImage: "gear")
                    }

                NavigationView { SecuritySettingsView() }
                    .tabItem {
                        Label("Security", systemImage: "lock.shield")
                    }

                NavigationView { ContactsView().environmentObject(viewModel) }
                    .tabItem {
                        Label("Contacts", systemImage: "person.2")
                    }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager)
        
        SettingsView(viewModel: calendarViewModel)
            .environmentObject(ThemeManager())
    }
} 