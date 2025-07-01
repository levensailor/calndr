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
    @State private var isAnimating = false
    @State private var animationOpacity: Double = 1.0
    @State private var animationScale: CGFloat = 1.0
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
                        .opacity(currentView == .month ? animationOpacity : 1.0)
                        .scaleEffect(currentView == .month ? animationScale : 1.0)
                    Spacer()
                }
                .padding(.horizontal)

                TabView(selection: $currentView) {
                    CalendarGridView(viewModel: calendarViewModel, focusedDate: $focusedDate, namespace: namespace)
                        .opacity(currentView == .month ? animationOpacity : 1.0)
                        .scaleEffect(currentView == .month ? animationScale : 1.0)
                        .tag(CalendarViewType.month)

                    WeekView(viewModel: calendarViewModel)
                        .tag(CalendarViewType.week)

                    DayView(viewModel: calendarViewModel)
                        .tag(CalendarViewType.day)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            handleEnhancedSwipeGesture(value)
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

    private func handleEnhancedSwipeGesture(_ value: DragGesture.Value) {
        // Prevent multiple simultaneous gestures
        guard !isAnimating else { return }
        
        let translation = value.translation
        let distance = sqrt(pow(translation.x, 2) + pow(translation.y, 2))
        let velocity = sqrt(pow(value.velocity.width, 2) + pow(value.velocity.height, 2))
        
        // Determine if this is primarily horizontal or vertical
        let isHorizontalDominant = abs(translation.x) > abs(translation.y)
        let isVerticalDominant = abs(translation.y) > abs(translation.x)
        
        // Thresholds for gesture recognition
        let shortSwipeThreshold: CGFloat = 50
        let longSwipeThreshold: CGFloat = 100
        let velocityThreshold: CGFloat = 500
        
        if isVerticalDominant && currentView == .month {
            // Vertical swipes in month view - check if it's a long swipe for month navigation
            let isLongVerticalSwipe = distance > longSwipeThreshold || velocity > velocityThreshold
            
            if isLongVerticalSwipe {
                // Long vertical swipe - change months with animation
                if translation.y < 0 {
                    // Swipe up - next month
                    changeMonthWithAnimation(by: 1)
                } else {
                    // Swipe down - previous month
                    changeMonthWithAnimation(by: -1)
                }
            }
            // Short vertical swipes in month view are ignored
            
        } else if isHorizontalDominant && abs(translation.x) > shortSwipeThreshold {
            // Horizontal swipes - standard navigation for all views
            if translation.x < 0 {
                // Swipe left
                changeDate(by: 1, for: currentView)
            } else {
                // Swipe right
                changeDate(by: -1, for: currentView)
            }
            
        } else if isVerticalDominant && currentView != .month && abs(translation.y) > shortSwipeThreshold {
            // Vertical swipes in week/day views - use as alternative navigation
            if translation.y < 0 {
                // Swipe up - forward
                changeDate(by: 1, for: currentView)
            } else {
                // Swipe down - backward
                changeDate(by: -1, for: currentView)
            }
        }
    }
    
    private func changeMonthWithAnimation(by amount: Int) {
        isAnimating = true
        
        // Fly-out animation - scale down and fade out
        withAnimation(.easeInOut(duration: 0.5)) {
            animationOpacity = 0.0
            animationScale = 0.8
        }
        
        // Change the month at the midpoint of the animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let calendar = Calendar.current
            if let newDate = calendar.date(byAdding: .month, value: amount, to: calendarViewModel.currentDate) {
                calendarViewModel.currentDate = newDate
                calendarViewModel.fetchEvents()
            }
        }
        
        // Fly-in animation - scale up and fade in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                animationOpacity = 1.0
                animationScale = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isAnimating = false
            }
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
