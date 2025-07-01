import SwiftUI

struct DayView: View {
    @ObservedObject var viewModel: CalendarViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text(viewModel.currentDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.largeTitle.bold())
                
                // Custody Information
                VStack(alignment: .leading) {
                    Text("Custody")
                        .font(.headline)
                    Text(viewModel.getCustodyInfo(for: viewModel.currentDate).text)
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                }
                
                // Events List
                VStack(alignment: .leading) {
                    Text("Events")
                        .font(.headline)
                    let events = viewModel.eventsForDate(viewModel.currentDate).filter { $0.position < 4 }
                    if events.isEmpty {
                        Text("No events scheduled.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(events) { event in
                            Text(event.content)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .frame(minHeight: UIScreen.main.bounds.height - 150)
        }
        .simultaneousGesture(
            DragGesture()
                .onEnded { value in
                    handleDaySwipeGesture(value)
                }
        )
    }
    
    private func handleDaySwipeGesture(_ value: DragGesture.Value) {
        let translation = value.translation
        let velocity = sqrt(pow(value.velocity.width, 2) + pow(value.velocity.height, 2))
        
        // Check for vertical swipes - be more aggressive about navigation detection
        let isVerticalDominant = abs(translation.height) > abs(translation.width) * 1.5
        let swipeThreshold: CGFloat = 100  // Increased threshold
        let velocityThreshold: CGFloat = 400  // Increased velocity threshold
        
        // Require either a long swipe OR high velocity for day navigation
        let isNavigationSwipe = (abs(translation.height) > swipeThreshold) || (velocity > velocityThreshold)
        
        if isVerticalDominant && isNavigationSwipe {
            let calendar = Calendar.current
            if translation.height < 0 {
                // Swipe up - next day
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: viewModel.currentDate) {
                    viewModel.currentDate = nextDay
                    viewModel.fetchEvents()
                }
            } else {
                // Swipe down - previous day
                if let previousDay = calendar.date(byAdding: .day, value: -1, to: viewModel.currentDate) {
                    viewModel.currentDate = previousDay
                    viewModel.fetchEvents()
                }
            }
        }
    }
}

struct DayView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager)
        DayView(viewModel: calendarViewModel)
    }
} 
