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
                        .scaleEffect(draggedBubbleDate == date ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: draggedBubbleDate == date)
                        .gesture(
                            // Combined gesture that handles both drag and tap
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    // Only start dragging if we've moved beyond a threshold
                                    if abs(value.translation.width) > 10 || abs(value.translation.height) > 10 {
                                        draggedBubbleDate = date
                                        dragOffset = value.translation
                                        
                                        // Show time overlay and update position/time
                                        showTimeOverlay = true
                                        overlayPosition = CGPoint(
                                            x: position.x + value.translation.width,
                                            y: position.y - 50 // Position above the bubble
                                        )
                                        
                                        // Calculate the new date and time based on drag position
                                        let newDateAndTime = calculateNewDateAndTime(
                                            originalDate: date,
                                            dragOffset: value.translation,
                                            cellWidth: cellWidth,
                                            cellHeight: cellHeight,
                                            originalPosition: position
                                        )
                                        
                                        overlayTime = "\(formatDate(newDateAndTime.date)) \(newDateAndTime.time.display)"
                                    }
                                }
                                .onEnded { value in
                                    // If we didn't drag much, treat as a tap
                                    if abs(value.translation.width) <= 10 && abs(value.translation.height) <= 10 {
                                        // Tap action - show modal
                                        selectedHandoffDate = date
                                        // Use async to ensure state update completes before presenting modal
                                        DispatchQueue.main.async {
                                            showingHandoffModal = true
                                        }
                                    } else {
                                        // Drag action - update handoff time
                                        updateHandoffTime(
                                            originalDate: date,
                                            dragOffset: value.translation,
                                            cellWidth: cellWidth,
                                            cellHeight: cellHeight,
                                            originalPosition: position
                                        )
                                    }
                                    
                                    // Reset drag state
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
    
    private func calculateNewDateAndTime(
        originalDate: Date,
        dragOffset: CGSize,
        cellWidth: CGFloat,
        cellHeight: CGFloat,
        originalPosition: CGPoint
    ) -> (date: Date, time: (hour: Int, minute: Int, display: String)) {
        
        // Calculate the new position
        let newPosition = CGPoint(
            x: originalPosition.x + dragOffset.width,
            y: originalPosition.y + dragOffset.height
        )
        
        // Calculate which day this corresponds to
        let newCol = Int(newPosition.x / cellWidth)
        let newRow = Int(newPosition.y / cellHeight)
        
        // Calculate the calendar index
        let newIndex = newRow * gridColumns + newCol
        
        // Ensure we're within bounds
        let clampedIndex = max(0, min(calendarDays.count - 1, newIndex))
        let newDate = calendarDays[clampedIndex]
        
        // Calculate time within the cell
        let cellLocalX = newPosition.x - (CGFloat(newCol) * cellWidth)
        let timeProgress = cellLocalX / cellWidth
        
        // Map time progress to our available times
        let timeIndex: Int
        if timeProgress < 0.35 {
            timeIndex = 0 // 9am
        } else if timeProgress < 0.65 {
            timeIndex = 1 // 12pm
        } else {
            timeIndex = 2 // 5pm
        }
        
        let selectedTime = availableHandoffTimes[timeIndex]
        
        return (date: newDate, time: selectedTime)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
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
    
    private func updateHandoffTime(
        originalDate: Date,
        dragOffset: CGSize,
        cellWidth: CGFloat,
        cellHeight: CGFloat,
        originalPosition: CGPoint
    ) {
        // Calculate the new date and time based on drag position
        let newDateAndTime = calculateNewDateAndTime(
            originalDate: originalDate,
            dragOffset: dragOffset,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
            originalPosition: originalPosition
        )
        
        let newDate = newDateAndTime.date
        let newTime = newDateAndTime.time
        let timeString = String(format: "%02d:%02d", newTime.hour, newTime.minute)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let originalDateString = dateFormatter.string(from: originalDate)
        let newDateString = dateFormatter.string(from: newDate)
        
        print("Moving handoff from \(originalDateString) to \(newDateString) at \(newTime.display)")
        
        // Get or create handoff data based on custody information
        let originalHandoffData = getHandoffDataForDate(originalDate)
        
        // If moving to a different date, we need to handle this differently
        if originalDateString != newDateString {
            // Try to find existing handoff record to delete it
            if let existingHandoff = viewModel.handoffTimes.first(where: { $0.date == originalDateString }) {
                // Delete existing handoff record
                APIService.shared.deleteHandoffTime(handoffId: "\(existingHandoff.id)") { deleteResult in
                    DispatchQueue.main.async {
                        switch deleteResult {
                        case .success(_):
                            print("✅ Deleted old handoff from \(originalDateString)")
                            
                            // Create new handoff on the new date
                            let newHandoffData = self.getHandoffDataForDate(newDate)
                            APIService.shared.saveHandoffTime(
                                date: newDateString, 
                                time: timeString,
                                location: originalHandoffData.location,
                                fromParentId: newHandoffData.fromParentId,
                                toParentId: newHandoffData.toParentId
                            ) { saveResult in
                                DispatchQueue.main.async {
                                    self.handleSaveResult(saveResult, newDate: newDate, newTime: newTime, originalDate: originalDate)
                                }
                            }
                            
                        case .failure(let error):
                            print("❌ Failed to delete old handoff: \(error.localizedDescription)")
                        }
                    }
                }
            } else {
                // No existing handoff to delete, just create new one
                let newHandoffData = getHandoffDataForDate(newDate)
                APIService.shared.saveHandoffTime(
                    date: newDateString, 
                    time: timeString,
                    location: originalHandoffData.location,
                    fromParentId: newHandoffData.fromParentId,
                    toParentId: newHandoffData.toParentId
                ) { saveResult in
                    DispatchQueue.main.async {
                        self.handleSaveResult(saveResult, newDate: newDate, newTime: newTime, originalDate: originalDate)
                    }
                }
            }
        } else {
            // Same date, just update the time
            APIService.shared.saveHandoffTime(
                date: newDateString, 
                time: timeString,
                location: originalHandoffData.location,
                fromParentId: originalHandoffData.fromParentId,
                toParentId: originalHandoffData.toParentId
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(_):
                        print("✅ Updated handoff time to \(newTime.display) on \(newDateString)")
                        self.viewModel.fetchHandoffTimes()
                        
                    case .failure(let error):
                        print("❌ Failed to save handoff time: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func getHandoffDataForDate(_ date: Date) -> (location: String, fromParentId: String?, toParentId: String?) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        // Try to get existing handoff data first
        if let existingHandoff = viewModel.handoffTimes.first(where: { $0.date == dateString }) {
            return (
                location: existingHandoff.location ?? "daycare",
                fromParentId: existingHandoff.from_parent_id,
                toParentId: existingHandoff.to_parent_id
            )
        }
        
        // Generate handoff data based on custody information
        let custodyInfo = viewModel.getCustodyInfo(for: date)
        let currentCustodian = custodyInfo.owner
        
        let fromParentId: String?
        let toParentId: String?
        
        if currentCustodian == viewModel.custodianOne?.id {
            fromParentId = viewModel.custodianOne?.id
            toParentId = viewModel.custodianTwo?.id
        } else {
            fromParentId = viewModel.custodianTwo?.id
            toParentId = viewModel.custodianOne?.id
        }
        
        // Determine default location based on day of week
        let dayOfWeek = Calendar.current.component(.weekday, from: date)
        let isWeekend = dayOfWeek == 1 || dayOfWeek == 7 // Sunday or Saturday
        let defaultLocation = isWeekend ? "\(toParentId == viewModel.custodianOne?.id ? viewModel.custodianOne?.first_name.lowercased() ?? "parent" : viewModel.custodianTwo?.first_name.lowercased() ?? "parent")'s home" : "daycare"
        
        return (
            location: defaultLocation,
            fromParentId: fromParentId,
            toParentId: toParentId
        )
    }
    
    private func handleSaveResult(_ result: Result<HandoffTimeResponse, Error>, newDate: Date, newTime: (hour: Int, minute: Int, display: String), originalDate: Date?) {
        switch result {
        case .success(_):
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            print("✅ Created new handoff on \(dateFormatter.string(from: newDate)) at \(newTime.display)")
            
            // Update custody for both dates if moving
            if let originalDate = originalDate {
                self.updateCustodyForHandoffMove(originalDate: originalDate, newDate: newDate)
            } else {
                self.updateCustodyBasedOnHandoffTimeChange(for: newDate)
            }
            
            // Refresh handoff times to update the view
            self.viewModel.fetchHandoffTimes()
            
        case .failure(let error):
            print("❌ Failed to create new handoff: \(error.localizedDescription)")
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
    
    private func updateCustodyForHandoffMove(originalDate: Date, newDate: Date) {
        // When moving a handoff, we need to implement proper transition logic
        // The handoff represents the point where custody changes from one parent to another
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let originalDateString = dateFormatter.string(from: originalDate)
        let newDateString = dateFormatter.string(from: newDate)
        
        print("Updating custody transition logic for handoff move from \(originalDateString) to \(newDateString)")
        
        // Get the handoff data to understand the transition
        let handoffData = getHandoffDataForDate(newDate)
        
        guard let fromParentId = handoffData.fromParentId,
              let toParentId = handoffData.toParentId else {
            print("Error: Could not determine parent IDs for handoff transition")
            return
        }
        
        // Determine the direction of the move and implement transition logic
        let calendar = Calendar.current
        let daysBetween = calendar.dateComponents([.day], from: originalDate, to: newDate).day ?? 0
        
        if daysBetween == 0 {
            // Same day, just time change - no custody update needed
            print("Same day handoff move, no custody changes needed")
            return
        }
        
        // For multi-day moves, we need to update custody based on handoff transition logic
        updateCustodyTransition(
            originalDate: originalDate,
            newDate: newDate,
            fromParentId: fromParentId,
            toParentId: toParentId,
            daysBetween: daysBetween
        )
    }
    
    private func updateCustodyTransition(
        originalDate: Date,
        newDate: Date,
        fromParentId: String,
        toParentId: String,
        daysBetween: Int
    ) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        
        // The handoff date gets custody for the "to" parent (after handoff)
        let newDateString = dateFormatter.string(from: newDate)
        
        // Update custody for the new handoff date - this is where custody transitions TO the "to" parent
        APIService.shared.updateCustodyRecord(for: newDateString, custodianId: toParentId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let custodyResponse):
                    print("✅ Updated custody for new handoff date \(newDateString): \(custodyResponse)")
                    self.updateLocalCustodyRecord(custodyResponse)
                    
                case .failure(let error):
                    print("❌ Failed to update custody for new handoff date: \(error.localizedDescription)")
                }
            }
        }
        
        // Handle the custody pattern around the handoff based on direction
        if daysBetween > 0 {
            // Moving handoff to the right (later) - update custody for days between
            self.updateCustodyForRightwardMove(
                originalDate: originalDate,
                newDate: newDate,
                fromParentId: fromParentId,
                toParentId: toParentId
            )
        } else {
            // Moving handoff to the left (earlier) - update custody for days between  
            self.updateCustodyForLeftwardMove(
                originalDate: originalDate,
                newDate: newDate,
                fromParentId: fromParentId,
                toParentId: toParentId
            )
        }
    }
    
    private func updateCustodyForRightwardMove(
        originalDate: Date,
        newDate: Date,
        fromParentId: String,
        toParentId: String
    ) {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // When moving handoff right, the "from" parent keeps custody until the new handoff date
        // Update custody for days between original and new date to be "from" parent
        
        var currentDate = calendar.date(byAdding: .day, value: 1, to: originalDate)!
        
        while currentDate < newDate {
            let dateString = dateFormatter.string(from: currentDate)
            
            APIService.shared.updateCustodyRecord(for: dateString, custodianId: fromParentId) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let custodyResponse):
                        print("✅ Updated custody (rightward) for \(dateString): \(custodyResponse)")
                        self.updateLocalCustodyRecord(custodyResponse)
                        
                    case .failure(let error):
                        print("❌ Failed to update custody (rightward) for \(dateString): \(error.localizedDescription)")
                    }
                }
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
    }
    
    private func updateCustodyForLeftwardMove(
        originalDate: Date,
        newDate: Date,
        fromParentId: String,
        toParentId: String
    ) {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // When moving handoff left, the transition happens earlier
        // Days between new date and original date get the "from" parent until the new handoff
        
        var currentDate = calendar.date(byAdding: .day, value: 1, to: newDate)!
        
        while currentDate < originalDate {
            let dateString = dateFormatter.string(from: currentDate)
            
            APIService.shared.updateCustodyRecord(for: dateString, custodianId: fromParentId) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let custodyResponse):
                        print("✅ Updated custody (leftward) for \(dateString): \(custodyResponse)")
                        self.updateLocalCustodyRecord(custodyResponse)
                        
                    case .failure(let error):
                        print("❌ Failed to update custody (leftward) for \(dateString): \(error.localizedDescription)")
                    }
                }
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        // Also update the original date to revert to the previous pattern
        let originalDateString = dateFormatter.string(from: originalDate)
        APIService.shared.updateCustodyRecord(for: originalDateString, custodianId: fromParentId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let custodyResponse):
                    print("✅ Reverted custody for original date \(originalDateString): \(custodyResponse)")
                    self.updateLocalCustodyRecord(custodyResponse)
                    
                case .failure(let error):
                    print("❌ Failed to revert custody for original date: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func updateLocalCustodyRecord(_ custodyResponse: CustodyResponse) {
        if let index = self.viewModel.custodyRecords.firstIndex(where: { $0.event_date == custodyResponse.event_date }) {
            self.viewModel.custodyRecords[index] = custodyResponse
        } else {
            self.viewModel.custodyRecords.append(custodyResponse)
        }
        self.viewModel.updateCustodyPercentages()
    }
}

struct HandoffTimelineView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 