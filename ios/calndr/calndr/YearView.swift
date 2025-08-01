import SwiftUI

struct YearView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    private let monthNames = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ]
    
    var body: some View {
        VStack(spacing: 16) {
                // Custody legend with yearly totals on single line
                let totals = viewModel.getYearlyCustodyTotals()
                HStack {
                    // First parent (far left)
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            VStack(spacing: 2) {
                                Text(viewModel.custodianOneName)
                                    .font(.caption)
                                    .foregroundColor(themeManager.currentTheme.textColor.color)
                                Rectangle()
                                    .fill(themeManager.currentTheme.parentOneColor.color)
                                    .frame(width: 50, height: 12)
                                    .cornerRadius(2)
                            }
                            VStack(spacing: 2) {
                                Text("\(totals.custodianOneDays)")
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(themeManager.currentTheme.textColor.color)
                                Text("days")
                                    .font(.caption2)
                                    .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                            }
                        }
                        
                    }
                    
                    Spacer()
                    
                    // Second parent (far right)
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            VStack(spacing: 2) {
                                Text(viewModel.custodianTwoName)
                                    .font(.caption)
                                    .foregroundColor(themeManager.currentTheme.textColor.color)
                                Rectangle()
                                    .fill(themeManager.currentTheme.parentTwoColor.color)
                                    .frame(width: 50, height: 12)
                                    .cornerRadius(2)
                            }
                            VStack(spacing: 2) {
                                Text("\(totals.custodianTwoDays)")
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(themeManager.currentTheme.textColor.color)
                                Text("days")
                                    .font(.caption2)
                                    .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                            }
                        }
                        

                    }
                }
                .padding(.horizontal, 20)
                .padding(.top)
                .padding(.bottom, 10)
                
                // 4x3 grid of months
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 16) {
                    ForEach(1...12, id: \.self) { monthNumber in
                        MonthMiniView(
                            viewModel: viewModel,
                            themeManager: themeManager,
                            year: Calendar.current.component(.year, from: viewModel.currentDate),
                            month: monthNumber,
                            monthName: monthNames[monthNumber - 1]
                        )
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 50)
            }
        .background(themeManager.currentTheme.mainBackgroundColorSwiftUI)
        .animateThemeChanges(themeManager)
        .onAppear {
            viewModel.fetchCustodyRecordsForYear()
        }
    }
}

struct CalendarItem: Identifiable {
    let id: String
    let day: Int? // nil for empty cells
}

struct MonthMiniView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let themeManager: ThemeManager
    let year: Int
    let month: Int
    let monthName: String
    
    var body: some View {
        VStack(spacing: 4) {
            // Month name
            Text(monthName)
                .font(.caption)
                .bold()
                .foregroundColor(themeManager.currentTheme.textColor.color)
            
            // Mini calendar grid
//            let daysInMonth = getDaysInMonth()
//            let firstWeekday = getFirstWeekdayOfMonth()
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 1) {
                ForEach(getCalendarItems(), id: \.id) { item in
                    if let day = item.day {
                        // Day cell
                        let date = createDate(year: year, month: month, day: day)
                        let custodyInfo = viewModel.getCustodyInfo(for: date)
                        
                        Rectangle()
                            .fill(getCustodyColor(custodyID: custodyInfo.owner))
                            .frame(height: 12)
                            .cornerRadius(1)
                            .overlay(
                                Rectangle()
                                    .stroke(isToday(date) ? Color.green : Color.clear, lineWidth: isToday(date) ? 2 : 0)
                                    .cornerRadius(1)
                            )
                    } else {
                        // Empty cell
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 12)
                    }
                }
            }
        }
        .padding(8)
        .background(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(themeManager.currentTheme.accentColorSwiftUI, lineWidth: 1)
        )
    }
    
    private func getDaysInMonth() -> Int {
        let calendar = Calendar.current
        let dateComponents = DateComponents(year: year, month: month)
        guard let date = calendar.date(from: dateComponents) else { return 30 }
        return calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }
    
    private func getFirstWeekdayOfMonth() -> Int {
        let calendar = Calendar.current
        let dateComponents = DateComponents(year: year, month: month, day: 1)
        guard let date = calendar.date(from: dateComponents) else { return 0 }
        return calendar.component(.weekday, from: date) - 1 // 0-based for Sunday
    }
    
    private func createDate(year: Int, month: Int, day: Int) -> Date {
        let calendar = Calendar.current
        let dateComponents = DateComponents(year: year, month: month, day: day)
        return calendar.date(from: dateComponents) ?? Date()
    }
    
    private func getCustodyColor(custodyID: String) -> Color {
        if custodyID == viewModel.custodianOneId {
            return themeManager.currentTheme.parentOneColor.color
        } else if custodyID == viewModel.custodianTwoId {
            return themeManager.currentTheme.parentTwoColor.color
        } else {
            return Color.gray.opacity(0.3) // Gray for no custody info
        }
    }
    
    private func isToday(_ date: Date) -> Bool {
        return Calendar.current.isDateInToday(date)
    }
    
    private func getCalendarItems() -> [CalendarItem] {
        var items: [CalendarItem] = []
        let firstWeekday = getFirstWeekdayOfMonth()
        let daysInMonth = getDaysInMonth()
        
        // Add empty cells for days before the first day of the month
        for i in 0..<firstWeekday {
            items.append(CalendarItem(id: "empty-\(year)-\(month)-\(i)", day: nil))
        }
        
        // Add days of the month
        for day in 1...daysInMonth {
            items.append(CalendarItem(id: "day-\(year)-\(month)-\(day)", day: day))
        }
        
        return items
    }
}



struct YearView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 
