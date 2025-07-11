import SwiftUI

struct ReminderModal: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    let date: Date
    @State private var reminderText: String = ""
    @State private var isLoading: Bool = false
    @State private var showingDeleteAlert: Bool = false
    
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
                        .foregroundColor(themeManager.currentTheme.textColor)
                    
                    Text(dateFormatter.string(from: date))
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                }
                .padding(.top)
                
                // Text Editor
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reminder Text")
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor)
                    
                    TextEditor(text: $reminderText)
                        .frame(minHeight: 150)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(themeManager.currentTheme.otherMonthBackgroundColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(themeManager.currentTheme.textColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .foregroundColor(themeManager.currentTheme.textColor)
                        .font(.body)
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
            .background(themeManager.currentTheme.mainBackgroundColor)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.textColor)
                    .disabled(isLoading)
                }
            }
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
        }
    }
    
    private func saveReminder() {
        let text = reminderText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        isLoading = true
        
        if let existingReminder = existingReminder {
            // Update existing reminder
            viewModel.updateReminder(existingReminder.id, text: text) { [self] success in
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
            viewModel.createReminder(date: date, text: text) { [self] success in
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