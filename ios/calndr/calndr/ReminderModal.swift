import SwiftUI

struct ReminderModal: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    let date: Date
    @State private var reminderText: String = ""
    @State private var notificationEnabled: Bool = false
    @State private var notificationTime: Date = Date()
    @State private var isLoading: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @FocusState private var isTextEditorFocused: Bool
    
    private var existingReminder: Reminder? {
        viewModel.getReminderForDate(date)
    }
    
    private var isEditing: Bool {
        existingReminder != nil
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Reminder")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                    
                    Text(dateFormatter.string(from: date))
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                }
                .padding(.top)
                
                // Text Editor
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reminder Text")
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                    
                    TextEditor(text: $reminderText)
                        .frame(minHeight: 150)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(themeManager.currentTheme.textColor.color.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                        .font(.body)
                        .focused($isTextEditorFocused)
                }
                .padding(.horizontal)
                
                // Notification Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Push Notification")
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                    
                    Toggle("Send notification", isOn: $notificationEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: Color.blue))
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                    
                    if notificationEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notification Time")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.8))
                            
                            DatePicker("", selection: $notificationTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(WheelDatePickerStyle())
                                .labelsHidden()
                                .frame(maxHeight: 120)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    // Save Button
                    Button(action: saveReminder) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isEditing ? "Update Reminder" : "Create Reminder")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(reminderText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    .opacity(reminderText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                    
                    // Delete Button (only show if editing)
                    if isEditing {
                        Button(action: { showingDeleteAlert = true }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Reminder")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading)
                        .opacity(isLoading ? 0.6 : 1.0)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(themeManager.currentTheme.mainBackgroundColorSwiftUI)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.textColor.color)
                    .disabled(isLoading)
                }
                
                // Add Done button when keyboard is active
                if isTextEditorFocused {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            isTextEditorFocused = false
                        }
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                        .disabled(isLoading)
                    }
                }
            }
            .background(
                // Invisible background to capture taps for keyboard dismissal
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Dismiss keyboard when tapping outside text editor
                        if isTextEditorFocused {
                            isTextEditorFocused = false
                        }
                    }
            )
        }
        .alert("Delete Reminder", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteReminder()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this reminder? This action cannot be undone.")
        }
        .onAppear {
            loadExistingReminder()
        }
    }
    
    private func loadExistingReminder() {
        if let reminder = existingReminder {
            reminderText = reminder.text
            notificationEnabled = reminder.notificationEnabled
            
            // Parse notification time if available
            if let timeString = reminder.notificationTime {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                if let time = formatter.date(from: timeString) {
                    notificationTime = time
                }
            }
        }
    }
    
    private func saveReminder() {
        let text = reminderText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        isLoading = true
        
        // Format notification time if enabled
        var notificationTimeString: String? = nil
        if notificationEnabled {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            notificationTimeString = formatter.string(from: notificationTime)
        }
        
        if let existingReminder = existingReminder {
            // Update existing reminder
            viewModel.updateReminder(existingReminder.id, text: text, notificationEnabled: notificationEnabled, notificationTime: notificationTimeString) { [self] success in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if success {
                        self.dismiss()
                    }
                    // TODO: Show error message if not successful
                }
            }
        } else {
            // Create new reminder
            viewModel.createReminder(date: date, text: text, notificationEnabled: notificationEnabled, notificationTime: notificationTimeString) { [self] success in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if success {
                        self.dismiss()
                    }
                    // TODO: Show error message if not successful
                }
            }
        }
    }
    
    private func deleteReminder() {
        guard let reminder = existingReminder else { return }
        
        isLoading = true
        
        viewModel.deleteReminder(reminder.id) { [self] success in
            DispatchQueue.main.async {
                self.isLoading = false
                if success {
                    self.dismiss()
                }
                // TODO: Show error message if not successful
            }
        }
    }
}

// MARK: - Preview
struct ReminderModal_Previews: PreviewProvider {
    static var previews: some View {
        ReminderModal(date: Date())
            .environmentObject(CalendarViewModel(authManager: AuthenticationManager(), themeManager: ThemeManager()))
            .environmentObject(ThemeManager())
    }
} 