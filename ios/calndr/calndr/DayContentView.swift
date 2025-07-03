import SwiftUI

struct DayContentView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let date: Date
    let events: [Event]
    let schoolEvent: String?
    let weatherInfo: WeatherInfo?
    let custodyOwner: String
    let custodyID: String
    let isCurrentMonth: Bool
    let themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ZStack {
                // Temperature on the left
                if let weather = weatherInfo {
                    HStack {
                        Text("\(Int(weather.temperature.rounded()))°")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.currentTheme.dayNumberColor)
                            .padding(1)
                            .background(themeManager.currentTheme.bubbleBackgroundColor)
                            .cornerRadius(2)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 1)
            .frame(height: 15) // Give a fixed height to maintain layout

            // School Event
            if let schoolEvent = schoolEvent {
                Text(schoolEvent)
                    .font(.system(size: 6))
                    .lineLimit(2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 1)
                    .background(Color.green)
                    .cornerRadius(3)
            }

            // Event rows
            ForEach(events.filter { $0.position < 4 && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.sorted(by: { $0.position < $1.position })) { event in
                Text(event.content)
                    .font(.system(size: 6))
                    .lineLimit(4)
                    .foregroundColor(themeManager.currentTheme.textColor)
                    .padding(.horizontal, 1)
                    .background(themeManager.currentTheme.iconActiveColor.opacity(0.1))
                    .cornerRadius(3)
            }
            
            Spacer()
            
            // Custody row - fixed height for consistency
            if !custodyOwner.isEmpty {
                Text(custodyOwner.capitalized)
                    .font(.system(size: 9))
                    .bold()
                    .foregroundColor(.black) // Always black for good contrast on light backgrounds
                    .frame(maxWidth: .infinity, minHeight: 24, maxHeight: 24) // Fixed height
                    .background(custodyID == viewModel.custodianOne?.id ? Color(hex: "#FFC2D9") : Color(hex: "#96CBFC"))
            }
        }
    }
    
    private func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
} 
