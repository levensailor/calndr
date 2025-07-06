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
            // Check if custodian data is loaded
            if !viewModel.custodiansLoaded {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading parent information...")
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(themeManager.currentTheme.mainBackgroundColor)
                .onAppear {
                    // Trigger custodian fetch if not loaded
                    print("Custodians not loaded in timeline, triggering fetch...")
                    viewModel.fetchCustodianNames()
                }
            } else {
                // Existing timeline content
                timelineContent
            }
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
                                    // Tap action - show modal
                                    selectedHandoffDate = date
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
        
        // Calculate which grid cell this position corresponds to
        let newCol = max(0, min(gridColumns - 1, Int(newX / cellWidth)))
        let newRow = max(0, Int(newY / cellHeight))
        
        // Calculate the new calendar index allowing movement across rows
        let newIndex = newRow * gridColumns + newCol
        
        // Ensure we're within bounds of the calendar days
        let clampedIndex = max(0, min(calendarDays.count - 1, newIndex))
        let newDate = calendarDays[clampedIndex]
        
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
        
        print("🎯 Drag calculation: newX=\(Int(newX)), newY=\(Int(newY)), col=\(newCol), row=\(newRow), index=\(clampedIndex)")
        print("📅 Target date: \(formatDate(newDate)), time: \(selectedTime.display)")
        
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
        // Get days that have ACTUAL handoff records first
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var handoffDays: [Date] = []
        
        // First, add all dates that have actual handoff records
        // Only include records where the custody actually changes (from != to).
        for handoffRecord in viewModel.handoffTimes {
            // If both parent IDs are present and identical, this is not a real handoff.
            if let fromId = handoffRecord.from_parent_id,
               let toId = handoffRecord.to_parent_id,
               fromId == toId {
                continue // Skip invalid handoff record
            }

            if let date = dateFormatter.date(from: handoffRecord.date) {
                handoffDays.append(date)
            }
        }
        
        // Then, add days where custody changes (virtual handoffs) only if no handoff record exists
        var previousOwner: String?
        
        for date in calendarDays {
            let currentOwner = viewModel.getCustodyInfo(for: date).owner
            
            if let prev = previousOwner, prev != currentOwner {
                // Only add if no actual handoff record exists for this date
                let dateString = dateFormatter.string(from: date)
                // Check for a *valid* handoff record on this date (parents must differ)
                let hasValidHandoffRecord = viewModel.handoffTimes.contains { record in
                    guard record.date == dateString else { return false }
                    if let fromId = record.from_parent_id,
                       let toId = record.to_parent_id,
                       fromId == toId {
                        return false // Same parent – not a valid handoff
                    }
                    return true
                }
                
                if !hasValidHandoffRecord && !handoffDays.contains(date) {
                    handoffDays.append(date)
                }
            }
            
            previousOwner = currentOwner
        }
        
        return handoffDays.sorted()
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
        
        // Check if we have an actual handoff record for the original date
        if let draggedHandoff = viewModel.handoffTimes.first(where: { $0.date == originalDateString }) {
            // We have an existing handoff record - update it
            updateExistingHandoff(draggedHandoff, originalDate, newDate, newDateString, timeString, newTime)
        } else {
            // No existing handoff record - this is a "virtual" bubble based on custody change
            // Create a new handoff record instead
            print("📝 No existing handoff record for \(originalDateString) - creating new handoff at \(newDateString)")
            createNewHandoffFromDrag(originalDate, newDate, newDateString, timeString, newTime)
        }
        
    }
    
    private func updateExistingHandoff(
        _ draggedHandoff: HandoffTimeResponse,
        _ originalDate: Date,
        _ newDate: Date,
        _ newDateString: String,
        _ timeString: String,
        _ newTime: (hour: Int, minute: Int, display: String)
    ) {
        // Check if there's already a handoff at the target date
        let existingTargetHandoff = viewModel.handoffTimes.first(where: { $0.date == newDateString })
        
        if let targetHandoff = existingTargetHandoff {
            // Target date already has a handoff - try to delete it first, then update the dragged one
            print("🔄 Target date \(newDateString) already has handoff - attempting to replace with dragged handoff")
            
            APIService.shared.deleteHandoffTime(handoffId: String(targetHandoff.id)) { deleteResult in
                DispatchQueue.main.async {
                    switch deleteResult {
                    case .success:
                        print("✅ Deleted existing handoff at target date \(newDateString)")
                        
                    case .failure(let deleteError):
                        print("⚠️ Failed to delete existing handoff at target (may already be gone): \(deleteError.localizedDescription)")
                        // Remove from local data anyway in case it was already deleted on backend
                        self.viewModel.handoffTimes.removeAll { $0.id == targetHandoff.id }
                    }
                    
                    // Continue with the update regardless of deletion success
                    print("📍 Proceeding with handoff update regardless of deletion result")
                    self.performHandoffUpdate(draggedHandoff, newDateString, timeString, newTime, originalDate, newDate)
                }
            }
        } else {
            // No existing handoff at target date - simply update the dragged one
            performHandoffUpdate(draggedHandoff, newDateString, timeString, newTime, originalDate, newDate)
        }
    }
    
    private func createNewHandoffFromDrag(
        _ originalDate: Date,
        _ newDate: Date,
        _ newDateString: String,
        _ timeString: String,
        _ newTime: (hour: Int, minute: Int, display: String)
    ) {
        // Check if target date already has a handoff - delete it first if so
        let existingTargetHandoff = viewModel.handoffTimes.first(where: { $0.date == newDateString })
        
        if let targetHandoff = existingTargetHandoff {
            print("🔄 Target date \(newDateString) already has handoff - deleting before creating new one")
            
            APIService.shared.deleteHandoffTime(handoffId: String(targetHandoff.id)) { deleteResult in
                DispatchQueue.main.async {
                    switch deleteResult {
                    case .success:
                        print("✅ Deleted existing handoff at target date \(newDateString)")
                    case .failure(let deleteError):
                        print("⚠️ Failed to delete existing handoff at target: \(deleteError.localizedDescription)")
                        // Remove from local data anyway
                        self.viewModel.handoffTimes.removeAll { $0.id == targetHandoff.id }
                    }
                    
                    // Proceed with creating new handoff
                    self.createNewHandoffRecord(newDate, newDateString, timeString, newTime, originalDate)
                }
            }
        } else {
            // No existing handoff at target - create new one directly
            createNewHandoffRecord(newDate, newDateString, timeString, newTime, originalDate)
        }
    }
    
    private func createNewHandoffRecord(
        _ newDate: Date,
        _ newDateString: String,
        _ timeString: String,
        _ newTime: (hour: Int, minute: Int, display: String),
        _ originalDate: Date?
    ) {
        // Get handoff data for the new date
        let newHandoffData = getHandoffDataForDate(newDate)
        
        // Create new handoff record
        APIService.shared.saveHandoffTime(
            date: newDateString,
            time: timeString,
            location: newHandoffData.location,
            fromParentId: newHandoffData.fromParentId,
            toParentId: newHandoffData.toParentId
        ) { result in
            DispatchQueue.main.async {
                self.handleSaveResult(result, newDate: newDate, newTime: newTime, originalDate: originalDate)
            }
        }
    }
    
    private func performHandoffUpdate(
        _ draggedHandoff: HandoffTimeResponse,
        _ newDateString: String,
        _ timeString: String,
        _ newTime: (hour: Int, minute: Int, display: String),
        _ originalDate: Date,
        _ newDate: Date
    ) {
        // Get handoff data for the new date to determine parent IDs
        let newHandoffData = getHandoffDataForDate(newDate)
        
        // Update the dragged handoff record with new date/time/location
        APIService.shared.updateHandoffTime(
            handoffId: draggedHandoff.id,
            date: newDateString,
            time: timeString,
            location: draggedHandoff.location ?? "daycare",
            fromParentId: newHandoffData.fromParentId,
            toParentId: newHandoffData.toParentId
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedHandoff):
                    print("✅ Updated handoff to \(newDateString) at \(newTime.display)")
                    
                    // Update custody for the move if different date
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    let originalDateString = dateFormatter.string(from: originalDate)
                    
                    if originalDateString != newDateString {
                        // Update custody first, then refresh UI when complete
                        self.updateCustodyForHandoffMove(originalDate: originalDate, newDate: newDate) {
                            // Refresh handoff times after custody update completes
                            DispatchQueue.main.async {
                                self.viewModel.fetchHandoffTimes()
                            }
                        }
                    } else {
                        // Same day move - refresh immediately
                        self.viewModel.fetchHandoffTimes()
                    }
                    
                case .failure(let error):
                    print("❌ Failed to update handoff time: \(error.localizedDescription)")
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
                self.updateCustodyForHandoffMove(originalDate: originalDate, newDate: newDate) {
                    // Refresh handoff times after custody update completes
                    DispatchQueue.main.async {
                        self.viewModel.fetchHandoffTimes()
                    }
                }
            } else {
                self.updateCustodyBasedOnHandoffTimeChange(for: newDate)
                // Refresh handoff times to update the view
                self.viewModel.fetchHandoffTimes()
            }
            
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
    
    private func updateCustodyForHandoffMove(originalDate: Date, newDate: Date, completion: @escaping () -> Void = {}) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let originalDateString = dateFormatter.string(from: originalDate)
        let newDateString = dateFormatter.string(from: newDate)
        
        print("Moving handoff from \(originalDateString) to \(newDateString)")
        
        // Calculate all dates in the range from original to new date
        let dateRange = generateDateRange(from: originalDate, to: newDate)
        
        if dateRange.count == 1 {
            // Same day move - just update that day
            updateSingleDayCustody(date: newDate) {
                completion()
            }
        } else {
            // Multi-day move - update custody for entire range
            print("📅 Updating custody for \(dateRange.count) days in range")
            updateCustodyForDateRange(dateRange) {
                completion()
            }
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
    
    private func updateCustodyForDateRange(_ dates: [Date], completion: @escaping () -> Void) {
        // Get the handoff data to determine who gets custody after the handoff
        let handoffData = getHandoffDataForDate(dates.last ?? dates[0])
        
        guard let toParentId = handoffData.toParentId else {
            print("Error: Could not determine 'to parent' ID for handoff transition")
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
        let bubbleRadius: CGFloat = 25.0 // Collision radius
        
        // Get all handoff days except the one being dragged
        let otherHandoffDays = getHandoffDays().filter { $0 != draggedDate }
        
        for date in otherHandoffDays {
            // Calculate the position of this handoff bubble
            let bubblePosition = getBubblePosition(for: date, cellWidth: cellWidth, cellHeight: cellHeight, size: CGSize(width: cellWidth * CGFloat(gridColumns), height: cellHeight * CGFloat(calendarDays.count / gridColumns)))
            
            // Check if the dragged bubble is within collision distance
            let distance = sqrt(pow(bubblePosition.x - dragPosition.x, 2) + pow(bubblePosition.y - dragPosition.y, 2))
            
            if distance < bubbleRadius {
                passedOverHandoffs.insert(date)
                print("Collision detected: dragged bubble passed over handoff at \(formatDate(date))")
            }
        }
    }
    
    private func deletePassedOverHandoffs() {
        for date in passedOverHandoffs {
            print("Deleting handoff at \(formatDate(date)) due to collision")
            
            // Convert the date to string format for comparison
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)
            
            // Find the handoff record for this date to get the ID
            if let handoffRecord = viewModel.handoffTimes.first(where: { $0.date == dateString }) {
                let handoffId = String(handoffRecord.id)
                
                // Call API to delete the handoff record
                APIService.shared.deleteHandoffTime(handoffId: handoffId) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            // Remove from viewModel data
                            self.viewModel.handoffTimes.removeAll { $0.id == handoffRecord.id }
                            print("Successfully deleted handoff at \(self.formatDate(date))")
                        case .failure(let error):
                            print("Failed to delete handoff at \(self.formatDate(date)): \(error)")
                        }
                    }
                }
            } else {
                print("No handoff record found for date \(formatDate(date))")
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