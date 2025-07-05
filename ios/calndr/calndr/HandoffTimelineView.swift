import SwiftUI

struct HandoffTimelineView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let calendarDays: [Date]
    let gridColumns: Int = 7
    
    @State private var showingHandoffModal = false
    @State private var selectedHandoffDate: Date?
    @State private var draggedBubbleDate: Date?
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            let cellWidth = geometry.size.width / CGFloat(gridColumns)
            let cellHeight = geometry.size.height / CGFloat(calendarDays.count / gridColumns)
            
            Canvas { context, size in
                drawHandoffTimeline(context: context, size: size, cellWidth: cellWidth, cellHeight: cellHeight)
            }
            .background(Color.clear)
            .overlay(
                // Draggable handoff bubbles
                ForEach(getHandoffDays(), id: \.self) { date in
                    let position = getBubblePosition(for: date, cellWidth: cellWidth, cellHeight: cellHeight, size: geometry.size)
                    
                    Circle()
                        .fill(Color.white)
                        .stroke(Color.purple, lineWidth: 3)
                        .frame(width: 20, height: 20)
                        .position(x: position.x, y: position.y)
                        .offset(draggedBubbleDate == date ? dragOffset : .zero)
                        .onTapGesture {
                            selectedHandoffDate = date
                            showingHandoffModal = true
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    draggedBubbleDate = date
                                    dragOffset = value.translation
                                }
                                .onEnded { value in
                                    updateHandoffTime(for: date, dragOffset: value.translation, cellWidth: cellWidth)
                                    draggedBubbleDate = nil
                                    dragOffset = .zero
                                }
                        )
                }
            )
        }
        .sheet(isPresented: $showingHandoffModal) {
            if let selectedDate = selectedHandoffDate {
                HandoffTimeModal(
                    date: selectedDate,
                    viewModel: viewModel,
                    isPresented: $showingHandoffModal
                )
            }
        }
    }
    
    private func drawHandoffTimeline(context: GraphicsContext, size: CGSize, cellWidth: CGFloat, cellHeight: CGFloat) {
        let rows = calendarDays.count / gridColumns
        
        // Draw dotted horizontal lines for each week
        for row in 0..<rows {
            let y = CGFloat(row) * cellHeight + cellHeight * 0.8
            
            // Draw dotted line across the entire week
            let linePath = Path { path in
                for x in stride(from: 0, to: size.width, by: 10) {
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: min(x + 5, size.width), y: y))
                }
            }
            
            context.stroke(linePath, with: .color(.gray.opacity(0.6)), lineWidth: 2)
        }
        
        // Draw parent names for each week
        for row in 0..<rows {
            let y = CGFloat(row) * cellHeight + cellHeight * 0.8
            let weekStartIndex = row * gridColumns
            
            if weekStartIndex < calendarDays.count {
                let weekStartDate = calendarDays[weekStartIndex]
                let custodyInfo = viewModel.getCustodyInfo(for: weekStartDate)
                
                // Draw parent name at the start of each week
                context.draw(
                    Text(custodyInfo.text)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(themeManager.currentTheme.textColor),
                    at: CGPoint(x: 30, y: y - 15),
                    anchor: .center
                )
            }
        }
    }
    
    private func getHandoffDays() -> [Date] {
        // Find days where custody changes (potential handoff days)
        var handoffDays: [Date] = []
        var previousOwner: String?
        
        for date in calendarDays {
            let currentOwner = viewModel.getCustodyInfo(for: date).owner
            
            if let prev = previousOwner, prev != currentOwner {
                handoffDays.append(date)
            }
            
            previousOwner = currentOwner
        }
        
        return handoffDays
    }
    
    private func getBubblePosition(for date: Date, cellWidth: CGFloat, cellHeight: CGFloat, size: CGSize) -> CGPoint {
        guard let index = calendarDays.firstIndex(of: date) else {
            return CGPoint(x: 0, y: 0)
        }
        
        let row = index / gridColumns
        let col = index % gridColumns
        
        // Get handoff time for this date
        let handoffTime = viewModel.getHandoffTimeForDate(date)
        let timeProgress = calculateTimeProgress(hour: handoffTime.hour, minute: handoffTime.minute)
        
        let x = CGFloat(col) * cellWidth + (cellWidth * timeProgress)
        let y = CGFloat(row) * cellHeight + cellHeight * 0.8
        
        return CGPoint(x: x, y: y)
    }
    
    private func calculateTimeProgress(hour: Int, minute: Int) -> CGFloat {
        let totalMinutes = hour * 60 + minute
        let totalMinutesInDay = 24 * 60
        let progress = CGFloat(totalMinutes) / CGFloat(totalMinutesInDay)
        
        // Clamp between 0.1 and 0.9 to keep bubbles visible within cell boundaries
        return max(0.1, min(0.9, progress))
    }
    
    private func updateHandoffTime(for date: Date, dragOffset: CGSize, cellWidth: CGFloat) {
        // Calculate new time based on drag offset
        let dragProgress = dragOffset.width / cellWidth
        let currentTime = viewModel.getHandoffTimeForDate(date)
        let currentMinutes = currentTime.hour * 60 + currentTime.minute
        
        // Convert drag to minutes (allow full day range)
        let dragMinutes = Int(dragProgress * 24 * 60)
        let newTotalMinutes = currentMinutes + dragMinutes
        
        // Snap to 6-hour increments (360 minutes)
        let snappedMinutes = (newTotalMinutes / 360) * 360
        let clampedMinutes = max(0, min(1440, snappedMinutes)) // 0-24 hours
        
        let newHour = (clampedMinutes / 60) % 24
        let newMinute = clampedMinutes % 60
        
        // Save the new handoff time
        let timeString = String(format: "%02d:%02d", newHour, newMinute)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        APIService.shared.saveHandoffTime(date: dateString, time: timeString) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    // Refresh handoff times to update the view
                    viewModel.fetchHandoffTimes()
                case .failure(let error):
                    print("❌ Failed to save handoff time: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct HandoffTimelineView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 