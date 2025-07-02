import SwiftUI

struct CalendarGridView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedDate: Date?
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
                        .foregroundColor(themeManager.currentTheme.textColor)
                }
            }
            .padding(.vertical, 8)
            .background(themeManager.currentTheme.headerBackgroundColor)
            
            // Calendar grid with flexible height
            let numberOfWeeks = calculateNumberOfWeeks()
            let fixedCalendarHeight: CGFloat = 500
            let rowHeight = fixedCalendarHeight / CGFloat(numberOfWeeks)
            
            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(getDaysForCurrentMonth(), id: \.self) { date in
                    DayCellView(
                        date: date,
                        isCurrentMonth: isDateInCurrentMonth(date),
                        viewModel: viewModel,
                        selectedDate: $selectedDate,
                        themeManager: themeManager
                    )
                    .frame(height: rowHeight)
                }
            }
            .frame(height: fixedCalendarHeight)
        }
        .overlay(
            // Show focused day view when a date is selected
            Group {
                if let selectedDate = selectedDate {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                                self.selectedDate = nil
                            }
                        }
                        .transition(.opacity)
                    
                    FocusedDayView(
                        date: selectedDate,
                        viewModel: viewModel,
                        selectedDate: $selectedDate,
                        themeManager: themeManager,
                        namespace: namespace
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
        )
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

    private func isDateInCurrentMonth(_ date: Date) -> Bool {
        return Calendar.current.isDate(date, equalTo: viewModel.currentDate, toGranularity: .month)
    }
    
    private func calculateNumberOfWeeks() -> Int {
        let days = getDaysForCurrentMonth()
        return days.count / 7
    }
}

struct CalendarGridView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 
