import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var themeManager = ThemeManager()

    var body: some View {
        Group {
            if authManager.isLoading {
                SplashScreenView()
                    .transition(.opacity)
            } else if authManager.isAuthenticated {
                MainTabView(calendarViewModel: CalendarViewModel(authManager: authManager))
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: authManager.isLoading)
        .animation(.easeInOut(duration: 0.5), value: authManager.isAuthenticated)
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
    @EnvironmentObject var navigationManager: NavigationManager
    
    @State private var currentView: CalendarViewType = .month
    @State private var focusedDate: Date?
    @State private var showSettings = false
    @State private var isAnimating = false
    @State private var animationOpacity: Double = 1.0
    @State private var animationScale: CGFloat = 1.0
    @State private var headerOpacity: Double = 1.0
    @State private var headerOffset: CGFloat = 0.0
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
                    Spacer()
                    Text(headerTitle(for: currentView))
                        .font(.title.bold())
                        .opacity(currentView == .month ? headerOpacity : 1.0)
                        .offset(y: currentView == .month ? headerOffset : 0.0)
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
                HStack(spacing: 30) {
                    // Custodian One
                    VStack(spacing: 4) {
                        Text(calendarViewModel.custodianOneName + " " + String(format: "%.0f", calendarViewModel.custodianOnePercentage) + "%")
                            .font(.headline)
                        
                        // Green dots for custodian one's streak
                        HStack(spacing: 2) {
                            if calendarViewModel.custodianWithStreak == 1 && calendarViewModel.custodyStreak > 0 {
                                ForEach(0..<min(calendarViewModel.custodyStreak, 10), id: \.self) { _ in
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 6, height: 6)
                                }
                                if calendarViewModel.custodyStreak > 10 {
                                    Text("...")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .frame(height: 10) // Reserve space even when empty
                    }
                    
                    // Custodian Two
                    VStack(spacing: 4) {
                        Text(calendarViewModel.custodianTwoName + " " + String(format: "%.0f", calendarViewModel.custodianTwoPercentage) + "%")
                            .font(.headline)
                        
                        // Green dots for custodian two's streak
                        HStack(spacing: 2) {
                            if calendarViewModel.custodianWithStreak == 2 && calendarViewModel.custodyStreak > 0 {
                                ForEach(0..<min(calendarViewModel.custodyStreak, 10), id: \.self) { _ in
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 6, height: 6)
                                }
                                if calendarViewModel.custodyStreak > 10 {
                                    Text("...")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .frame(height: 10) // Reserve space even when empty
                    }
                }
                .padding()

                // Menu Bar
                HStack(alignment: .top, spacing: 60) {
                    VStack(spacing: 4) {
                        Button(action: {
                            calendarViewModel.toggleWeather()
                        }) {
                            Image(systemName: calendarViewModel.showWeather ? "cloud.sun.fill" : "cloud.sun")
                                .font(.title2)
                                .foregroundColor(calendarViewModel.showWeather ? themeManager.currentTheme.iconActiveColor : themeManager.currentTheme.iconColor)
                        }
                        Text("Weather")
                            .font(.caption2)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                    }
                    
                    VStack(spacing: 4) {
                        Button(action: {
                            calendarViewModel.toggleSchoolEvents()
                        }) {
                            Image(systemName: calendarViewModel.showSchoolEvents ? "graduationcap.fill" : "graduationcap")
                                .font(.title2)
                                .foregroundColor(calendarViewModel.showSchoolEvents ? themeManager.currentTheme.iconActiveColor : themeManager.currentTheme.iconColor)
                        }
                        Text("School")
                            .font(.caption2)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                    }
                    
                    VStack(spacing: 4) {
                        Button(action: {
                            showSettings = true
                        }) {
                            Image(systemName: "gear")
                                .font(.title2)
                                .foregroundColor(themeManager.currentTheme.iconColor)
                        }
                        Text("Settings")
                            .font(.caption2)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
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
        .onReceive(navigationManager.$shouldNavigateToSchedule) { shouldNavigate in
            if shouldNavigate {
                currentView = .month // Switch to month view
                focusedDate = nil   // Ensure no day is focused
                // Reset the state in the navigation manager
                navigationManager.shouldNavigateToSchedule = false
            }
        }
    }

    private func handleEnhancedSwipeGesture(_ value: DragGesture.Value) {
        // Prevent multiple simultaneous gestures
        guard !isAnimating else { return }
        
        let translation = value.translation
        let distance = sqrt(pow(translation.width, 2) + pow(translation.height, 2))
        let velocity = sqrt(pow(value.velocity.width, 2) + pow(value.velocity.height, 2))
        
        // Determine if this is primarily horizontal or vertical
        let isHorizontalDominant = abs(translation.width) > abs(translation.height)
        let isVerticalDominant = abs(translation.height) > abs(translation.width)
        
        // Thresholds for gesture recognition
        let shortSwipeThreshold: CGFloat = 50
        let longSwipeThreshold: CGFloat = 60
        let velocityThreshold: CGFloat = 250
        
        if isVerticalDominant && currentView == .month {
            // Vertical swipes in month view - check if it's a long swipe for month navigation
            let isLongVerticalSwipe = distance > longSwipeThreshold || velocity > velocityThreshold
            
            if isLongVerticalSwipe {
                // Long vertical swipe - change months with animation
                if translation.height < 0 {
                    // Swipe up - next month
                    changeMonthWithAnimation(by: 1)
                } else {
                    // Swipe down - previous month
                    changeMonthWithAnimation(by: -1)
                }
            }
            // Short vertical swipes in month view are ignored
            
        } else if isHorizontalDominant && abs(translation.width) > shortSwipeThreshold {
            // Horizontal swipes - standard navigation for all views
            if translation.width < 0 {
                // Swipe left
                changeDate(by: 1, for: currentView)
            } else {
                // Swipe right
                changeDate(by: -1, for: currentView)
            }
            
        } else if isVerticalDominant && currentView != .month && abs(translation.height) > shortSwipeThreshold {
            // Vertical swipes in week/day views - use as alternative navigation
            if translation.height < 0 {
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
        
        // Fly-out animation - fade out header and slide up
        withAnimation(.easeInOut(duration: 0.01)) {
            animationOpacity = 1.0
            animationScale = 1.0
            headerOpacity = 0.0
            headerOffset = -20.0
        }
        
        // Change the month at the midpoint of the animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let calendar = Calendar.current
            if let newDate = calendar.date(byAdding: .month, value: amount, to: calendarViewModel.currentDate) {
                calendarViewModel.currentDate = newDate
                calendarViewModel.fetchEvents()
            }
        }
        
        // Fly-in animation - fade in header and slide down
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // Start header from below
            headerOffset = 20.0
            headerOpacity = 0.0
            
            withAnimation(.easeInOut(duration: 0.01)) {
                animationOpacity = 1.0
                animationScale = 1.0
                headerOpacity = 1.0
                headerOffset = 0.0
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
            return weekRangeString(from: calendarViewModel.currentDate)
        case .day:
            formatter.dateFormat = "MMMM d"
        }
        return formatter.string(from: calendarViewModel.currentDate)
    }

    private func weekRangeString(from date: Date) -> String {
        let calendar = Calendar.current
        
        // Get the start of the week (Sunday)
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return "Week"
        }
        
        let startOfWeek = weekInterval.start
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d"
        
        let startMonth = monthFormatter.string(from: startOfWeek)
        let startDay = dayFormatter.string(from: startOfWeek)
        let endDay = dayFormatter.string(from: endOfWeek)
        
        // Check if the week spans multiple months
        if calendar.isDate(startOfWeek, equalTo: endOfWeek, toGranularity: .month) {
            // Same month: "July 14 - 20"
            return "\(startMonth) \(startDay) - \(endDay)"
        } else {
            // Different months: "July 30 - Aug 5"
            let endMonth = monthFormatter.string(from: endOfWeek)
            let shortEndMonth = String(endMonth.prefix(3)) // First 3 letters
            return "\(startMonth) \(startDay) - \(shortEndMonth) \(endDay)"
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
