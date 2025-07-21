import SwiftUI

struct WeekView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingReminderModal = false
    @State private var selectedDate: Date = Date()
    
    var body: some View {
        ZStack {
            VStack {
                ForEach(getDaysForCurrentWeek(), id: \.self) { day in
                    ZStack {
                        // Weather effects background
                        if viewModel.showWeather, let weatherInfo = viewModel.weatherInfoForDate(day) {
                            WeatherFXView(weatherInfo: weatherInfo)
                                .cornerRadius(8)
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(day.formatted(.dateTime.weekday(.wide)))
                                        .font(.headline)
                                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                                    Spacer()
                                    // Temperature display
                                    if viewModel.showWeather, let weatherInfo = viewModel.weatherInfoForDate(day) {
                                        Text("\(Int(weatherInfo.temperature.rounded()))°")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                                            .padding(3)
                                            .background(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                                            .cornerRadius(4)
                                    }
                                }
                                Text(day.formatted(.dateTime.month().day()))
                                    .font(.caption)
                                    .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
                            }
                            .frame(width: 200, alignment: .leading)
                            
                            Spacer()
                            
                            // Reminder icon
                            Button(action: {
                                selectedDate = day
                                showingReminderModal = true
                            }) {
                                Image(systemName: "note.text")
                                    .font(.title2)
                                    .foregroundColor(viewModel.hasReminderForDate(day) ? .orange : .gray)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(viewModel.hasReminderForDate(day) ? Color.yellow.opacity(0.3) : Color.gray.opacity(0.1))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(viewModel.hasReminderForDate(day) ? Color.orange : Color.gray.opacity(0.5), lineWidth: 1)
                                    )
                            }
                            .padding(.trailing, 8)
                            
                            // Custody information and toggle button
                            let custodyInfo = viewModel.getCustodyInfo(for: day)
                            let ownerName = custodyInfo.text
                            let ownerId = custodyInfo.owner
                            
                            if !ownerName.isEmpty {
                                Button(action: {
                                    // Disable custody toggle when handoff timeline is active
                                    if !viewModel.showHandoffTimeline {
                                        viewModel.toggleCustodian(for: day)
                                    }
                                }) {
                                    Text(ownerName.capitalized)
                                        .font(.headline.bold())
                                        .foregroundColor(ownerId == viewModel.custodianOneId ? themeManager.currentTheme.parentOneTextColor : themeManager.currentTheme.parentTwoTextColor)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(ownerId == viewModel.custodianOneId ? themeManager.currentTheme.parentOneColorSwiftUI : themeManager.currentTheme.parentTwoColorSwiftUI)
                                        .cornerRadius(8)
                                }
                                .disabled((isDateInPast(day) && !UserDefaults.standard.bool(forKey: "allowPastCustodyEditing")) || viewModel.showHandoffTimeline)
                                .opacity(((isDateInPast(day) && !UserDefaults.standard.bool(forKey: "allowPastCustodyEditing")) || viewModel.showHandoffTimeline) ? 0.5 : 1.0)
                            }
                        }
                    }
                    .padding()
                    .frame(minHeight: 60)
                    .background(themeManager.currentTheme.mainBackgroundColorSwiftUI.opacity(viewModel.showHandoffTimeline ? 0.3 : 0.5))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .allowsHitTesting(!viewModel.showHandoffTimeline) // Disable interactions when handoff timeline is active
            
            // Vertical Handoff Timeline Overlay
            if viewModel.showHandoffTimeline {
                if viewModel.isHandoffDataReady {
                    WeekHandoffTimelineView(viewModel: viewModel, weekDays: getDaysForCurrentWeek())
                        .environmentObject(themeManager)
                        .allowsHitTesting(true) // Allow interactions with handoff bubbles
                        .zIndex(1000) // Ensure handoff timeline is above everything else
                } else {
                    // Loading state overlay
                    ZStack {
                        Rectangle()
                            .fill(.ultraThinMaterial.opacity(0.2))
                            .allowsHitTesting(false)
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.purple))
                                .scaleEffect(1.2)
                            
                            Text("Loading handoff data...")
                                .font(.headline)
                                .foregroundColor(.purple)
                        }
                    }
                    .zIndex(999)
                }
            }
        }
        .sheet(isPresented: $showingReminderModal) {
            ReminderModal(date: selectedDate)
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
    }
    
    private func getDaysForCurrentWeek() -> [Date] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: viewModel.currentDate) else {
            return []
        }
        
        var days: [Date] = []
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: weekInterval.start) {
                days.append(date)
            }
        }
        return days
    }
    
    private func isDateInPast(_ date: Date) -> Bool {
        return date < Calendar.current.startOfDay(for: Date())
    }
}

struct WeekHandoffTimelineView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let weekDays: [Date]
    
    @State private var showingHandoffModal = false
    @State private var selectedHandoffDate: Date?
    @State private var draggedBubbleDate: Date?
    @State private var dragOffset: CGSize = .zero
    @State private var showTimeOverlay = false
    @State private var overlayTime = ""
    @State private var overlayPosition: CGPoint = .zero
    @State private var passedOverHandoffs: Set<Date> = []
    
    // Available handoff times - same as in modal
    private let availableHandoffTimes = [
        (hour: 9, minute: 0, display: "9:00 AM"),
        (hour: 12, minute: 0, display: "12:00 PM"),
        (hour: 17, minute: 0, display: "5:00 PM")
    ]

    var body: some View {
        GeometryReader { geometry in
            let dayHeight = geometry.size.height / CGFloat(weekDays.count)
            
            ZStack {
                Canvas { context, size in
                    drawVerticalHandoffTimeline(context: context, size: size, dayHeight: dayHeight)
                }
                .background(Color.clear)
                .allowsHitTesting(false)
                
                // Draggable handoff bubbles positioned vertically
                ForEach(getHandoffDays(), id: \.self) { date in
                    let position = getBubblePosition(for: date, dayHeight: dayHeight, size: geometry.size)
                    
                    ZStack {
                        // Invisible larger touch target for better touch sensitivity
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 70, height: 70)
                        
                        // Visual bubble
                        Circle()
                            .fill(Color.clear)
                            .stroke(Color.purple, lineWidth: 2)
                            .frame(width: 20, height: 20)
                            .scaleEffect(draggedBubbleDate == date ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: draggedBubbleDate == date)
                    }
                    .position(x: position.x, y: position.y)
                    .offset(x: 0, y: draggedBubbleDate == date ? dragOffset.height : 0) // Y-axis movement for vertical
                    .zIndex(2000)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                // Only allow vertical dragging (Y-axis only)
                                let verticalTranslation = CGSize(width: 0, height: value.translation.height)
                                
                                if abs(value.translation.height) > 5 {
                                    draggedBubbleDate = date
                                    dragOffset = verticalTranslation
                                    
                                    // Check for collision with other handoff bubbles
                                    detectHandoffCollisions(
                                        draggedDate: date,
                                        dragPosition: CGPoint(
                                            x: position.x,
                                            y: position.y + verticalTranslation.height
                                        ),
                                        dayHeight: dayHeight
                                    )
                                    
                                    // Show time overlay
                                    showTimeOverlay = true
                                    overlayPosition = CGPoint(
                                        x: position.x + 80, // Position to the right of bubble
                                        y: position.y + verticalTranslation.height
                                    )
                                    
                                    // Calculate the new date and time based on vertical drag
                                    let newDateAndTime = calculateNewDateAndTime(
                                        originalDate: date,
                                        dragOffset: verticalTranslation,
                                        dayHeight: dayHeight,
                                        originalPosition: position
                                    )
                                    
                                    overlayTime = "\(formatDate(newDateAndTime.date)) \(newDateAndTime.time.display)"
                                }
                            }
                            .onEnded { value in
                                // If we didn't drag much vertically, treat as a tap
                                if abs(value.translation.height) <= 5 {
                                    selectedHandoffDate = date
                                    
                                    if !viewModel.isHandoffDataReady {
                                        viewModel.fetchHandoffsAndCustody()
                                    }
                                    
                                    DispatchQueue.main.async {
                                        showingHandoffModal = true
                                    }
                                } else {
                                    // Drag action - update handoff time (Y-axis only)
                                    let verticalTranslation = CGSize(width: 0, height: value.translation.height)
                                    updateHandoffTime(
                                        originalDate: date,
                                        dragOffset: verticalTranslation,
                                        dayHeight: dayHeight,
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
                        .zIndex(3000)
                        .animation(.easeInOut(duration: 0.1), value: overlayPosition)
                }
                
                if showingHandoffModal, let selectedDate = selectedHandoffDate {
                    HandoffTimeModal(
                        date: selectedDate,
                        viewModel: viewModel,
                        isPresented: $showingHandoffModal
                    )
                    .environmentObject(themeManager)
                    .zIndex(4000)
                    .transition(.opacity.animation(.easeInOut))
                }
            }
        }
    }
    
    private func drawVerticalHandoffTimeline(context: GraphicsContext, size: CGSize, dayHeight: CGFloat) {
        // Draw colored custody line segments for each day vertically
        for (dayIndex, day) in weekDays.enumerated() {
            // Position line to align with the right edge of the custodian button
            // Account for: date width (200) + reminder icon (32) + trailing padding (8) + some margin
            let x = size.width - 16 // Right justified with custodian button area
            let yStart = CGFloat(dayIndex) * dayHeight
            let yEnd = yStart + dayHeight
            
            // Draw custody background for handoff modal
            if showingHandoffModal {
                let custodyInfo = viewModel.getCustodyInfo(for: day)
                let custodyColor = getCustodyColor(for: custodyInfo.owner)
                
                context.fill(
                    Path(CGRect(x: 0, y: yStart, width: size.width, height: dayHeight)),
                    with: .color(custodyColor.opacity(0.05))
                )
            }
            
            // Get handoff times for this day
            if getHandoffDays().contains(day) {
                let handoffTime = viewModel.getHandoffTimeForDate(day)
                let timeProgress = calculateTimeProgress(hour: handoffTime.hour, minute: handoffTime.minute)
                let handoffY = yStart + (dayHeight * timeProgress)
                
                // Draw handoff line segment
                let custodyInfo = viewModel.getCustodyInfo(for: day)
                let custodyColor = getCustodyColor(for: custodyInfo.owner)
                
                // Draw line from start of day to handoff point
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: yStart))
                        path.addLine(to: CGPoint(x: x, y: handoffY))
                    },
                    with: .color(custodyColor),
                    lineWidth: 4
                )
                
                // Get next custody owner after handoff
                let nextCustodyColor = custodyColor == getCustodyColor(for: viewModel.custodianOneId ?? "") ? 
                    getCustodyColor(for: viewModel.custodianTwoId ?? "") : getCustodyColor(for: viewModel.custodianOneId ?? "")
                
                // Draw line from handoff point to end of day
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: handoffY))
                        path.addLine(to: CGPoint(x: x, y: yEnd))
                    },
                    with: .color(nextCustodyColor),
                    lineWidth: 4
                )
            } else {
                // No handoff, draw single custody line for whole day
                let custodyInfo = viewModel.getCustodyInfo(for: day)
                let custodyColor = getCustodyColor(for: custodyInfo.owner)
                
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: yStart))
                        path.addLine(to: CGPoint(x: x, y: yEnd))
                    },
                    with: .color(custodyColor),
                    lineWidth: 4
                )
            }
        }
    }
    
    private func getHandoffDays() -> [Date] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var handoffDays: Set<Date> = []
        let weekDaysSet = Set(weekDays)
        
        for custodyRecord in viewModel.custodyRecords {
            if custodyRecord.handoff_day == true {
                if let date = dateFormatter.date(from: custodyRecord.event_date) {
                    if weekDaysSet.contains(date) {
                        handoffDays.insert(date)
                    }
                }
            }
        }
        
        var previousOwner: String?
        
        for date in weekDays {
            let currentOwner = viewModel.getCustodyInfo(for: date).owner
            
            if let prev = previousOwner, prev != currentOwner {
                let dateString = dateFormatter.string(from: date)
                let hasHandoffRecord = viewModel.custodyRecords.contains { record in
                    record.event_date == dateString && record.handoff_day == true
                }
                
                if !hasHandoffRecord {
                    handoffDays.insert(date)
                }
            }
            
            previousOwner = currentOwner
        }
        
        return Array(handoffDays).sorted()
    }
    
    private func getBubblePosition(for date: Date, dayHeight: CGFloat, size: CGSize) -> CGPoint {
        guard let index = weekDays.firstIndex(of: date) else {
            return CGPoint(x: 0, y: 0)
        }
        
        // Get handoff time for this date
        let handoffTime = viewModel.getHandoffTimeForDate(date)
        let timeProgress = calculateTimeProgress(hour: handoffTime.hour, minute: handoffTime.minute)
        
        let x = size.width - 16 // Position aligned with custodian button right edge
        let y = CGFloat(index) * dayHeight + (dayHeight * timeProgress)
        
        return CGPoint(x: x, y: y)
    }
    
    private func calculateTimeProgress(hour: Int, minute: Int) -> CGFloat {
        let totalMinutes = hour * 60 + minute
        let dayStartMinutes = 0 // Start of day
        let dayEndMinutes = 24 * 60 // End of day
        return CGFloat(totalMinutes - dayStartMinutes) / CGFloat(dayEndMinutes - dayStartMinutes)
    }
    
    private func getCustodyColor(for custodyID: String) -> Color {
        if custodyID == viewModel.custodianOneId {
            return themeManager.currentTheme.parentOneColorSwiftUI
        } else if custodyID == viewModel.custodianTwoId {
            return themeManager.currentTheme.parentTwoColorSwiftUI
        } else {
            return .gray
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private func calculateNewDateAndTime(
        originalDate: Date,
        dragOffset: CGSize,
        dayHeight: CGFloat,
        originalPosition: CGPoint
    ) -> (date: Date, time: (hour: Int, minute: Int, display: String)) {
        
        // Calculate which day we're dragging to based on vertical position
        let newYPosition = originalPosition.y + dragOffset.height
        let dayIndex = max(0, min(weekDays.count - 1, Int(newYPosition / dayHeight)))
        let newDate = weekDays[dayIndex]
        
        // Calculate time within the day based on position within that day's height
        let dayStartY = CGFloat(dayIndex) * dayHeight
        let relativeY = newYPosition - dayStartY
        let timeProgress = max(0, min(1, relativeY / dayHeight))
        
        // Map to available handoff times
        let timeIndex = Int(round(timeProgress * 2)) // 0, 1, or 2 for our 3 time slots
        let clampedIndex = max(0, min(2, timeIndex))
        let selectedTime = availableHandoffTimes[clampedIndex]
        
        return (date: newDate, time: selectedTime)
    }
    
    private func detectHandoffCollisions(
        draggedDate: Date,
        dragPosition: CGPoint,
        dayHeight: CGFloat
    ) {
        let collisionRadius: CGFloat = 30
        
        for handoffDate in getHandoffDays() {
            if handoffDate != draggedDate {
                let bubblePos = getBubblePosition(for: handoffDate, dayHeight: dayHeight, size: CGSize(width: 400, height: 600))
                let distance = sqrt(pow(dragPosition.x - bubblePos.x, 2) + pow(dragPosition.y - bubblePos.y, 2))
                
                if distance < collisionRadius {
                    passedOverHandoffs.insert(handoffDate)
                }
            }
        }
    }
    
    private func updateHandoffTime(
        originalDate: Date,
        dragOffset: CGSize,
        dayHeight: CGFloat,
        originalPosition: CGPoint
    ) {
        let newDateAndTime = calculateNewDateAndTime(
            originalDate: originalDate,
            dragOffset: dragOffset,
            dayHeight: dayHeight,
            originalPosition: originalPosition
        )
        
        let newDate = newDateAndTime.date
        let newTime = newDateAndTime.time
        let timeString = String(format: "%02d:%02d", newTime.hour, newTime.minute)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let newDateString = dateFormatter.string(from: newDate)
        
        // Update custody record with handoff information using CalendarViewModel method
        updateCustodyWithHandoffInfo(originalDate, newDate, newDateString, timeString, newTime)
    }
    
    private func updateCustodyWithHandoffInfo(
        _ originalDate: Date,
        _ newDate: Date,
        _ newDateString: String,
        _ timeString: String,
        _ newTime: (hour: Int, minute: Int, display: String)
    ) {
        let currentCustodian = viewModel.getCustodyInfo(for: newDate).owner
        
        // Determine the receiving parent (opposite of current)
        let receivingParentId: String
        if currentCustodian == viewModel.custodianOneId {
            receivingParentId = viewModel.custodianTwoId ?? ""
        } else {
            receivingParentId = viewModel.custodianOneId ?? ""
        }
        
        // Get handoff location from original handoff
        let handoffLocation = viewModel.getHandoffTimeForDate(originalDate).location ?? "daycare"
        
        // Update custody record with handoff information
        APIService.shared.updateCustodyRecord(
            for: newDateString,
            custodianId: receivingParentId,
            handoffDay: true,
            handoffTime: timeString,
            handoffLocation: handoffLocation
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Handoff updated successfully for \(newDateString)")
                    self.viewModel.fetchHandoffsAndCustody()
                case .failure(let error):
                    print("❌ Failed to update handoff: \(error)")
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

struct WeekView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let themeManager = ThemeManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager, themeManager: themeManager)
        WeekView(viewModel: calendarViewModel)
            .environmentObject(themeManager)
    }
} 
