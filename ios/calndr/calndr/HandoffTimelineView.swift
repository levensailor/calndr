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
    @State private var passedOverHandoffs: Set<Date> = [] // Track handoffs passed over during drag
    
    // Available handoff times - same as in modal
    private let availableHandoffTimes = [
        (hour: 9, minute: 0, display: "9:00 AM"),
        (hour: 12, minute: 0, display: "12:00 PM"),
        (hour: 17, minute: 0, display: "5:00 PM")
    ]

    var body: some View {
        VStack {
            timelineContent
            // Check if all handoff data is loaded
//            if !viewModel.isHandoffDataReady {
//                VStack(spacing: 16) {
//                    ProgressView()
//                        .scaleEffect(1.2)
//                    Text("Loading handoff information...")
//                        .font(.headline)
//                        .foregroundColor(themeManager.currentTheme.textColor)
//                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//                .background(themeManager.currentTheme.mainBackgroundColor)
//                .onAppear {
//                    // Data is already being fetched by the ViewModel's initializer
//                    print("Timeline view appeared, waiting for handoff data...")
//                }
//                
//            } else {
//                // Existing timeline content
//                timelineContent
//            }
        }
    }
    
    private var timelineContent: some View {
        GeometryReader { geometry in
            let cellWidth = geometry.size.width / CGFloat(gridColumns)
            let cellHeight = geometry.size.height / CGFloat(calendarDays.count / gridColumns)
            
            ZStack {
                Canvas { context, size in
                    drawHandoffTimeline(context: context, size: size, cellWidth: cellWidth, cellHeight: cellHeight)
                }
                .background(Color.clear)
                .allowsHitTesting(false) // Canvas doesn't need to capture gestures
                
                // Draggable handoff bubbles with highest priority
                ForEach(getHandoffDays(), id: \.self) { date in
                    let position = getBubblePosition(for: date, cellWidth: cellWidth, cellHeight: cellHeight, size: geometry.size)
                    
                    ZStack {
                        // Invisible larger touch target (60x60) for better touch sensitivity
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 60, height: 60)
                        
                        // Visual bubble (20x20) - same size as before
                        Circle()
                            .fill(Color.white)
                            .stroke(Color.purple, lineWidth: 3)
                            .frame(width: 20, height: 20)
                            .scaleEffect(draggedBubbleDate == date ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: draggedBubbleDate == date)
                    }
                    .position(x: position.x, y: position.y)
                    .offset(x: draggedBubbleDate == date ? dragOffset.width : 0, y: 0) // X-axis only movement
                    .zIndex(2000) // Ensure bubbles are above everything else
                    .gesture(
                        // Combined gesture that handles both drag and tap - X-axis only
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                // Only allow horizontal dragging (X-axis only)
                                let horizontalTranslation = CGSize(width: value.translation.width, height: 0)
                                
                                // Only start dragging if we've moved horizontally beyond threshold (reduced to 5px for better sensitivity)
                                if abs(value.translation.width) > 5 {
                                    draggedBubbleDate = date
                                    dragOffset = horizontalTranslation // Only horizontal movement
                                    
                                    // Check for collision with other handoff bubbles
                                    detectHandoffCollisions(
                                        draggedDate: date,
                                        dragPosition: CGPoint(
                                            x: position.x + horizontalTranslation.width,
                                            y: position.y // Keep Y position fixed
                                        ),
                                        cellWidth: cellWidth,
                                        cellHeight: cellHeight
                                    )
                                    
                                    // Show time overlay and update position/time
                                    showTimeOverlay = true
                                    overlayPosition = CGPoint(
                                        x: position.x + horizontalTranslation.width,
                                        y: position.y - 50 // Position above the bubble
                                    )
                                    
                                    // Calculate the new date and time based on horizontal drag only
                                    let newDateAndTime = calculateNewDateAndTime(
                                        originalDate: date,
                                        dragOffset: horizontalTranslation, // X-axis only
                                        cellWidth: cellWidth,
                                        cellHeight: cellHeight,
                                        originalPosition: position
                                    )
                                    
                                    overlayTime = "\(formatDate(newDateAndTime.date)) \(newDateAndTime.time.display)"
                                }
                            }
                            .onEnded { value in
                                // If we didn't drag much horizontally, treat as a tap
                                if abs(value.translation.width) <= 5 {
                                    selectedHandoffDate = date
                                    
                                    // Ensure handoff data is loaded before showing modal
                                    if !viewModel.isHandoffDataReady {
                                        // Trigger data loading if not ready
                                        viewModel.fetchHandoffsAndCustody()
                                    }
                                    
                                    // Use async to ensure state update completes before presenting modal
                                    DispatchQueue.main.async {
                                        showingHandoffModal = true
                                    }
                                } else {
                                    // Drag action - update handoff time (X-axis only)
                                    let horizontalTranslation = CGSize(width: value.translation.width, height: 0)
                                    updateHandoffTime(
                                        originalDate: date,
                                        dragOffset: horizontalTranslation,
                                        cellWidth: cellWidth,
                                        cellHeight: cellHeight,
                                        originalPosition: position
                                    )
                                }
                                
                                // Reset drag state
                                draggedBubbleDate = nil
                                dragOffset = .zero
                                showTimeOverlay = false
                                
                                // Delete any handoff bubbles that were passed over
                                deletePassedOverHandoffs()
                            }
                    )
                }
                
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
                        .zIndex(3000) // Ensure overlay is above everything
                        .animation(.easeInOut(duration: 0.1), value: overlayPosition)
                }
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
        
        // Calculate the new position based on drag
        let newX = originalPosition.x + dragOffset.width
        let newY = originalPosition.y + dragOffset.height
        
        // Calculate relative movement in cells instead of absolute position
        // This ensures dragging "one day right" moves exactly one day, not based on pixel distance
        let cellsMovedX = Int(round(dragOffset.width / cellWidth))
        let cellsMovedY = Int(round(dragOffset.height / cellHeight))
        
        // Get original position
        guard let originalIndex = calendarDays.firstIndex(of: originalDate) else {
            return (date: originalDate, time: availableHandoffTimes[1])
        }
        let originalCol = originalIndex % gridColumns
        let originalRow = originalIndex / gridColumns
        
        // Calculate target position based on relative movement
        var targetCol = originalCol + cellsMovedX
        var targetRow = originalRow + cellsMovedY
        
        // Handle negative column (left drag across row boundaries)
        while targetCol < 0 && targetRow > 0 {
            targetCol += gridColumns
            targetRow -= 1
        }
        
        // Handle column overflow (right drag across row boundaries)
        while targetCol >= gridColumns && targetRow < (calendarDays.count / gridColumns) {
            targetCol -= gridColumns
            targetRow += 1
        }
        
        // Clamp to valid ranges
        targetCol = max(0, min(gridColumns - 1, targetCol))
        targetRow = max(0, min((calendarDays.count / gridColumns) - 1, targetRow))
        
        // Calculate the new calendar index
        let newIndex = targetRow * gridColumns + targetCol
        let clampedIndex = max(0, min(calendarDays.count - 1, newIndex))
        let newDate = calendarDays[clampedIndex]
        
        // Use calculated positions for time calculation
        let newCol = targetCol
        let newRow = targetRow
        
        // Calculate time within the cell based on X position within that specific cell
        let cellLocalX = newX - (CGFloat(newCol) * cellWidth)
        let timeProgress = max(0, min(1, cellLocalX / cellWidth)) // Clamp to 0-1
        
        // Map time progress to our available times with better distribution
        let timeIndex: Int
        if timeProgress < 0.33 {
            timeIndex = 0 // 9am
        } else if timeProgress < 0.67 {
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
        if custodyID == viewModel.custodianOneId {
            return themeManager.currentTheme.parentOneColor
        } else {
            return themeManager.currentTheme.parentTwoColor
        }
    }
    
    private func getHandoffDays() -> [Date] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var handoffDays: Set<Date> = []
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: viewModel.currentDate)
        let currentYear = calendar.component(.year, from: viewModel.currentDate)

        let visibleDaysSet = Set(calendarDays)
        
        for custodyRecord in viewModel.custodyRecords {
            if custodyRecord.handoff_day == true {
                if let date = dateFormatter.date(from: custodyRecord.event_date) {
                    let handoffMonth = calendar.component(.month, from: date)
                    let handoffYear = calendar.component(.year, from: date)
                    
                    if visibleDaysSet.contains(date) && handoffMonth == currentMonth && handoffYear == currentYear {
                        handoffDays.insert(date)
                    }
                }
            }
        }
        
        var previousOwner: String?
        
        for date in calendarDays {
            let currentOwner = viewModel.getCustodyInfo(for: date).owner
            
            if let prev = previousOwner, prev != currentOwner {
                let handoffMonth = calendar.component(.month, from: date)
                let handoffYear = calendar.component(.year, from: date)
                
                if handoffMonth == currentMonth && handoffYear == currentYear {
                    let dateString = dateFormatter.string(from: date)
                    let hasHandoffRecord = viewModel.custodyRecords.contains { record in
                        record.event_date == dateString && record.handoff_day == true
                    }
                    
                    if !hasHandoffRecord {
                        handoffDays.insert(date)
                    }
                }
            }
            
            previousOwner = currentOwner
        }
        
        return Array(handoffDays).sorted()
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
        
        // Since we're now using custody table, we just need to update the custody record
        // with handoff information
        updateCustodyWithHandoffInfo(originalDate, newDate, newDateString, timeString, newTime)
        
    }
    
    private func updateCustodyWithHandoffInfo(
        _ originalDate: Date,
        _ newDate: Date,
        _ newDateString: String,
        _ timeString: String,
        _ newTime: (hour: Int, minute: Int, display: String)
    ) {
        // Get handoff data for the new date
        let newHandoffData = getHandoffDataForDate(newDate)
        
        // Update custody records directly through the custody API
        
        // Update custody for the move if different date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let originalDateString = dateFormatter.string(from: originalDate)
        
        if originalDateString != newDateString {
            // Different day move - custody logic depends on direction
            if newDate > originalDate {
                // Moving RIGHT: Toggle custody from original day to day before destination
                let endDate = Calendar.current.date(byAdding: .day, value: -1, to: newDate) ?? newDate
                let rangeDates = generateDateRange(from: originalDate, to: endDate)
                self.updateCustodyForDateRange(rangeDates) {
                    // After range is updated, create handoff for new day
                    self.createHandoffForNewDay(newDate: newDate, time: newTime) {
                        // Refresh custody records after both updates complete
                        DispatchQueue.main.async {
                            self.viewModel.fetchCustodyRecords()
                        }
                    }
                }
            } else {
                // Moving LEFT: Toggle custody from day before original to destination day
                let startDate = Calendar.current.date(byAdding: .day, value: -1, to: originalDate) ?? originalDate
                let rangeDates = generateDateRange(from: startDate, to: newDate)
                self.updateCustodyForDateRange(rangeDates) {
                    // After range is updated, create handoff for new day
                    self.createHandoffForNewDay(newDate: newDate, time: newTime) {
                        // Refresh custody records after both updates complete
                        DispatchQueue.main.async {
                            self.viewModel.fetchCustodyRecords()
                        }
                    }
                }
            }
        } else {
            // Same day move - update custody with handoff info
            self.updateCustodyBasedOnHandoffTimeChange(for: newDate)
            // Refresh custody records to update the view
            self.viewModel.fetchCustodyRecords()
        }
    }
    
    private func getHandoffDataForDate(_ date: Date) -> (location: String, fromParentId: String?, toParentId: String?) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        // Try to get existing handoff data from custody records first
        if let existingCustody = viewModel.custodyRecords.first(where: { $0.event_date == dateString && $0.handoff_day == true }) {
            return (
                location: existingCustody.handoff_location ?? "daycare",
                fromParentId: nil, // We'll determine this from previous day's custody
                toParentId: existingCustody.custodian_id
            )
        }
        
        // Generate handoff data based on custody information
        let custodyInfo = viewModel.getCustodyInfo(for: date)
        let currentCustodian = custodyInfo.owner
        
        let fromParentId: String?
        let toParentId: String?
        
        if currentCustodian == viewModel.custodianOneId {
            fromParentId = viewModel.custodianTwoId // Previous custodian
            toParentId = viewModel.custodianOneId   // New custodian
        } else {
            fromParentId = viewModel.custodianOneId // Previous custodian
            toParentId = viewModel.custodianTwoId   // New custodian
        }
        
        // Determine default location based on day of week
        let dayOfWeek = Calendar.current.component(.weekday, from: date)
        let isWeekend = dayOfWeek == 1 || dayOfWeek == 7 // Sunday or Saturday
        let defaultLocation = isWeekend ? "\(toParentId == viewModel.custodianOneId ? viewModel.custodianOneName.lowercased() : viewModel.custodianTwoName.lowercased())'s home" : "daycare"
        
        return (
            location: defaultLocation,
            fromParentId: fromParentId,
            toParentId: toParentId
        )
    }
    

    
    private func updateCustodyBasedOnHandoffTimeChange(for date: Date) {
        // Determine who should have custody after this handoff
        let custodyInfo = viewModel.getCustodyInfo(for: date)
        let currentCustodian = custodyInfo.owner
        
        // Toggle to the other parent
        let newCustodianId: String
        if currentCustodian == viewModel.custodianOneId {
            newCustodianId = viewModel.custodianTwoId ?? ""
        } else {
            newCustodianId = viewModel.custodianOneId ?? ""
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
    
    private func createHandoffForNewDay(newDate: Date, time: (hour: Int, minute: Int, display: String), completion: @escaping () -> Void = {}) {
        // Create a handoff record for the new day with the specified time
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: newDate)
        let timeString = String(format: "%02d:%02d", time.hour, time.minute)
        
        print("📋 Creating handoff record for new day: \(dateString) at \(time.display)")
        
        // Get handoff data for the new date
        let handoffData = getHandoffDataForDate(newDate)
        
        // Create custody record with handoff information
        let custodyData: [String: Any] = [
            "date": dateString,
            "custodian_id": handoffData.toParentId ?? "",
            "handoff_day": true,
            "handoff_time": timeString,
            "handoff_location": handoffData.location
        ]
        
        // Use the existing updateCustodyRecord method (it can create records too)
        APIService.shared.updateCustodyRecord(for: dateString, custodianId: handoffData.toParentId ?? "") { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let custodyResponse):
                    print("✅ Created handoff record for new day: \(custodyResponse.content)")
                    self.updateLocalCustodyRecord(custodyResponse)
                    completion()
                    
                case .failure(let error):
                    print("❌ Failed to create handoff record for new day: \(error.localizedDescription)")
                    completion()
                }
            }
        }
    }
    
    private func updateCustodyForOriginalHandoffDay(originalDate: Date, completion: @escaping () -> Void = {}) {
        // Simple logic: when handoff moves away from a day, update custody for the original day
        // The original day gets custody assigned to whoever should have it now that the handoff moved
        let custodyInfo = viewModel.getCustodyInfo(for: originalDate)
        let currentCustodian = custodyInfo.owner
        
        // Toggle to the other parent (whoever should get custody now that handoff moved)
        let newCustodianId: String
        if currentCustodian == viewModel.custodianOneId {
            newCustodianId = viewModel.custodianTwoId ?? ""
        } else {
            newCustodianId = viewModel.custodianOneId ?? ""
        }
        
        guard !newCustodianId.isEmpty else {
            print("❌ Could not determine new custodian ID for original handoff day")
            completion()
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: originalDate)
        
        print("📋 Updating custody for original handoff day: \(dateString)")
        
        // Update custody for the original handoff day
        APIService.shared.updateCustodyRecord(for: dateString, custodianId: newCustodianId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let custodyResponse):
                    print("✅ Updated custody for original handoff day: \(custodyResponse.content)")
                    self.updateLocalCustodyRecord(custodyResponse)
                    completion()
                    
                case .failure(let error):
                    print("❌ Failed to update custody for original handoff day: \(error.localizedDescription)")
                    completion()
                }
            }
        }
    }
    
    private func updateCustodyForDateRange(_ dates: [Date], completion: @escaping () -> Void = {}) {
        guard !dates.isEmpty else {
            print("📋 No dates to update")
            completion()
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStrings = dates.map { dateFormatter.string(from: $0) }
        
        print("📋 Updating custody for \(dates.count) days: \(dateStrings.joined(separator: ", "))")
        
        // Process each date sequentially
        var remainingDates = dates
        
        func updateNextDate() {
            guard !remainingDates.isEmpty else {
                print("✅ Completed custody updates for all dates")
                completion()
                return
            }
            
            let currentDate = remainingDates.removeFirst()
            let custodyInfo = viewModel.getCustodyInfo(for: currentDate)
            let currentCustodian = custodyInfo.owner
            
            // Toggle to the other parent
            let newCustodianId: String
            if currentCustodian == viewModel.custodianOneId {
                newCustodianId = viewModel.custodianTwoId ?? ""
            } else {
                newCustodianId = viewModel.custodianOneId ?? ""
            }
            
            guard !newCustodianId.isEmpty else {
                print("❌ Could not determine new custodian ID for \(dateFormatter.string(from: currentDate))")
                updateNextDate() // Continue with next date
                return
            }
            
            let dateString = dateFormatter.string(from: currentDate)
            print("📋 Updating custody for \(dateString)")
            
            // Update custody for this date
            APIService.shared.updateCustodyRecord(for: dateString, custodianId: newCustodianId) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let custodyResponse):
                        print("✅ Updated custody for \(dateString): \(custodyResponse.content)")
                        self.updateLocalCustodyRecord(custodyResponse)
                        updateNextDate() // Continue with next date
                        
                    case .failure(let error):
                        print("❌ Failed to update custody for \(dateString): \(error.localizedDescription)")
                        updateNextDate() // Continue with next date even on failure
                    }
                }
            }
        }
        
        updateNextDate()
    }
    
    private func updateCustodyForHandoffMove(originalDate: Date, newDate: Date, completion: @escaping () -> Void = {}) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let originalDateString = dateFormatter.string(from: originalDate)
        let newDateString = dateFormatter.string(from: newDate)
        
        print("🔄 Moving handoff from \(originalDateString) to \(newDateString)")
        
        // Same day move - just update that day's custody
        if originalDate == newDate {
            updateSingleDayCustody(date: newDate) {
                completion()
            }
            return
        }
        
        // Different day move - need to update custody for the affected range
        let calendar = Calendar.current
        
        // Determine who should get custody for the days between original and new handoff
        let custodianToAssign: (owner: String, text: String)
        
        if newDate > originalDate {
            // Moving handoff RIGHT (to future): 
            // Assign custody to whoever had it the day BEFORE the original handoff
            let dayBeforeOriginal = calendar.date(byAdding: .day, value: -1, to: originalDate) ?? originalDate
            custodianToAssign = viewModel.getCustodyInfo(for: dayBeforeOriginal)
            print("📋 Moving handoff RIGHT: Using custody from day before original (\(dateFormatter.string(from: dayBeforeOriginal)))")
        } else {
            // Moving handoff LEFT (to past):
            // Assign custody to whoever had it the day AFTER the original handoff
            let dayAfterOriginal = calendar.date(byAdding: .day, value: 1, to: originalDate) ?? originalDate
            custodianToAssign = viewModel.getCustodyInfo(for: dayAfterOriginal)
            print("📋 Moving handoff LEFT: Using custody from day after original (\(dateFormatter.string(from: dayAfterOriginal)))")
        }
        
        guard !custodianToAssign.owner.isEmpty else {
            print("❌ Could not determine custodian to assign for handoff move")
            completion()
            return
        }
        
        print("📋 Custodian to assign: \(custodianToAssign.text)")
        
        // Determine the date range that needs to be updated
        let updateRange = determineUpdateRange(originalDate: originalDate, newDate: newDate)
        
        if updateRange.isEmpty {
            print("📋 No dates need custody updates")
            completion()
            return
        }
        
        print("📋 Updating custody for \(updateRange.count) days: \(updateRange.map { dateFormatter.string(from: $0) })")
        print("📋 Setting custody to: \(custodianToAssign.text)")
        
        // Update custody for the affected range
        updateCustodyForDateRange(updateRange, toParentId: custodianToAssign.owner) {
            completion()
        }
    }
    
    private func determineUpdateRange(originalDate: Date, newDate: Date) -> [Date] {
        let calendar = Calendar.current
        
        // If moving handoff earlier (e.g., Thursday to Tuesday)
        // Update Tuesday and Wednesday to have the custody that Thursday had
        if newDate < originalDate {
            let endDate = calendar.date(byAdding: .day, value: -1, to: originalDate) ?? originalDate
            return generateDateRange(from: newDate, to: endDate)
        }
        // If moving handoff later (e.g., Tuesday to Thursday)
        // Update Wednesday up to (but NOT including) Thursday to have the custody that Tuesday had
        else if newDate > originalDate {
            let startDate = calendar.date(byAdding: .day, value: 1, to: originalDate) ?? originalDate
            let endDate = calendar.date(byAdding: .day, value: -1, to: newDate) ?? newDate
            
            // Only return range if there are actually days between original and new date
            if startDate <= endDate {
                return generateDateRange(from: startDate, to: endDate)
            }
        }
        
        return []
    }
    
    private func updateCustodyForDateRange(_ dates: [Date], toParentId: String, completion: @escaping () -> Void) {
        guard !dates.isEmpty else {
            completion()
            return
        }
        
        print("📋 Updating custody for \(dates.count) days to parent: \(toParentId)")
        
        // Track completion of all updates
        let dispatchGroup = DispatchGroup()
        
        // Update custody for each date in the range
        for (index, date) in dates.enumerated() {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)
            
            dispatchGroup.enter()
            
            // Add a small delay between requests to avoid overwhelming the API
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                self.updateCustodyRecordWithRetry(dateString: dateString, custodianId: toParentId, retryCount: 0) {
                    dispatchGroup.leave()
                }
            }
        }
        
        // Call completion when all updates finish
        dispatchGroup.notify(queue: .main) {
            print("✅ All custody updates completed for range")
            completion()
        }
    }
    
    private func generateDateRange(from startDate: Date, to endDate: Date) -> [Date] {
        var dates: [Date] = []
        let calendar = Calendar.current
        
        // Ensure we always go from earlier to later date
        let earlierDate = min(startDate, endDate)
        let laterDate = max(startDate, endDate)
        
        var currentDate = earlierDate
        
        while currentDate <= laterDate {
            dates.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        
        return dates
    }
    
    private func updateSingleDayCustody(date: Date, completion: @escaping () -> Void) {
        let handoffData = getHandoffDataForDate(date)
        
        guard let toParentId = handoffData.toParentId else {
            print("Error: Could not determine 'to parent' ID for handoff transition")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        print("📋 Updating single day custody for \(dateString) to parent: \(toParentId)")
        updateCustodyRecordWithRetry(dateString: dateString, custodianId: toParentId, retryCount: 0) {
            completion()
        }
    }
    
    private func updateCustodyRecordWithRetry(dateString: String, custodianId: String, retryCount: Int, completion: @escaping () -> Void) {
        APIService.shared.updateCustodyRecord(for: dateString, custodianId: custodianId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let custodyResponse):
                    print("✅ Updated custody for \(dateString): \(custodyResponse.content)")
                    self.updateLocalCustodyRecord(custodyResponse)
                    completion()
                    
                case .failure(let error):
                    print("❌ Failed to update custody for \(dateString): \(error.localizedDescription)")
                    
                    // Retry up to 2 times with exponential backoff
                    if retryCount < 2 {
                        let delay = pow(2.0, Double(retryCount)) // 1s, 2s delays
                        print("🔄 Retrying custody update for \(dateString) in \(delay)s (attempt \(retryCount + 2)/3)")
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self.updateCustodyRecordWithRetry(dateString: dateString, custodianId: custodianId, retryCount: retryCount + 1, completion: completion)
                        }
                    } else {
                        // Max retries reached - still call completion to avoid hanging
                        print("❌ Max retries reached for \(dateString) - giving up")
                        completion()
                    }
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
    
    private func detectHandoffCollisions(draggedDate: Date, dragPosition: CGPoint, cellWidth: CGFloat, cellHeight: CGFloat) {
        guard let draggedHandoff = viewModel.custodyRecords.first(where: { viewModel.isoDateFormatter.date(from: $0.event_date) == draggedDate && $0.handoff_day == true }) else {
            return
        }
        
        for date in getHandoffDays() {
            if date == draggedDate { continue } // Don't check against itself
            
            guard let otherHandoff = viewModel.custodyRecords.first(where: { viewModel.isoDateFormatter.date(from: $0.event_date) == date && $0.handoff_day == true }) else {
                continue
            }
            
            let otherPosition = getBubblePosition(for: date, cellWidth: cellWidth, cellHeight: cellHeight, size: .zero)
            
            // Check if drag position is close to another handoff bubble
            let distance = abs(dragPosition.x - otherPosition.x)
            
            // If dragging past another handoff bubble (within a threshold)
            if distance < (cellWidth / 4) { // Collision if within 1/4 of a cell
                // Check if we are passing over a handoff for the same custodian
                let draggedToParent = draggedHandoff.custodian_id
                let otherToParent = otherHandoff.custodian_id
                
                let isSameParentHandoff = (draggedToParent == viewModel.custodianOneId && otherToParent == viewModel.custodianOneId) ||
                (draggedToParent == viewModel.custodianTwoId && otherToParent == viewModel.custodianTwoId)
                
                if isSameParentHandoff {
                    // Mark this handoff to be deleted if it's for the same parent
                    if !passedOverHandoffs.contains(date) {
                        print("💥 Collision detected with handoff at \(formatDate(date)) for same parent. Marking for deletion.")
                        passedOverHandoffs.insert(date)
                    }
                }
            } else {
                // If we've moved away, remove from deletion set
                if passedOverHandoffs.contains(date) {
                    print("✅ Dragged away from \(formatDate(date)). Unmarking for deletion.")
                    passedOverHandoffs.remove(date)
                }
            }
        }
    }
    
    private func deletePassedOverHandoffs() {
        if passedOverHandoffs.isEmpty { return }
        
        let datesToDelete = passedOverHandoffs
        print("🗑️ Deleting \(datesToDelete.count) handoffs that were passed over: \(datesToDelete.map { formatDate($0) }.joined(separator: ", "))")
        
        for date in datesToDelete {
            // Get original handoff to determine which parent had custody
            guard let handoffInfo = viewModel.custodyRecords.first(where: { viewModel.isoDateFormatter.date(from: $0.event_date) == date && $0.handoff_day == true }) else {
                continue
            }
            let parentReceivingCustody = handoffInfo.custodian_id
            
            // The day of the deleted handoff should now belong to the other parent
            let newCustodianId = parentReceivingCustody == viewModel.custodianOneId ? viewModel.custodianTwoId : viewModel.custodianOneId
            
            // Update custody for the day of the deleted handoff
            if let newCustodianId = newCustodianId {
                viewModel.updateCustodyForSingleDay(date: date, newCustodianId: newCustodianId) {
                    print("✅ Custody updated for deleted handoff at \(self.formatDate(date))")
                }
            }
        }
        
        // Clear the set after processing
        passedOverHandoffs.removeAll()
    }
}

struct HandoffTimelineView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 
