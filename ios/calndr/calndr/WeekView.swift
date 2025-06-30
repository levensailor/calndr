import SwiftUI

struct WeekView: View {
    @ObservedObject var viewModel: CalendarViewModel
    
    var body: some View {
        VStack {
            ForEach(getDaysForCurrentWeek(), id: \.self) { day in
                HStack {
                    VStack(alignment: .leading) {
                        Text(day.formatted(.dateTime.weekday(.wide)))
                            .font(.headline)
                        Text(day.formatted(.dateTime.month().day()))
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    // You could add event indicators here
                }
                .padding()
                .frame(minHeight: 75)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
    
    private func getDaysForCurrentWeek() -> [Date] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: viewModel.currentDate) else {
            return []
        }
        
        var days: [Date] = []
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: weekInterval.start) {
                days.append(date)
            }
        }
        return days
    }
}

struct WeekView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager)
        WeekView(viewModel: calendarViewModel)
    }
} 
