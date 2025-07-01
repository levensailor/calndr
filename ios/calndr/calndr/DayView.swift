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
    }
}

struct DayView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager)
        DayView(viewModel: calendarViewModel)
    }
} 
