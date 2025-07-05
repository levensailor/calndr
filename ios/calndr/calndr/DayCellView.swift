import SwiftUI

struct DayCellView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var focusedDate: Date?
    var namespace: Namespace.ID
    
    let date: Date
    let events: [Event]
    let schoolEvent: String?
    let weatherInfo: WeatherInfo?
    let isCurrentMonth: Bool
    let isToday: Bool
    let custodyOwner: String
    let custodyID: String
    @State private var showToggleFeedback: Bool = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Weather effects in the background
            if viewModel.showWeather, let weather = weatherInfo {
                WeatherFXView(weatherInfo: weather)
            }

            DayContentView(
                viewModel: viewModel,
                date: date,
                events: events,
                schoolEvent: schoolEvent,
                weatherInfo: weatherInfo,
                custodyOwner: custodyOwner,
                custodyID: custodyID,
                isCurrentMonth: isCurrentMonth,
                themeManager: themeManager
            )
            
            // Day Number on top
            Text(dayString(from: date))
                .font(.caption)
                .bold()
                .padding(2)
                .foregroundColor(isCurrentMonth ? themeManager.currentTheme.dayNumberColor : themeManager.currentTheme.otherMonthForegroundColor)
        }
        // Add a tap gesture to the custody area specifically
        .overlay(
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(height: 24) // Match the fixed custody rectangle height
                    .onLongPressGesture(minimumDuration: 0.25, maximumDistance: .infinity, pressing: { isPressing in
                        // Disable custody toggle when handoff timeline is active
                        if !viewModel.showHandoffTimeline && isPressing {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    }, perform: {
                        // Disable custody toggle when handoff timeline is active
                        if !viewModel.showHandoffTimeline {
                            viewModel.toggleCustodian(for: date)
                            withAnimation(.spring()) {
                                showToggleFeedback = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                withAnimation(.spring()) {
                                    showToggleFeedback = false
                                }
                            }
                        }
                    })
            }
        )
        .frame(minWidth: 0, maxWidth: .infinity)
        .background(isCurrentMonth ? themeManager.currentTheme.mainBackgroundColor : themeManager.currentTheme.otherMonthBackgroundColor)
        .cornerRadius(0)
        .overlay(
            // Inset border that doesn't interfere with grid lines
            RoundedRectangle(cornerRadius: 0)
                .inset(by: 0.5) // Small inset to ensure consistent placement
                .stroke(showToggleFeedback ? .green : (isToday ? themeManager.currentTheme.todayBorderColor : Color.clear), lineWidth: showToggleFeedback ? 3 : 2)
        )
        .scaleEffect(showToggleFeedback ? 1.05 : 1.0)
        .matchedGeometryEffect(id: date, in: namespace, isSource: focusedDate != date)
        .onTapGesture {
            // Disable tap gesture when handoff timeline is active
            if !viewModel.showHandoffTimeline {
                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.8)) {
                    focusedDate = date
                }
            }
        }
        .opacity(focusedDate == date ? 0 : 1)
    }
    
    private func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

struct DayCellView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 
