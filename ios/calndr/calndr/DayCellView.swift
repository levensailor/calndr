import SwiftUI

struct DayCellView: View {
    let date: Date
    let isCurrentMonth: Bool
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var selectedDate: Date?
    let themeManager: ThemeManager
    
    private var eventsForThisDate: [Event] {
        viewModel.eventsForDate(date)
    }
    
    private var custodyForThisDate: CustodyResponse? {
        viewModel.custodyForDate(date)
    }
    
    private var isSelected: Bool {
        selectedDate?.isSameDay(as: date) == true
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Date number at the top
            HStack {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isCurrentMonth ? 
                        (isToday ? themeManager.currentTheme.todayNumberColor : themeManager.currentTheme.textColor) : 
                        themeManager.currentTheme.otherMonthTextColor)
                
                Spacer()
            }
            
            // All events displayed as multi-line text
            VStack(alignment: .leading, spacing: 1) {
                // Show custody if available
                if let custody = custodyForThisDate {
                    Text(custody.custodian_name)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.custodyTextColor)
                        .lineLimit(1)
                }
                
                // Show all regular events
                ForEach(eventsForThisDate, id: \.id) { event in
                    if !event.content.isEmpty {
                        Text(event.content)
                            .font(.system(size: 9))
                            .foregroundColor(themeManager.currentTheme.eventTextColor)
                            .lineLimit(nil) // Allow unlimited lines
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? themeManager.currentTheme.selectedDayColor : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isToday ? themeManager.currentTheme.todayBorderColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDate = date
        }
    }
}

extension Date {
    func isSameDay(as otherDate: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: otherDate)
    }
}

struct DayCellView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 
