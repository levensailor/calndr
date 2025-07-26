import SwiftUI

// Generic infinite scroll view that can work with any time period
struct InfiniteScrollView<Content: View>: View {
    let content: (Int) -> Content // Content closure that takes an offset index
    let onOffsetChanged: (Int) -> Void // Callback when offset changes
    let preloadCount: Int // Number of items to preload on each side
    
    @State private var currentOffset: Int = 0
    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging = false
    
    init(
        preloadCount: Int = 3,
        onOffsetChanged: @escaping (Int) -> Void = { _ in },
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self.preloadCount = preloadCount
        self.onOffsetChanged = onOffsetChanged
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            
            HStack(spacing: 0) {
                // Generate views for current visible range plus preload buffer
                ForEach(visibleRange, id: \.self) { index in
                    content(index)
                        .frame(width: width)
                        .id("scroll_item_\(index)")
                }
            }
            .offset(x: -CGFloat(currentOffset) * width + dragOffset)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentOffset)
            .gesture(
                DragGesture()
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let threshold = width * 0.3 // 30% of screen width
                        let velocity = abs(value.velocity.width)
                        
                        if abs(value.translation.width) > threshold || velocity > 500 {
                            if value.translation.width > 0 {
                                // Swipe right - go to previous
                                moveToOffset(currentOffset - 1)
                            } else {
                                // Swipe left - go to next
                                moveToOffset(currentOffset + 1)
                            }
                        } else {
                            // Snap back to current position
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .clipped()
    }
    
    private var visibleRange: Range<Int> {
        let start = currentOffset - preloadCount
        let end = currentOffset + preloadCount + 1
        return start..<end
    }
    
    private func moveToOffset(_ newOffset: Int) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentOffset = newOffset
            dragOffset = 0
        }
        
        // Notify parent of offset change
        onOffsetChanged(newOffset)
    }
    
    // Public method to programmatically change offset
    func setOffset(_ offset: Int, animated: Bool = true) {
        if animated {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                currentOffset = offset
                dragOffset = 0
            }
        } else {
            currentOffset = offset
            dragOffset = 0
        }
        onOffsetChanged(offset)
    }
}

// Specialized infinite scroll view for calendar periods
struct CalendarInfiniteScrollView<Content: View>: View {
    @ObservedObject var viewModel: CalendarViewModel
    let viewType: CalendarViewType
    let content: (Date) -> Content
    
    @State private var currentIndex: Int = 0
    @State private var baseDate: Date = Date()
    
    init(
        viewModel: CalendarViewModel,
        viewType: CalendarViewType,
        @ViewBuilder content: @escaping (Date) -> Content
    ) {
        self.viewModel = viewModel
        self.viewType = viewType
        self.content = content
        
        // Initialize baseDate to align with current date
        let calendar = Calendar.current
        switch viewType {
        case .day:
            _baseDate = State(initialValue: calendar.startOfDay(for: Date()))
        case .week:
            if let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start {
                _baseDate = State(initialValue: weekStart)
            } else {
                _baseDate = State(initialValue: Date())
            }
        case .threeDay:
            // For 3-day view, align to yesterday so today is in the middle
            _baseDate = State(initialValue: calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        default:
            _baseDate = State(initialValue: Date())
        }
    }
    
    var body: some View {
        InfiniteScrollView(
            preloadCount: 2,
            onOffsetChanged: { offset in
                currentIndex = offset
                updateCurrentDate()
                preloadDataForOffset(offset)
            }
        ) { offset in
            let date = dateForOffset(offset)
            content(date)
                .onAppear {
                    // Preload data when view appears
                    preloadDataForDate(date)
                }
        }
        .onAppear {
            // Sync with current viewModel date
            syncWithCurrentDate()
        }
        .onChange(of: viewModel.currentDate) { oldValue, newValue in
            syncWithCurrentDate()
        }
    }
    
    private func dateForOffset(_ offset: Int) -> Date {
        let calendar = Calendar.current
        
        switch viewType {
        case .day:
            return calendar.date(byAdding: .day, value: offset, to: baseDate) ?? baseDate
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: offset, to: baseDate) ?? baseDate
        case .threeDay:
            return calendar.date(byAdding: .day, value: offset * 3, to: baseDate) ?? baseDate
        default:
            return baseDate
        }
    }
    
    private func syncWithCurrentDate() {
        let targetDate = viewModel.currentDate
        let calendar = Calendar.current
        
        let newIndex: Int
        switch viewType {
        case .day:
            newIndex = calendar.dateComponents([.day], from: baseDate, to: targetDate).day ?? 0
        case .week:
            newIndex = calendar.dateComponents([.weekOfYear], from: baseDate, to: targetDate).weekOfYear ?? 0
        case .threeDay:
            let dayDiff = calendar.dateComponents([.day], from: baseDate, to: targetDate).day ?? 0
            newIndex = dayDiff / 3
        default:
            newIndex = 0
        }
        
        if newIndex != currentIndex {
            currentIndex = newIndex
        }
    }
    
    private func updateCurrentDate() {
        let newDate = dateForOffset(currentIndex)
        
        // Only update if it's different to avoid unnecessary updates
        if !Calendar.current.isDate(newDate, inSamePeriod: viewModel.currentDate, granularity: granularityForViewType()) {
            DispatchQueue.main.async {
                viewModel.currentDate = newDate
            }
        }
    }
    
    private func granularityForViewType() -> Calendar.Component {
        switch viewType {
        case .day:
            return .day
        case .week:
            return .weekOfYear
        case .threeDay:
            return .day
        default:
            return .day
        }
    }
    
    private func preloadDataForOffset(_ offset: Int) {
        // Preload data for current and adjacent periods
        let preloadRange = -1...1
        for deltaOffset in preloadRange {
            let date = dateForOffset(offset + deltaOffset)
            preloadDataForDate(date)
        }
    }
    
    private func preloadDataForDate(_ date: Date) {
        let calendar = Calendar.current
        
        switch viewType {
        case .day:
            // Preload events and custody for the day
            Task {
                await viewModel.preloadDataForDate(date)
            }
        case .week:
            // Preload data for the entire week
            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) {
                Task {
                    await viewModel.preloadDataForDateRange(weekInterval.start, to: weekInterval.end)
                }
            }
        case .threeDay:
            // Preload data for 3 days starting from date
            let endDate = calendar.date(byAdding: .day, value: 2, to: date) ?? date
            Task {
                await viewModel.preloadDataForDateRange(date, to: endDate)
            }
        default:
            break
        }
    }
}

extension Calendar {
    func isDate(_ date1: Date, inSamePeriod date2: Date, granularity: Calendar.Component) -> Bool {
        switch granularity {
        case .day:
            return isDate(date1, inSameDayAs: date2)
        case .weekOfYear:
            return isDate(date1, equalTo: date2, toGranularity: .weekOfYear)
        case .month:
            return isDate(date1, equalTo: date2, toGranularity: .month)
        case .year:
            return isDate(date1, equalTo: date2, toGranularity: .year)
        default:
            return false
        }
    }
}

// Specialized infinite scroll view for monthly calendar grid
struct MonthInfiniteScrollView<Content: View>: View {
    @ObservedObject var viewModel: CalendarViewModel
    let content: (Date) -> Content // Content closure that takes a month start date
    
    @State private var currentIndex: Int = 0
    @State private var baseDate: Date = Date()
    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging = false
    
    init(
        viewModel: CalendarViewModel,
        @ViewBuilder content: @escaping (Date) -> Content
    ) {
        self.viewModel = viewModel
        self.content = content
        
        // Initialize baseDate to first day of current month
        let calendar = Calendar.current
        _baseDate = State(initialValue: calendar.dateInterval(of: .month, for: Date())?.start ?? Date())
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            
            HStack(spacing: 0) {
                // Generate views for current visible range plus preload buffer
                ForEach(visibleRange, id: \.self) { index in
                    content(monthDateForOffset(index))
                        .frame(width: width)
                        .id("month_scroll_item_\(index)")
                }
            }
            .offset(x: -CGFloat(currentIndex) * width + dragOffset)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentIndex)
            .gesture(
                DragGesture()
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let threshold = width * 0.3 // 30% of screen width
                        let velocity = abs(value.velocity.width)
                        
                        if abs(value.translation.width) > threshold || velocity > 500 {
                            if value.translation.width > 0 {
                                // Swipe right - go to previous month
                                moveToOffset(currentIndex - 1)
                            } else {
                                // Swipe left - go to next month
                                moveToOffset(currentIndex + 1)
                            }
                        } else {
                            // Snap back to current position
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .clipped()
        .onAppear {
            syncWithCurrentDate()
        }
        .onChange(of: viewModel.currentDate) { oldValue, newValue in
            syncWithCurrentDate()
        }
    }
    
    private var visibleRange: Range<Int> {
        let preloadCount = 2
        let start = currentIndex - preloadCount
        let end = currentIndex + preloadCount + 1
        return start..<end
    }
    
    private func monthDateForOffset(_ offset: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .month, value: offset, to: baseDate) ?? baseDate
    }
    
    private func syncWithCurrentDate() {
        let targetDate = viewModel.currentDate
        let calendar = Calendar.current
        
        let newIndex = calendar.dateComponents([.month], from: baseDate, to: targetDate).month ?? 0
        
        if newIndex != currentIndex {
            currentIndex = newIndex
        }
    }
    
    private func moveToOffset(_ newOffset: Int) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentIndex = newOffset
            dragOffset = 0
        }
        
        // Update viewModel's current date
        let newDate = monthDateForOffset(newOffset)
        DispatchQueue.main.async {
            viewModel.currentDate = newDate
        }
        
        // Preload data for the new month
        preloadDataForMonth(newDate)
    }
    
    private func preloadDataForMonth(_ monthDate: Date) {
        let calendar = Calendar.current
        let _ = calendar.component(.year, from: monthDate)
        let _ = calendar.component(.month, from: monthDate)
        
        // Preload data in the background
        Task {
            await viewModel.preloadDataForDate(monthDate)
            
            // Also preload the entire month range
            if let monthInterval = calendar.dateInterval(of: .month, for: monthDate) {
                await viewModel.preloadDataForDateRange(monthInterval.start, to: monthInterval.end)
            }
        }
    }
} 