import SwiftUI

struct FocusedDayView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var focusedDate: Date?
    @State private var eventContent: String = ""
    @State private var schoolEvents: [Event] = []
    @State private var daycareEvents: [Event] = []
    
    var namespace: Namespace.ID

    var body: some View {
        if let date = focusedDate {
            Rectangle()
                .fill(.thinMaterial)  // Less blurry than ultraThinMaterial
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // Disable focused day closing when handoff timeline is active
                    if !viewModel.showHandoffTimeline {
                        saveChanges()
                        withAnimation(.interactiveSpring(response: 0.1, dampingFraction: 0.4, blendDuration: 0.8)) {
                            focusedDate = nil
                        }
                    }
                }
                .transition(.opacity)

            ZStack {
                if let weatherInfo = viewModel.weatherInfoForDate(date) {
                    WeatherFXView(weatherInfo: weatherInfo)
                        .transition(.opacity.animation(.easeInOut))
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Family Events Section (Editable)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(getFamilyEventsTitle(for: date))
                                .font(.headline)
                                .foregroundColor(themeManager.currentTheme.textColor.color)
                            
                            TextEditor(text: $eventContent)
                                .font(.body)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                                .background(themeManager.currentTheme.textColor.color.opacity(eventContent.isEmpty ? 0.1 : 0.3))
                                .foregroundColor(themeManager.currentTheme.textColor.color)
                                .cornerRadius(6)
                                .frame(minHeight: 120)
                        }
                        
                        // School Events Section (Non-editable)
                        if !schoolEvents.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "graduationcap.fill")
                                        .foregroundColor(.orange)
                                    Text(getSchoolEventsTitle())
                                        .font(.headline)
                                        .foregroundColor(themeManager.currentTheme.textColor.color)
                                }
                                
                                ForEach(schoolEvents) { event in
                                    Text(event.content)
                                        .font(.body)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .background(Color.orange.opacity(0.2))
                                        .foregroundColor(themeManager.currentTheme.textColor.color)
                                        .cornerRadius(6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        
                        // Daycare Events Section (Non-editable)
                        if !daycareEvents.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "building.2.fill")
                                        .foregroundColor(.purple)
                                    Text(getDaycareEventsTitle())
                                        .font(.headline)
                                        .foregroundColor(themeManager.currentTheme.textColor.color)
                                }
                                
                                ForEach(daycareEvents) { event in
                                    Text(event.content)
                                        .font(.body)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .background(Color.purple.opacity(0.2))
                                        .foregroundColor(themeManager.currentTheme.textColor.color)
                                        .cornerRadius(6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        
                        // Custody Information
                        let custodyInfo = viewModel.getCustodyInfo(for: date)
                        let ownerName = custodyInfo.text
                        let ownerId = custodyInfo.owner
                        if !ownerName.isEmpty {
                            Text(ownerName.capitalized)
                                .font(.headline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(ownerId == viewModel.custodianOneId ? themeManager.currentTheme.parentOneColor.color : themeManager.currentTheme.parentTwoColor.color)
                                .foregroundColor(themeManager.currentTheme.textColor.color)
                                .cornerRadius(10)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // Disable custody toggle when handoff timeline is active
                                    if !viewModel.showHandoffTimeline {
                                        viewModel.toggleCustodian(for: date)
                                    }
                                }
                                .disabled(isDateInPast(date) && !UserDefaults.standard.bool(forKey: "allowPastCustodyEditing"))
                                .opacity((isDateInPast(date) && !UserDefaults.standard.bool(forKey: "allowPastCustodyEditing")) ? 0.5 : 1.0)
                        }
                    }
                    .padding()
                }
            }
            .scrollTargetBehavior(CustomVerticalPagingBehavior())
            .matchedGeometryEffect(id: date, in: namespace)
            .frame(width: 320, height: 480)  // Slightly larger to accommodate sections
            .background(themeManager.currentTheme.mainBackgroundColorSwiftUI)
            .cornerRadius(20)
            .shadow(radius: 10)
            .onAppear(perform: loadEvents)
        }
    }

    private func isDateInPast(_ date: Date) -> Bool {
        return date < Calendar.current.startOfDay(for: Date())
    }
    
    private func getFamilyEventsTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        let dateString = formatter.string(from: date)
        
        // Add ordinal suffix
        let day = Calendar.current.component(.day, from: date)
        let ordinalSuffix = getOrdinalSuffix(for: day)
        
        let components = dateString.components(separatedBy: " ")
        if components.count >= 2 {
            return "\(components[0]) \(components[1])\(ordinalSuffix) Events"
        }
        return "\(dateString) Events"
    }
    
    private func getOrdinalSuffix(for day: Int) -> String {
        switch day {
        case 11...13:
            return "th"
        default:
            switch day % 10 {
            case 1: return "st"
            case 2: return "nd"
            case 3: return "rd"
            default: return "th"
            }
        }
    }
    
    private func getSchoolEventsTitle() -> String {
        // Get the first school provider name if available
        if let firstSchoolProvider = viewModel.schoolProviders.first {
            return firstSchoolProvider.name
        }
        
        // Fallback: Try to extract provider name from school events content
        // School events are often prefixed with [Provider Name]
        for event in schoolEvents {
            if event.content.hasPrefix("[") {
                if let endBracket = event.content.firstIndex(of: "]") {
                    let providerName = String(event.content[event.content.index(after: event.content.startIndex)..<endBracket])
                    return providerName
                }
            }
        }
        
        return "School Events"
    }
    
    private func getDaycareEventsTitle() -> String {
        // Get the first daycare provider name if available
        if let firstDaycareProvider = viewModel.daycareProviders.first {
            return firstDaycareProvider.name
        }
        
        return "Daycare Events"
    }

    private func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private func loadEvents() {
        guard let date = focusedDate else { return }
        let dailyEvents = viewModel.eventsForDate(date)
        
        // Separate events by type
        let familyEvents = dailyEvents.filter { event in
            // Only include family events (exclude school, daycare, and custody)
            event.source_type != "school" && 
            event.source_type != "daycare" && 
            event.position != 4 && 
            !event.content.isEmpty
        }
        
        self.schoolEvents = dailyEvents.filter { event in
            event.source_type == "school" && !event.content.isEmpty
        }
        
        self.daycareEvents = dailyEvents.filter { event in
            event.source_type == "daycare" && !event.content.isEmpty
        }
        
        // Combine family events into a single text with line breaks
        let eventTexts = familyEvents.map { $0.content }
        self.eventContent = eventTexts.joined(separator: "\n")
    }

    private func saveChanges() {
        guard let date = focusedDate else { return }
        
        let dailyEvents = viewModel.eventsForDate(date)
        let newContent = eventContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Get the first existing family event to update, or create a new one
        // Only consider family events (exclude school/daycare events and custody events)
        let existingEvent = dailyEvents.first { event in
            // Exclude school and daycare events using source_type
            if event.source_type == "school" || event.source_type == "daycare" {
                return false
            }
            // Exclude custody events
            if event.position == 4 {
                return false
            }
            return true
        }
        
        let group = DispatchGroup()
        
        if let existingEvent = existingEvent {
            if existingEvent.content != newContent {
                group.enter()
                if newContent.isEmpty {
                    APIService.shared.deleteEvent(eventId: existingEvent.id) { _ in group.leave() }
                } else {
                    let eventDetails: [String: Any] = [
                        "id": existingEvent.id,
                        "event_date": viewModel.isoDateString(from: date),
                        "content": newContent
                    ]
                    APIService.shared.saveEvent(eventDetails: eventDetails, existingEvent: existingEvent) { _ in group.leave() }
                }
            }
        } else if !newContent.isEmpty {
            group.enter()
            let eventDetails: [String: Any] = [
                "event_date": viewModel.isoDateString(from: date),
                "content": newContent
            ]
            APIService.shared.saveEvent(eventDetails: eventDetails, existingEvent: nil) { _ in group.leave() }
        }
        
        // Delete any additional family events that existed (since we're now using only one)
        // Only delete family events, not school/daycare events
        let additionalFamilyEvents = dailyEvents.dropFirst().filter { event in
            // Exclude school and daycare events using source_type
            if event.source_type == "school" || event.source_type == "daycare" {
                return false
            }
            // Exclude custody events
            if event.position == 4 {
                return false
            }
            return true
        }
        
        for event in additionalFamilyEvents {
            group.enter()
            APIService.shared.deleteEvent(eventId: event.id) { _ in group.leave() }
        }
        
        group.notify(queue: .main) {
            self.viewModel.fetchEvents()
        }
    }
} 
