import SwiftUI

struct DayCellView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var focusedDate: Date?
    var namespace: Namespace.ID
    
    let date: Date
    let events: [Event]
    let schoolEvent: String?
    let daycareEvent: String?
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
                daycareEvent: daycareEvent,
                weatherInfo: weatherInfo,
                custodyOwner: custodyOwner,
                custodyID: custodyID,
                isCurrentMonth: isCurrentMonth,
                isToday: isToday
            )
            
            // Day Number on top with brutalist styling
            Text(dayString(from: date))
                .font(.system(size: 14, weight: .black, design: .default))
                .foregroundColor(isToday ? themeManager.currentTheme.accentColorSwiftUI : 
                              (isCurrentMonth ? themeManager.currentTheme.textColorSwiftUI : themeManager.currentTheme.textColorSwiftUI.opacity(0.4)))
                .padding(4)
                .background(isToday ? themeManager.currentTheme.textColorSwiftUI.opacity(0.1) : Color.clear)
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
        .background(isCurrentMonth ? themeManager.currentTheme.mainBackgroundColorSwiftUI : themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
        .overlay(
            // Sharp rectangular border with brutalist styling
            Rectangle()
                .stroke(
                    showToggleFeedback ? Color.green : 
                    (isToday ? themeManager.currentTheme.accentColorSwiftUI : themeManager.currentTheme.textColorSwiftUI.opacity(0.2)), 
                    lineWidth: showToggleFeedback ? 4 : (isToday ? 3 : 1)
                )
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
