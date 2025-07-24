import SwiftUI

struct FocusedDayView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var focusedDate: Date?
    @State private var eventContent: String = ""
    
    var namespace: Namespace.ID

    var body: some View {
        if let date = focusedDate {
            Rectangle()
                .fill(.ultraThinMaterial)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // Disable focused day closing when handoff timeline is active
                    if !viewModel.showHandoffTimeline {
                        saveChanges()
                        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.8)) {
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

                VStack(alignment: .leading, spacing: 8) {
                    Text(dayString(from: date))
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing)
                    
                    // Single large text field that spans the height
                    TextEditor(text: $eventContent)
                        .font(.body)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(themeManager.currentTheme.textColor.color.opacity(eventContent.isEmpty ? 0.1 : 0.3))
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                        .cornerRadius(6)
                        .frame(minHeight: 200) // Give it substantial height
                    
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
            }
            .padding()
            .matchedGeometryEffect(id: date, in: namespace)
            .frame(width: 300, height: 400)
            .background(themeManager.currentTheme.mainBackgroundColorSwiftUI)
            .cornerRadius(20)
            .shadow(radius: 10)
            .onAppear(perform: loadEvents)
        }
    }

    private func isDateInPast(_ date: Date) -> Bool {
        return date < Calendar.current.startOfDay(for: Date())
    }

    private func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private func loadEvents() {
        guard let date = focusedDate else { return }
        let dailyEvents = viewModel.eventsForDate(date)
        
        // Filter to only show family events (non-school, non-daycare) since these are the only editable events
        let familyEvents = dailyEvents.filter { event in
            // Exclude school and daycare events using source_type
            if event.source_type == "school" || event.source_type == "daycare" {
                return false
            }
            // Exclude custody events
            if event.position == 4 {
                return false
            }
            // Include only non-empty family events
            return !event.content.isEmpty
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
