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
                NavigationView { ThemeSettingsView() }
                    .tabItem {
                        Label("Theme", systemImage: "paintbrush")
                    }

                NavigationView { SecuritySettingsView() }
                    .tabItem {
                        Label("Security", systemImage: "lock.shield")
                    }

                NavigationView { AlertsSettingsView().environmentObject(viewModel) }
                    .tabItem {
                        Label("Alerts", systemImage: "bell")
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