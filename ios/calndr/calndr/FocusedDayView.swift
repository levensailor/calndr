import SwiftUI

struct FocusedDayView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var focusedDate: Date?
    @State private var eventContents: [Int: String] = [:]
    
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
                    
                    ForEach(0..<4) { index in
                        TextField("Event...", text: Binding(
                            get: { self.eventContents[index, default: ""] },
                            set: { self.eventContents[index] = $0 }
                        ))
                        .font(.body)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(themeManager.currentTheme.textColor.opacity(eventContents[index, default: ""].isEmpty ? 0.1 : 0.3))
                        .foregroundColor(themeManager.currentTheme.textColor)
                        .cornerRadius(6)
                    }
                    
                    Spacer()
                    
                    let custodyInfo = viewModel.getCustodyInfo(for: date)
                    let ownerName = custodyInfo.text
                    let ownerId = custodyInfo.owner
                    if !ownerName.isEmpty {
                        Text(ownerName.capitalized)
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(ownerId == viewModel.custodianOne?.id ? Color(hex: "#FFC2D9") : Color(hex: "#96CBFC"))
                            .foregroundColor(themeManager.currentTheme.textColor)
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
            .background(themeManager.currentTheme.mainBackgroundColor)
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
        for event in dailyEvents {
            if event.position >= 0 && event.position < 4 {
                self.eventContents[event.position] = event.content
            }
        }
    }

    private func saveChanges() {
        guard let date = focusedDate else { return }
        
        let dailyEvents = viewModel.eventsForDate(date)
        let group = DispatchGroup()
        
        for position in 0..<4 {
            let existingEvent = dailyEvents.first { $0.position == position }
            let newContent = eventContents[position, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)

            if let existingEvent = existingEvent {
                if existingEvent.content != newContent {
                    group.enter()
                    if newContent.isEmpty {
                        APIService.shared.deleteEvent(eventId: existingEvent.id) { _ in group.leave() }
                    } else {
                        let eventDetails: [String: Any] = [
                            "id": existingEvent.id,
                            "event_date": viewModel.isoDateString(from: date),
                            "content": newContent,
                            "position": position
                        ]
                        APIService.shared.saveEvent(eventDetails: eventDetails, existingEvent: existingEvent) { _ in group.leave() }
                    }
                }
            } else if !newContent.isEmpty {
                group.enter()
                let eventDetails: [String: Any] = [
                    "event_date": viewModel.isoDateString(from: date),
                    "content": newContent,
                    "position": position
                ]
                APIService.shared.saveEvent(eventDetails: eventDetails, existingEvent: nil) { _ in group.leave() }
            }
        }
        
        group.notify(queue: .main) {
            self.viewModel.fetchEvents()
        }
    }
} 
