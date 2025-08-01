import SwiftUI

struct CalendarGridView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var focusedDate: Date?
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
                }
            }
            .padding(.vertical, 4)
            .background(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
            
            // Calendar grid with fixed height - cells adapt to fill space
            let numberOfWeeks = calculateNumberOfWeeks()
            let fixedCalendarHeight: CGFloat = 510 // Fixed height for consistent layout
            let rowHeight = fixedCalendarHeight / CGFloat(numberOfWeeks)
            
            ZStack {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)
                LazyVGrid(columns: columns, spacing: 1) {
                    ForEach(getDaysForCurrentMonth(), id: \.self) { date in
                        DayCellView(
                            viewModel: viewModel,
                            focusedDate: $focusedDate,
                            namespace: namespace,
                            date: date,
                            events: viewModel.eventsForDate(date),
                            schoolEvent: viewModel.schoolEventForDate(date),
                            daycareEvent: viewModel.daycareEventForDate(date),
                            weatherInfo: viewModel.weatherInfoForDate(date),
                            isCurrentMonth: isDateInCurrentMonth(date),
                            isToday: isToday(date),
                            custodyOwner: viewModel.getCustodyInfo(for: date).text,
                            custodyID: viewModel.getCustodyInfo(for: date).owner
                        )
                        .frame(height: rowHeight) // Adaptive height based on number of weeks
                        .opacity(viewModel.showHandoffTimeline ? 0.90 : 1.0) // Very slight dim when handoff timeline is active
                    }
                }
                .background(themeManager.currentTheme.accentColorSwiftUI)
                .allowsHitTesting(!viewModel.showHandoffTimeline) // Disable all interactions when handoff timeline is active
                .animateThemeChanges(themeManager)
                
                // Handoff Timeline Overlay
                if viewModel.showHandoffTimeline {
                    if viewModel.custodiansReady || viewModel.custodyDataReady {
                        // Show timeline progressively as data becomes available
                        HandoffTimelineView(viewModel: viewModel, calendarDays: getDaysForCurrentMonth())
                            .environmentObject(themeManager)
                            .allowsHitTesting(true) // Allow interactions with handoff bubbles
                            .zIndex(1000) // Ensure handoff timeline is above everything else
                            .opacity(viewModel.isHandoffDataReady ? 1.0 : 0.7) // Slightly dimmed if still loading
                        
                        // Show loading indicator overlay if still loading
                        if !viewModel.isHandoffDataReady && viewModel.isDataLoading {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: Color.purple))
                                            .scaleEffect(0.8)
                                        Text("Loading...")
                                            .font(.caption)
                                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                                    }
                                    .padding(12)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(8)
                                    Spacer()
                                }
                                Spacer()
                            }
                            .allowsHitTesting(false)
                            .zIndex(1001)
                        }
                    } else {
                        // Loading state overlay
                        ZStack {
                            Rectangle()
                                .fill(.ultraThinMaterial.opacity(0.2))
                                .allowsHitTesting(false)
                            
                            VStack(spacing: 16) {
                                if viewModel.isDataLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color.purple))
                                        .scaleEffect(1.5)
                                    
                                    Text("Loading handoff data...")
                                        .font(.headline)
                                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                                } else {
                                    // Data failed to load
                                    VStack(spacing: 12) {
                                        Image(systemName: "exclamationmark.triangle")
                                            .font(.title)
                                            .foregroundColor(.orange)
                                        
                                        Text("Failed to load handoff data")
                                            .font(.headline)
                                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                                        
                                        Button("Retry") {
                                            viewModel.fetchHandoffsAndCustody()
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)
                                        .background(Color.purple)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                                    .shadow(radius: 8)
                            )
                        }
                        .zIndex(1000)
                    }
                }
            }
            .frame(height: fixedCalendarHeight) // Fixed calendar height
        }
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
    
    private func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private func isToday(_ date: Date) -> Bool {
        return Calendar.current.isDateInToday(date)
    }

    private func isDateInCurrentMonth(_ date: Date) -> Bool {
        return Calendar.current.isDate(date, equalTo: viewModel.currentDate, toGranularity: .month)
    }
    
    private func calculateNumberOfWeeks() -> Int {
        let days = getDaysForCurrentMonth()
        return days.count / 7 // Each week has 7 days
    }
    
    private func cellBackgroundColor(for date: Date) -> Color {
        return isDateInCurrentMonth(date) ? Color.gray.opacity(0.1) : Color.clear
    }
    
    private func cellForegroundColor(for date: Date) -> Color {
        return isDateInCurrentMonth(date) ? .primary : .secondary
    }
    
}

struct CalendarGridView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 
