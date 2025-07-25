import SwiftUI

struct CalendarGridView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var focusedDate: Date?
    var namespace: Namespace.ID
    
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header for days of the week - always visible
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                }
            }
            .padding(.vertical, 4)
            .background(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
            
            // Infinite scrolling calendar grid
            MonthInfiniteScrollView(viewModel: viewModel) { monthStartDate in
                CalendarMonthContentView(
                    viewModel: viewModel,
                    monthStartDate: monthStartDate,
                    focusedDate: $focusedDate,
                    namespace: namespace
                )
                .environmentObject(themeManager)
            }
        }
    }
}

struct CalendarMonthContentView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let monthStartDate: Date
    @Binding var focusedDate: Date?
    var namespace: Namespace.ID
    
    var body: some View {
        let numberOfWeeks = calculateNumberOfWeeks()
        let fixedCalendarHeight: CGFloat = 510 // Fixed height for consistent layout
        let rowHeight = fixedCalendarHeight / CGFloat(numberOfWeeks)
        
        ZStack {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(getDaysForMonth(monthStartDate), id: \.self) { date in
                    DayCellView(
                        viewModel: viewModel,
                        focusedDate: $focusedDate,
                        namespace: namespace,
                        date: date,
                        events: viewModel.eventsForDate(date),
                        schoolEvent: viewModel.schoolEventForDate(date),
                        daycareEvent: viewModel.daycareEventForDate(date),
                        weatherInfo: viewModel.weatherInfoForDate(date),
                        isCurrentMonth: isDateInMonth(date, monthStartDate),
                        isToday: isToday(date),
                        custodyOwner: viewModel.getCustodyInfo(for: date).text,
                        custodyID: viewModel.getCustodyInfo(for: date).owner
                    )
                    .frame(height: rowHeight) // Adaptive height based on number of weeks
                    .opacity(viewModel.showHandoffTimeline ? 0.90 : 1.0) // Very slight dim when handoff timeline is active
                }
            }
            .frame(height: fixedCalendarHeight)
            .background(themeManager.currentTheme.mainBackgroundColorSwiftUI)
            
            // Handoff timeline overlay
            if viewModel.showHandoffTimeline {
                HandoffTimelineView(viewModel: viewModel, calendarDays: getDaysForMonth(monthStartDate))
                    .environmentObject(themeManager)
            }
        }
    }
    
    private func getDaysForMonth(_ monthStart: Date) -> [Date] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthStart) else {
            return []
        }
        
        let firstDayOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let startDate = calendar.date(byAdding: .day, value: -(firstWeekday - 1), to: firstDayOfMonth) ?? firstDayOfMonth
        
        var dates: [Date] = []
        let numberOfWeeks = calculateNumberOfWeeksForMonth(monthStart)
        
        for week in 0..<numberOfWeeks {
            for day in 0..<7 {
                let offset = week * 7 + day
                if let date = calendar.date(byAdding: .day, value: offset, to: startDate) {
                    dates.append(date)
                }
            }
        }
        
        return dates
    }
    
    private func calculateNumberOfWeeks() -> Int {
        return calculateNumberOfWeeksForMonth(monthStartDate)
    }
    
    private func calculateNumberOfWeeksForMonth(_ monthStart: Date) -> Int {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthStart) else {
            return 6 // Default fallback
        }
        
        let firstDayOfMonth = monthInterval.start
        let lastDayOfMonth = calendar.date(byAdding: .day, value: -1, to: monthInterval.end) ?? monthInterval.start
        
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) // 1 = Sunday
        let daysInMonth = calendar.component(.day, from: lastDayOfMonth)
        
        let totalCells = (firstWeekday - 1) + daysInMonth
        return Int(ceil(Double(totalCells) / 7.0))
    }
    
    private func isDateInMonth(_ date: Date, _ monthStart: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date, equalTo: monthStart, toGranularity: .month)
    }
    
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}

struct CalendarGridView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 
