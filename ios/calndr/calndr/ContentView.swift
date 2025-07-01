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
    
    @State private var currentView: CalendarViewType = .month
    @State private var focusedDate: Date?
    @State private var showSettings = false
    @Namespace private var namespace

    var body: some View {
        ZStack {
            themeManager.currentTheme.mainBackgroundColor.ignoresSafeArea()
            
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
                    Text(headerTitle(for: currentView))
                        .font(.title.bold())
                    Spacer()
                }
                .padding(.horizontal)

                TabView(selection: $currentView) {
                    CalendarGridView(viewModel: calendarViewModel, focusedDate: $focusedDate, namespace: namespace)
                        .tag(CalendarViewType.month)

                    WeekView(viewModel: calendarViewModel)
                        .tag(CalendarViewType.week)

                    DayView(viewModel: calendarViewModel)
                        .tag(CalendarViewType.day)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .gesture(
                    DragGesture().onEnded { value in
                        if value.translation.width < -50 {
                            // Swipe left
                            changeDate(by: 1, for: currentView)
                        } else if value.translation.width > 50 {
                            // Swipe right
                            changeDate(by: -1, for: currentView)
                        }
                    }
                )

                // Custody Percentage Footer
                HStack(spacing: 15) {
                    Text(calendarViewModel.custodianOneName + " " + String(format: "%.0f", calendarViewModel.custodianOnePercentage) + "%")
                    Text("(\(calendarViewModel.custodyStreak))")
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
        .foregroundColor(themeManager.currentTheme.textColor)
        .onAppear {
            calendarViewModel.fetchEvents()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: calendarViewModel)
        }
    }

    private func changeDate(by amount: Int, for viewType: CalendarViewType) {
        let calendar = Calendar.current
        var dateComponent: Calendar.Component
        switch viewType {
        case .month:
            dateComponent = .month
        case .week:
            dateComponent = .weekOfYear
        case .day:
            dateComponent = .day
        }
        if let newDate = calendar.date(byAdding: dateComponent, value: amount, to: calendarViewModel.currentDate) {
            calendarViewModel.currentDate = newDate
            calendarViewModel.fetchEvents()
        }
    }

    private func headerTitle(for viewType: CalendarViewType) -> String {
        let formatter = DateFormatter()
        switch viewType {
        case .month:
            formatter.dateFormat = "MMMM yyyy"
        case .week:
            formatter.dateFormat = "MMMM"
        case .day:
            formatter.dateFormat = "MMMM d"
        }
        return formatter.string(from: calendarViewModel.currentDate)
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
