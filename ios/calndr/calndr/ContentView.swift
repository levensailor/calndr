import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var themeManager = ThemeManager()

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView(calendarViewModel: CalendarViewModel(authManager: authManager))
            } else {
                LoginView()
            }
        }
        .environmentObject(themeManager)
        .onAppear {
            authManager.checkAuthentication()
            NotificationManager.shared.requestAuthorizationAndRegister()
        }
    }
}

struct MainTabView: View {
    @StateObject var calendarViewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var focusedDate: Date?
    @State private var showSettings = false
    @Namespace private var namespace

    var body: some View {
        ZStack {
            VStack {
                if calendarViewModel.isOffline {
                    Text("Offline Mode")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray)
                        .padding(.top, -8)
                }
                
                // Header with month/year and view switcher
                HStack {
                    Button(action: {
                        calendarViewModel.changeMonth(by: -1)
                    }) {
                        Image(systemName: "chevron.left")
                    }
                    .padding(.leading)

                    Spacer()

                    Text(monthYearString(from: calendarViewModel.currentDate))
                        .font(.title.bold())

                    Spacer()

                    Button(action: {
                        calendarViewModel.changeMonth(by: 1)
                    }) {
                        Image(systemName: "chevron.right")
                    }
                    .padding(.trailing)
                }
                .padding(.horizontal)

                CalendarGridView(viewModel: calendarViewModel, focusedDate: $focusedDate, namespace: namespace)

                // Custody Percentage Footer
                HStack(spacing: 15) {
                    Text(calendarViewModel.custodianOneName + " " + String(format: "%.0f", calendarViewModel.custodianOnePercentage) + "%")
                    Text("(\\(calendarViewModel.custodyStreak))")
                        .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                    Text(calendarViewModel.custodianTwoName + " " + String(format: "%.0f", calendarViewModel.custodianTwoPercentage) + "%")
                }
                .font(.headline)
                .padding()

                // Menu Bar
                HStack(alignment: .top, spacing: 60) {
                    Button(action: {
                        calendarViewModel.toggleWeather()
                    }) {
                        Image(systemName: calendarViewModel.showWeather ? "cloud.sun.fill" : "cloud.sun")
                            .font(.title2)
                    }
                    
                    Button(action: {
                        calendarViewModel.toggleSchoolEvents()
                    }) {
                        Image(systemName: calendarViewModel.showSchoolEvents ? "graduationcap.fill" : "graduationcap")
                            .font(.title2)
                    }
                    
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gear")
                            .font(.title2)
                    }
                }
                .padding(.bottom)
            }
            
            if focusedDate != nil {
                FocusedDayView(viewModel: calendarViewModel, focusedDate: $focusedDate, namespace: namespace)
            }
        }
        .background(themeManager.currentTheme.mainBackgroundColor)
        .foregroundColor(themeManager.currentTheme.textColor)
        .onAppear {
            calendarViewModel.fetchEvents()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: calendarViewModel)
        }
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthenticationManager())
    }
}
