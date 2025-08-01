import SwiftUI

struct DayContentView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let date: Date
    let events: [Event]
    let schoolEvent: String?
    let daycareEvent: String?
    let weatherInfo: WeatherInfo?
    let custodyOwner: String
    let custodyID: String
    let isCurrentMonth: Bool
    let isToday: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ZStack {
                // Temperature on the left
                if let weather = weatherInfo {
                    HStack {
                        Text("\(Int(weather.temperature.rounded()))°")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                            .padding(1)
                            .background(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                            .cornerRadius(2)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 1)
            .frame(height: 15) // Give a fixed height to maintain layout

            // School Event - Orange color
            if let schoolEvent = schoolEvent {
                Text(schoolEvent)
                    .font(.system(size: 7))
                    .lineLimit(2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 1)
                    .background(Color.orange)
                    .cornerRadius(3)
            }
            
            // Daycare Event - Purple color
            if let daycareEvent = daycareEvent {
                Text(daycareEvent)
                    .font(.system(size: 7))
                    .lineLimit(2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 1)
                    .background(Color.purple)
                    .cornerRadius(3)
            }

            // Family Event rows (exclude school/daycare events and custody events)
            ForEach(events.filter { 
                $0.position != 4 && 
                !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                $0.source_type != "school" &&
                $0.source_type != "daycare"
            }) { event in
                Text(event.content)
                    .font(.system(size: 7))
                    .lineLimit(4)
                    .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                    .padding(.horizontal, 1)
                    .background(themeManager.currentTheme.iconActiveColorSwiftUI.opacity(0.1))
                    .cornerRadius(3)
            }
            
            Spacer()
            // Custody row logic
            if !custodyOwner.isEmpty && !viewModel.showHandoffTimeline {
                // Normal custody display
                Text(custodyOwner.capitalized)
                    .font(.system(size: 9))
                    .bold()
                    .foregroundColor(custodyID == viewModel.custodianOneId ? themeManager.currentTheme.parentOneTextColor : themeManager.currentTheme.parentTwoTextColor)
                    .frame(maxWidth: .infinity, minHeight: 24, maxHeight: 24) // Fixed height
                    .background(custodyID == viewModel.custodianOneId ? themeManager.currentTheme.parentOneColorSwiftUI : themeManager.currentTheme.parentTwoColorSwiftUI)
                    .opacity(isToday ? 1.0 : 0.6)
            } else if !custodyOwner.isEmpty && viewModel.showHandoffTimeline {
                // Handoff timeline display
                Text(custodyOwner.capitalized)
                    .font(.system(size: 9))
                    .bold()
                    .foregroundColor(custodyID == viewModel.custodianOneId ? themeManager.currentTheme.parentOneTextColor : themeManager.currentTheme.parentTwoTextColor)
                    .frame(maxWidth: .infinity, minHeight: 24, maxHeight: 24) // Fixed height
                    .background(custodyID == viewModel.custodianOneId ? themeManager.currentTheme.parentOneColorSwiftUI : themeManager.currentTheme.parentTwoColorSwiftUI)
                    .opacity(0.3)
            } else if custodyOwner.isEmpty && isPastDate() {
                // Past date with no custody - show subtle transparent gray
                Rectangle()
                    .frame(maxWidth: .infinity, minHeight: 24, maxHeight: 24)
                    .foregroundColor(Color.gray.opacity(0.1))
            }
        }
        .animateThemeChanges(themeManager)
    }
    
    private func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private func isPastDate() -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dateToCheck = calendar.startOfDay(for: date)
        return dateToCheck < today
    }
} 
