import SwiftUI

struct FocusedDayView: View {
    let date: Date
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var selectedDate: Date?
    let themeManager: ThemeManager
    var namespace: Namespace.ID
    
    @State private var newEventText = ""
    @State private var isAddingEvent = false
    
    private var eventsForThisDate: [Event] {
        viewModel.eventsForDate(date)
    }
    
    private var custodyForThisDate: CustodyResponse? {
        viewModel.custodyForDate(date)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with date and close button
            HStack {
                Text(dateFormatter.string(from: date))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.currentTheme.textColor)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                        selectedDate = nil
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // Scrollable content area
            ScrollView {
                VStack(spacing: 12) {
                    // Custody section
                    if let custody = custodyForThisDate {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Custody")
                                .font(.headline)
                                .foregroundColor(themeManager.currentTheme.textColor)
                            
                            HStack {
                                Text(custody.custodian_name.capitalized)
                                    .font(.body)
                                    .foregroundColor(themeManager.currentTheme.custodyTextColor)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(themeManager.currentTheme.custodyBackgroundColor.opacity(0.2))
                                    )
                                
                                Spacer()
                                
                                Button(action: {
                                    viewModel.toggleCustodian(for: date)
                                }) {
                                    Text("Switch")
                                        .font(.caption)
                                        .foregroundColor(themeManager.currentTheme.custodyTextColor)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(themeManager.currentTheme.custodyTextColor, lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Divider()
                            .padding(.horizontal, 20)
                    }
                    
                    // Events section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Events")
                                .font(.headline)
                                .foregroundColor(themeManager.currentTheme.textColor)
                            
                            Spacer()
                            
                            Button(action: {
                                isAddingEvent = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(themeManager.currentTheme.accentColor)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Existing events list
                        ForEach(eventsForThisDate, id: \.id) { event in
                            HStack(alignment: .top, spacing: 12) {
                                Text(event.content)
                                    .font(.body)
                                    .foregroundColor(themeManager.currentTheme.eventTextColor)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Button(action: {
                                    viewModel.deleteEvent(event)
                                }) {
                                    Text("❌")
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(themeManager.currentTheme.eventBackgroundColor.opacity(0.1))
                            )
                            .padding(.horizontal, 20)
                        }
                        
                        // Add new event field
                        if isAddingEvent {
                            VStack(spacing: 8) {
                                TextField("Enter new event...", text: $newEventText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onSubmit {
                                        if !newEventText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            viewModel.addEvent(for: date, content: newEventText.trimmingCharacters(in: .whitespacesAndNewlines))
                                            newEventText = ""
                                            isAddingEvent = false
                                        }
                                    }
                                
                                HStack {
                                    Button("Cancel") {
                                        newEventText = ""
                                        isAddingEvent = false
                                    }
                                    .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                                    
                                    Spacer()
                                    
                                    Button("Add") {
                                        if !newEventText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            viewModel.addEvent(for: date, content: newEventText.trimmingCharacters(in: .whitespacesAndNewlines))
                                            newEventText = ""
                                            isAddingEvent = false
                                        }
                                    }
                                    .disabled(newEventText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    .foregroundColor(themeManager.currentTheme.accentColor)
                                }
                                .font(.caption)
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Empty state message
                        if eventsForThisDate.isEmpty && !isAddingEvent {
                            Text("No events scheduled")
                                .font(.body)
                                .foregroundColor(themeManager.currentTheme.textColor.opacity(0.5))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 20)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.currentTheme.modalBackgroundColor)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .matchedGeometryEffect(id: date, in: namespace, isSource: true)
        .onAppear {
            // Auto-focus on new event field if no events exist
            if eventsForThisDate.isEmpty && custodyForThisDate == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isAddingEvent = true
                }
            }
        }
    }
} 
