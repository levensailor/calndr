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
            .background(themeManager.currentTheme.headerBackgroundColor)
            
            // Calendar grid with fixed height - cells adapt to fill space
            let numberOfWeeks = calculateNumberOfWeeks()
            let fixedCalendarHeight: CGFloat = 510 // Fixed height for consistent layout
            let rowHeight = fixedCalendarHeight / CGFloat(numberOfWeeks)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
                ForEach(getDaysForCurrentMonth(), id: \.self) { date in
                    DayCellView(
                        viewModel: viewModel,
                        focusedDate: $focusedDate,
                        namespace: namespace,
                        date: date,
                        events: viewModel.eventsForDate(date),
                        schoolEvent: viewModel.schoolEventForDate(date),
                        weatherInfo: viewModel.weatherInfoForDate(date),
                        isCurrentMonth: isDateInCurrentMonth(date),
                        isToday: isToday(date),
                        custodyOwner: viewModel.getCustodyInfo(for: date).text,
                        custodyID: viewModel.getCustodyInfo(for: date).owner
                    )
                    .frame(height: rowHeight) // Adaptive height based on number of weeks
                }
            }
            .frame(height: fixedCalendarHeight) // Fixed calendar height
        }
    }
    
    private func getDaysForCurrentMonth() -> [Date] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: viewModel.currentDate) else {
            return []
        }

        let firstDayOfMonth = monthInterval.start
        let lastDayOfMonth = monthInterval.end
        
        guard let firstDayOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: firstDayOfMonth)),
              let lastDayOfMonthWithTime = calendar.date(byAdding: .day, value: -1, to: lastDayOfMonth),
              let lastDayOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: lastDayOfMonthWithTime)) else {
            return []
        }
        
        let startDate = firstDayOfWeek
        let endDate = calendar.date(byAdding: .day, value: 6, to: lastDayOfWeek)!

        var days: [Date] = []
        var currentDate = startDate
        while currentDate <= endDate {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        return days
    }
    
    private func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private func isToday(_ date: Date) -> Bool {
        return Calendar.current.isDateInToday(date)
    }

    private func isDateInCurrentMonth(_ date: Date) -> Bool {
        return Calendar.current.isDate(date, equalTo: viewModel.currentDate, toGranularity: .month)
    }
    
    private func calculateNumberOfWeeks() -> Int {
        let days = getDaysForCurrentMonth()
        return days.count / 7 // Each week has 7 days
    }
    
    private func cellBackgroundColor(for date: Date) -> Color {
        return isDateInCurrentMonth(date) ? Color.gray.opacity(0.1) : Color.clear
    }
    
    private func cellForegroundColor(for date: Date) -> Color {
        return isDateInCurrentMonth(date) ? .primary : .secondary
    }
}

struct CalendarGridView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 
