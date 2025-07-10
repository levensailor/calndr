import SwiftUI

struct SchedulesView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAddSchedule = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Schedules")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.currentTheme.textColor)
                        
                        Text("Manage schedule templates and routines")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                    }
                    .padding(.horizontal)
                    
                    // Add Button
                    HStack {
                        Spacer()
                        Button(action: { showingAddSchedule = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Schedule Template")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.indigo)
                            .cornerRadius(10)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Schedule Templates List
                    if viewModel.scheduleTemplates.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.largeTitle)
                                .foregroundColor(themeManager.currentTheme.textColor.opacity(0.3))
                            
                            Text("No schedule templates added yet")
                                .font(.headline)
                                .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                            
                            Text("Create schedule templates to quickly apply recurring patterns")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.textColor.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    } else {
                        ForEach(viewModel.scheduleTemplates) { template in
                            ScheduleTemplateCard(template: template)
                                .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 80)
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor)
        }
        .sheet(isPresented: $showingAddSchedule) {
            AddScheduleView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
    }
}

struct ScheduleTemplateCard: View {
    let template: ScheduleTemplate
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: template.isActive ? "calendar.badge.clock" : "calendar.badge.exclamationmark")
                    .font(.title2)
                    .foregroundColor(template.isActive ? .indigo : .gray)
                    .frame(width: 30, height: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor)
                    
                    if let description = template.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(template.isActive ? "Active" : "Inactive")
                        .font(.caption)
                        .foregroundColor(template.isActive ? .green : .gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(template.isActive ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                        )
                    
                    Button(action: {
                        // TODO: Apply schedule template
                    }) {
                        Text("Apply")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.indigo)
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.otherMonthBackgroundColor)
                .shadow(color: themeManager.currentTheme.textColor.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

struct AddScheduleView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var description = ""
    @State private var isActive = true
    
    var body: some View {
        NavigationView {
            Form {
                Section("Schedule Template Information") {
                    FloatingLabelTextField(
                        title: "Template Name",
                        text: $name,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    
                    FloatingLabelTextField(
                        title: "Description (Optional)",
                        text: $description,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    
                    Toggle("Active Template", isOn: $isActive)
                        .foregroundColor(themeManager.currentTheme.textColor)
                }
                
                Section("Template Details") {
                    Text("Schedule pattern configuration will be implemented here")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                        .italic()
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor)
            .navigationTitle("Add Schedule Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // TODO: Implement save functionality
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct SchedulesView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager)
        
        SchedulesView()
            .environmentObject(calendarViewModel)
            .environmentObject(ThemeManager())
    }
} 