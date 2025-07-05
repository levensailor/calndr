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
    @State private var showTimeOverlay = false
    @State private var overlayTime = ""
    @State private var overlayPosition: CGPoint = .zero
    
    // Available handoff times - same as in modal
    private let availableHandoffTimes = [
        (hour: 9, minute: 0, display: "9:00 AM"),
        (hour: 12, minute: 0, display: "12:00 PM"),
        (hour: 17, minute: 0, display: "5:00 PM")
    ]

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
                                    
                                    // Show time overlay and update position/time
                                    showTimeOverlay = true
                                    overlayPosition = CGPoint(
                                        x: position.x + value.translation.width,
                                        y: position.y - 50 // Position above the bubble
                                    )
                                    
                                    // Calculate and display the new time based on drag position
                                    let newTimeIndex = calculateNewTimeIndex(dragOffset: value.translation.width, cellWidth: cellWidth)
                                    overlayTime = availableHandoffTimes[newTimeIndex].display
                                }
                                .onEnded { value in
                                    updateHandoffTime(for: date, dragOffset: value.translation, cellWidth: cellWidth)
                                    draggedBubbleDate = nil
                                    dragOffset = .zero
                                    showTimeOverlay = false
                                }
                        )
                }
            )
            
            // Time overlay during dragging
            if showTimeOverlay {
                Text(overlayTime)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.purple)
                            .shadow(radius: 8)
                    )
                    .position(overlayPosition)
                    .zIndex(100) // Ensure it appears above other elements
                    .animation(.easeInOut(duration: 0.1), value: overlayPosition)
            }
        }
        .sheet(isPresented: $showingHandoffModal) {
            if let selectedDate = selectedHandoffDate {
                HandoffTimeModal(
                    date: selectedDate,
                    viewModel: viewModel,
                    isPresented: $showingHandoffModal
                )
                .environmentObject(themeManager)
            }
        }
    }
    
    private func calculateNewTimeIndex(dragOffset: CGFloat, cellWidth: CGFloat) -> Int {
        // Calculate drag progress as a percentage of cell width
        let dragProgress = dragOffset / cellWidth
        
        // Map drag progress to time indices (allowing wrapping)
        let baseIndex = 1 // Start from 12pm as middle position
        let indexChange = Int(round(dragProgress * 3)) // Each third of drag changes by one time slot
        
        let newIndex = baseIndex + indexChange
        
        // Clamp to valid range (0-2)
        return max(0, min(2, newIndex))
    }
    
    private func drawHandoffTimeline(context: GraphicsContext, size: CGSize, cellWidth: CGFloat, cellHeight: CGFloat) {
        let rows = calendarDays.count / gridColumns
        
        // Draw colored custody line segments for each week
        for row in 0..<rows {
            let y = CGFloat(row) * cellHeight + cellHeight * 0.8
            let weekStartIndex = row * gridColumns
            let weekEndIndex = min(weekStartIndex + gridColumns, calendarDays.count)
            
            if weekStartIndex < calendarDays.count {
                // Get handoff times for this week
                var weekHandoffs: [(date: Date, position: CGFloat)] = []
                
                // Add handoffs for this week
                for i in weekStartIndex..<weekEndIndex {
                    let date = calendarDays[i]
                    if getHandoffDays().contains(date) {
                        let handoffTime = viewModel.getHandoffTimeForDate(date)
                        let timeProgress = calculateTimeProgress(hour: handoffTime.hour, minute: handoffTime.minute)
                        let col = i % gridColumns
                        let x = CGFloat(col) * cellWidth + (cellWidth * timeProgress)
                        weekHandoffs.append((date: date, position: x))
                    }
                }
                
                // Sort handoffs by position
                weekHandoffs.sort { $0.position < $1.position }
                
                // Draw line segments between handoffs
                var startX: CGFloat = 0
                var currentCustodyID = ""
                
                // Get custody for start of week
                if weekStartIndex < calendarDays.count {
                    let weekStartDate = calendarDays[weekStartIndex]
                    currentCustodyID = viewModel.getCustodyInfo(for: weekStartDate).owner
                }
                
                // Draw segments
                for handoff in weekHandoffs {
                    let endX = handoff.position
                    
                    // Draw segment from startX to endX with current custody color
                    let segmentPath = Path { path in
                        path.move(to: CGPoint(x: startX, y: y))
                        path.addLine(to: CGPoint(x: endX, y: y))
                    }
                    
                    let custodyColor = getCustodyColor(for: currentCustodyID)
                    context.stroke(segmentPath, with: .color(custodyColor.opacity(0.7)), lineWidth: 8)
                    
                    // Update custody ID to the new owner after handoff
                    // The handoff date shows who gets custody after the handoff
                    let newCustodyID = viewModel.getCustodyInfo(for: handoff.date).owner
                    currentCustodyID = newCustodyID
                    startX = endX
                }
                
                // Draw final segment from last handoff to end of week
                let finalSegmentPath = Path { path in
                    path.move(to: CGPoint(x: startX, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                
                let finalCustodyColor = getCustodyColor(for: currentCustodyID)
                context.stroke(finalSegmentPath, with: .color(finalCustodyColor.opacity(0.7)), lineWidth: 8)
            }
        }
    }
    
    private func getCustodyColor(for custodyID: String) -> Color {
        if custodyID == viewModel.custodianOne?.id {
            return themeManager.currentTheme.parentOneColor
        } else {
            return themeManager.currentTheme.parentTwoColor
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
        // Map the three allowed times to positions within the cell
        let totalMinutes = hour * 60 + minute
        
        // Find which of our allowed times this matches
        for (index, time) in availableHandoffTimes.enumerated() {
            let timeMinutes = time.hour * 60 + time.minute
            if totalMinutes == timeMinutes {
                // Map to positions: 9am->0.2, 12pm->0.5, 5pm->0.8
                switch index {
                case 0: return 0.2 // 9am
                case 1: return 0.5 // 12pm  
                case 2: return 0.8 // 5pm
                default: return 0.5
                }
            }
        }
        
        // If no exact match, find closest and return its position
        let closestIndex = findClosestTimeIndex(hour: hour, minute: minute)
        switch closestIndex {
        case 0: return 0.2 // 9am
        case 1: return 0.5 // 12pm
        case 2: return 0.8 // 5pm
        default: return 0.5
        }
    }
    
    private func findClosestTimeIndex(hour: Int, minute: Int) -> Int {
        let totalMinutes = hour * 60 + minute
        
        var closestIndex = 0
        var smallestDifference = Int.max
        
        for (index, time) in availableHandoffTimes.enumerated() {
            let timeMinutes = time.hour * 60 + time.minute
            let difference = abs(totalMinutes - timeMinutes)
            
            if difference < smallestDifference {
                smallestDifference = difference
                closestIndex = index
            }
        }
        
        return closestIndex
    }
    
    private func formatTimeString(hour: Int, minute: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        
        if let time = Calendar.current.date(from: components) {
            return formatter.string(from: time)
        }
        return "\(hour):\(String(format: "%02d", minute))"
    }
    
    private func updateHandoffTime(for date: Date, dragOffset: CGSize, cellWidth: CGFloat) {
        // Calculate which time slot based on drag
        let newTimeIndex = calculateNewTimeIndex(dragOffset: dragOffset.width, cellWidth: cellWidth)
        let newTime = availableHandoffTimes[newTimeIndex]
        
        let timeString = String(format: "%02d:%02d", newTime.hour, newTime.minute)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        print("Updating handoff time to: \(newTime.display) for date: \(dateString)")
        
        APIService.shared.saveHandoffTime(date: dateString, time: timeString) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    // Update custody for this date based on handoff time change
                    self.updateCustodyBasedOnHandoffTimeChange(for: date)
                    
                    // Refresh handoff times to update the view
                    viewModel.fetchHandoffTimes()
                case .failure(let error):
                    print("❌ Failed to save handoff time: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func updateCustodyBasedOnHandoffTimeChange(for date: Date) {
        // Determine who should have custody after this handoff
        let custodyInfo = viewModel.getCustodyInfo(for: date)
        let currentCustodian = custodyInfo.owner
        
        // Toggle to the other parent
        let newCustodianId: String
        if currentCustodian == viewModel.custodianOne?.id {
            newCustodianId = viewModel.custodianTwo?.id ?? ""
        } else {
            newCustodianId = viewModel.custodianOne?.id ?? ""
        }
        
        guard !newCustodianId.isEmpty else {
            print("Error: Could not determine new custodian ID for handoff")
            return
        }
        
        let dateString = viewModel.isoDateString(from: date)
        
        // Update custody record for this date
        APIService.shared.updateCustodyRecord(for: dateString, custodianId: newCustodianId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let custodyResponse):
                    print("✅ Updated custody for handoff date via drag: \(custodyResponse)")
                    // Update local custody records
                    if let index = self.viewModel.custodyRecords.firstIndex(where: { $0.event_date == custodyResponse.event_date }) {
                        self.viewModel.custodyRecords[index] = custodyResponse
                    } else {
                        self.viewModel.custodyRecords.append(custodyResponse)
                    }
                    self.viewModel.updateCustodyPercentages()
                    
                case .failure(let error):
                    print("❌ Failed to update custody for handoff: \(error.localizedDescription)")
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