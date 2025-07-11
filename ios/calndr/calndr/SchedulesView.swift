import SwiftUI

struct SchedulesView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAddSchedule = false
    @State private var selectedPreset: SchedulePreset?
    @State private var showingScheduleBuilder = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Schedules")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.currentTheme.textColor)
                        
                        Text("Create and manage custody schedule templates")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                    }
                    .padding(.horizontal)
                    
                    // Quick Start Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Quick Start")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor)
                            .padding(.horizontal)
                        
                        // Popular Presets
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(SchedulePreset.commonPresets.filter { $0.isPopular }, id: \.id) { preset in
                                SchedulePresetCard(preset: preset) {
                                    selectedPreset = preset
                                    showingScheduleBuilder = true
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // All Presets Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("All Schedule Patterns")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(SchedulePreset.commonPresets, id: \.id) { preset in
                                SchedulePresetCard(preset: preset) {
                                    selectedPreset = preset
                                    showingScheduleBuilder = true
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Custom Schedule Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Custom Schedule")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor)
                            .padding(.horizontal)
                        
                        Button(action: {
                            selectedPreset = nil
                            showingScheduleBuilder = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Create Custom Schedule")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text("Build your own schedule pattern")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding()
                            .background(Color.indigo)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Saved Templates Section
                    if !viewModel.scheduleTemplates.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Saved Templates")
                                .font(.headline)
                                .foregroundColor(themeManager.currentTheme.textColor)
                                .padding(.horizontal)
                            
                            ForEach(viewModel.scheduleTemplates) { template in
                                ScheduleTemplateCard(template: template)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    
                    Spacer(minLength: 80)
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingScheduleBuilder) {
            ScheduleBuilderView(selectedPreset: selectedPreset)
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
        .onAppear {
            viewModel.fetchScheduleTemplates()
        }
    }
}

struct SchedulePresetCard: View {
    let preset: SchedulePreset
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: preset.icon)
                        .font(.title2)
                        .foregroundColor(.indigo)
                        .frame(width: 30, height: 30)
                    
                    Spacer()
                    
                    if preset.isPopular {
                        Text("Popular")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(4)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name)
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor)
                        .multilineTextAlignment(.leading)
                    
                    Text(preset.description)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding()
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.currentTheme.otherMonthBackgroundColor)
                    .shadow(color: themeManager.currentTheme.textColor.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ScheduleTemplateCard: View {
    let template: ScheduleTemplate
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: CalendarViewModel
    
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
                        applyTemplate()
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
    
    private func applyTemplate() {
        // Apply template to the next 3 months by default
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .month, value: 3, to: startDate) ?? startDate
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let application = ScheduleApplication(
            templateId: template.id,
            startDate: dateFormatter.string(from: startDate),
            endDate: dateFormatter.string(from: endDate),
            overwriteExisting: false
        )
        
        viewModel.applyScheduleTemplate(application) { success, message in
            if success {
                print("✅ Successfully applied template '\(template.name)': \(message ?? "No message")")
            } else {
                print("❌ Failed to apply template '\(template.name)': \(message ?? "Unknown error")")
            }
        }
    }
}

// MARK: - Schedule Builder View

struct ScheduleBuilderView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    let selectedPreset: SchedulePreset?
    
    @State private var scheduleName = ""
    @State private var scheduleDescription = ""
    @State private var patternType: SchedulePatternType = .weekly
    @State private var weeklyPattern = WeeklySchedulePattern(
        sunday: nil, monday: nil, tuesday: nil, wednesday: nil,
        thursday: nil, friday: nil, saturday: nil
    )
    @State private var alternatingWeeksPattern: AlternatingWeeksPattern?
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var overwriteExisting = false
    @State private var showingDatePicker = false
    
    private let daysOfWeek = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedPreset?.name ?? "Custom Schedule")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.currentTheme.textColor)
                        
                        Text(selectedPreset?.description ?? "Create a custom custody schedule")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                    }
                    .padding(.horizontal)
                    
                    // Schedule Information
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Schedule Information")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor)
                        
                        VStack(spacing: 12) {
                            FloatingLabelTextField(
                                title: "Schedule Name",
                                text: $scheduleName,
                                isSecure: false,
                                themeManager: themeManager
                            )
                            
                            FloatingLabelTextField(
                                title: "Description (Optional)",
                                text: $scheduleDescription,
                                isSecure: false,
                                themeManager: themeManager
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Pattern Type Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Pattern Type")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor)
                        
                        ForEach(SchedulePatternType.allCases, id: \.self) { type in
                            PatternTypeCard(
                                type: type,
                                isSelected: patternType == type,
                                action: { patternType = type }
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Schedule Pattern Configuration
                    if patternType == .weekly {
                        WeeklyPatternBuilder(
                            pattern: $weeklyPattern,
                            custodianOneName: viewModel.custodianOneName,
                            custodianTwoName: viewModel.custodianTwoName
                        )
                        .padding(.horizontal)
                    }
                    
                    // Schedule Preview
                    SchedulePreviewSection(
                        patternType: patternType,
                        weeklyPattern: weeklyPattern,
                        alternatingWeeksPattern: alternatingWeeksPattern,
                        custodianOneName: viewModel.custodianOneName,
                        custodianTwoName: viewModel.custodianTwoName
                    )
                    .padding(.horizontal)
                    
                    // Application Settings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Apply Schedule")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColor)
                        
                        VStack(spacing: 12) {
                            Button(action: { showingDatePicker = true }) {
                                HStack {
                                    Text("Date Range")
                                        .font(.subheadline)
                                        .foregroundColor(themeManager.currentTheme.textColor)
                                    
                                    Spacer()
                                    
                                    Text("\(startDate, formatter: dateFormatter) - \(endDate, formatter: dateFormatter)")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(themeManager.currentTheme.otherMonthBackgroundColor)
                                )
                            }
                            
                            Toggle("Overwrite Existing Schedule", isOn: $overwriteExisting)
                                .foregroundColor(themeManager.currentTheme.textColor)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 80)
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.textColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save & Apply") {
                        saveAndApplySchedule()
                    }
                    .disabled(scheduleName.isEmpty || !isValidSchedule())
                    .foregroundColor(scheduleName.isEmpty || !isValidSchedule() ? .gray : .blue)
                }
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            DateRangePickerView(startDate: $startDate, endDate: $endDate)
        }
        .onAppear {
            loadPresetData()
        }
    }
    
    private func loadPresetData() {
        guard let preset = selectedPreset else { return }
        
        scheduleName = preset.name
        scheduleDescription = preset.description
        patternType = preset.patternType
        
        if let weeklyPattern = preset.weeklyPattern {
            self.weeklyPattern = weeklyPattern
        }
        
        if let alternatingPattern = preset.alternatingWeeksPattern {
            self.alternatingWeeksPattern = alternatingPattern
        }
    }
    
    private func isValidSchedule() -> Bool {
        switch patternType {
        case .weekly:
            return weeklyPattern.sunday != nil ||
                   weeklyPattern.monday != nil ||
                   weeklyPattern.tuesday != nil ||
                   weeklyPattern.wednesday != nil ||
                   weeklyPattern.thursday != nil ||
                   weeklyPattern.friday != nil ||
                   weeklyPattern.saturday != nil
        case .alternatingWeeks, .alternatingDays:
            return alternatingWeeksPattern != nil
        case .custom:
            return true
        }
    }
    
    private func saveAndApplySchedule() {
        // Validate schedule first
        if patternType == .weekly {
            let validation = viewModel.validateSchedulePattern(weeklyPattern)
            if !validation.isValid {
                // Show error alert
                print("❌ Invalid schedule: \(validation.message ?? "Unknown error")")
                return
            }
        }
        
        // Convert pattern to API format
        let apiPattern = viewModel.convertPatternToAPIFormat(weeklyPattern)
        
        // Create schedule template
        let templateData = ScheduleTemplateCreate(
            name: scheduleName,
            description: scheduleDescription.isEmpty ? nil : scheduleDescription,
            patternType: patternType,
            weeklyPattern: patternType == .weekly ? apiPattern : nil,
            alternatingWeeksPattern: alternatingWeeksPattern,
            isActive: true
        )
        
        print("🚀 Saving schedule: \(scheduleName)")
        print("📅 Pattern type: \(patternType)")
        print("📆 Date range: \(startDate) to \(endDate)")
        
        // Save template first
        viewModel.createScheduleTemplate(templateData) { success in
            guard success else {
                print("❌ Failed to save schedule template")
                return
            }
            
            // Get the newly created template ID
            guard let newTemplate = viewModel.scheduleTemplates.last else {
                print("❌ Could not find newly created template")
                return
            }
            
            // Apply the schedule
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            let application = ScheduleApplication(
                templateId: newTemplate.id,
                startDate: dateFormatter.string(from: startDate),
                endDate: dateFormatter.string(from: endDate),
                overwriteExisting: overwriteExisting
            )
            
            viewModel.applyScheduleTemplate(application) { success, message in
                if success {
                    print("✅ Successfully applied schedule: \(message ?? "No message")")
                } else {
                    print("❌ Failed to apply schedule: \(message ?? "Unknown error")")
                }
                
                DispatchQueue.main.async {
                    dismiss()
                }
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
}

struct PatternTypeCard: View {
    let type: SchedulePatternType
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor)
                    
                    Text(type.description)
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeManager.currentTheme.otherMonthBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct WeeklyPatternBuilder: View {
    @Binding var pattern: WeeklySchedulePattern
    let custodianOneName: String
    let custodianTwoName: String
    @EnvironmentObject var themeManager: ThemeManager
    
    private let daysOfWeek = [
        ("Sunday", \WeeklySchedulePattern.sunday),
        ("Monday", \WeeklySchedulePattern.monday),
        ("Tuesday", \WeeklySchedulePattern.tuesday),
        ("Wednesday", \WeeklySchedulePattern.wednesday),
        ("Thursday", \WeeklySchedulePattern.thursday),
        ("Friday", \WeeklySchedulePattern.friday),
        ("Saturday", \WeeklySchedulePattern.saturday)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Schedule")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.textColor)
            
            VStack(spacing: 8) {
                ForEach(daysOfWeek, id: \.0) { day, keyPath in
                    DayAssignmentRow(
                        dayName: day,
                        selectedParent: Binding(
                            get: { pattern[keyPath: keyPath] },
                            set: { newValue in
                                pattern = WeeklySchedulePattern(
                                    sunday: keyPath == \.sunday ? newValue : pattern.sunday,
                                    monday: keyPath == \.monday ? newValue : pattern.monday,
                                    tuesday: keyPath == \.tuesday ? newValue : pattern.tuesday,
                                    wednesday: keyPath == \.wednesday ? newValue : pattern.wednesday,
                                    thursday: keyPath == \.thursday ? newValue : pattern.thursday,
                                    friday: keyPath == \.friday ? newValue : pattern.friday,
                                    saturday: keyPath == \.saturday ? newValue : pattern.saturday
                                )
                            }
                        ),
                        custodianOneName: custodianOneName,
                        custodianTwoName: custodianTwoName
                    )
                }
            }
        }
    }
}

struct DayAssignmentRow: View {
    let dayName: String
    @Binding var selectedParent: String?
    let custodianOneName: String
    let custodianTwoName: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack {
            Text(dayName)
                .font(.subheadline)
                .foregroundColor(themeManager.currentTheme.textColor)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 8) {
                // Unassigned
                Button(action: { selectedParent = nil }) {
                    Text("None")
                        .font(.caption)
                        .foregroundColor(selectedParent == nil ? .white : themeManager.currentTheme.textColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedParent == nil ? Color.gray : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                        )
                }
                
                // Parent 1
                Button(action: { selectedParent = "parent1" }) {
                    Text(custodianOneName)
                        .font(.caption)
                        .foregroundColor(selectedParent == "parent1" ? .white : themeManager.currentTheme.textColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedParent == "parent1" ? themeManager.currentTheme.parentOneColor : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(themeManager.currentTheme.parentOneColor, lineWidth: 1)
                                )
                        )
                }
                
                // Parent 2
                Button(action: { selectedParent = "parent2" }) {
                    Text(custodianTwoName)
                        .font(.caption)
                        .foregroundColor(selectedParent == "parent2" ? .white : themeManager.currentTheme.textColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedParent == "parent2" ? themeManager.currentTheme.parentTwoColor : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(themeManager.currentTheme.parentTwoColor, lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(themeManager.currentTheme.otherMonthBackgroundColor)
        )
    }
}

struct SchedulePreviewSection: View {
    let patternType: SchedulePatternType
    let weeklyPattern: WeeklySchedulePattern
    let alternatingWeeksPattern: AlternatingWeeksPattern?
    let custodianOneName: String
    let custodianTwoName: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Schedule Preview")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.textColor)
            
            if patternType == .weekly {
                WeeklySchedulePreview(
                    pattern: weeklyPattern,
                    custodianOneName: custodianOneName,
                    custodianTwoName: custodianTwoName
                )
            } else {
                Text("Preview for \(patternType.displayName) coming soon")
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                    .italic()
            }
        }
    }
}

struct WeeklySchedulePreview: View {
    let pattern: WeeklySchedulePattern
    let custodianOneName: String
    let custodianTwoName: String
    @EnvironmentObject var themeManager: ThemeManager
    
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(Array(daysOfWeek.enumerated()), id: \.offset) { index, day in
                    VStack(spacing: 4) {
                        Text(day)
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor)
                        
                        Rectangle()
                            .fill(colorForDay(index + 1))
                            .frame(height: 40)
                            .cornerRadius(4)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            HStack {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(themeManager.currentTheme.parentOneColor)
                        .frame(width: 12, height: 12)
                        .cornerRadius(2)
                    Text(custodianOneName)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(themeManager.currentTheme.parentTwoColor)
                        .frame(width: 12, height: 12)
                        .cornerRadius(2)
                    Text(custodianTwoName)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .cornerRadius(2)
                    Text("Unassigned")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(themeManager.currentTheme.otherMonthBackgroundColor)
        )
    }
    
    private func colorForDay(_ weekday: Int) -> Color {
        let assignment = pattern.custodianFor(weekday: weekday)
        
        switch assignment {
        case "parent1":
            return themeManager.currentTheme.parentOneColor
        case "parent2":
            return themeManager.currentTheme.parentTwoColor
        default:
            return Color.gray.opacity(0.3)
        }
    }
}

struct DateRangePickerView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle())
                
                DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle())
            }
            .padding()
            .background(themeManager.currentTheme.mainBackgroundColor)
            .navigationTitle("Select Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SchedulesView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let themeManager = ThemeManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager, themeManager: themeManager)
        
        SchedulesView()
            .environmentObject(calendarViewModel)
            .environmentObject(themeManager)
    }
} 