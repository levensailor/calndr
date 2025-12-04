import SwiftUI

struct SchedulesView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAddSchedule = false
    @State private var selectedPreset: SchedulePreset?
    @State private var showingScheduleBuilder = false
    @State private var presetToShow: SchedulePreset?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SchedulesHeaderView()
                    AllPresetsSection(onPresetSelected: selectPreset)
                    CustomScheduleSection(onCreateCustom: createCustomSchedule)
                    SavedTemplatesSection()
                    Spacer(minLength: 80)
                }
            }
            .scrollTargetBehavior(CustomVerticalPagingBehavior())
            .background(themeManager.currentTheme.mainBackgroundColorSwiftUI)
            .navigationBarHidden(true)
        }
        .sheet(item: $presetToShow) { preset in
            ScheduleBuilderView(selectedPreset: preset)
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingScheduleBuilder) {
            ScheduleBuilderView(selectedPreset: nil)
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
        .onAppear {
            viewModel.fetchScheduleTemplates()
        }
    }
    
    private func selectPreset(_ preset: SchedulePreset) {
        selectedPreset = preset
        presetToShow = preset  // This will trigger the preset sheet
    }
    
    private func createCustomSchedule() {
        selectedPreset = nil
        presetToShow = nil
        showingScheduleBuilder = true  // This will trigger the custom schedule sheet
    }
}

// MARK: - Header Section

struct SchedulesHeaderView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Default Schedules")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(themeManager.currentTheme.textColor.color)
            
            Text("Create and manage custody schedule templates")
                .font(.subheadline)
                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
        }
        .padding(.horizontal)
    }
}



// MARK: - All Presets Section

struct AllPresetsSection: View {
    let onPresetSelected: (SchedulePreset) -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Schedule Patterns")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.textColor.color)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(SchedulePreset.commonPresets, id: \.id) { preset in
                    SchedulePresetCard(preset: preset) {
                        onPresetSelected(preset)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Custom Schedule Section

struct CustomScheduleSection: View {
    let onCreateCustom: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Custom Schedule")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.textColor.color)
                .padding(.horizontal)
            
            Button(action: onCreateCustom) {
                CustomScheduleButton()
            }
            .padding(.horizontal)
        }
    }
}

struct CustomScheduleButton: View {
    var body: some View {
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
}

// MARK: - Saved Templates Section

struct SavedTemplatesSection: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        if !viewModel.scheduleTemplates.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Saved Templates")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.textColor.color)
                    .padding(.horizontal)
                
                ForEach(viewModel.scheduleTemplates) { template in
                    ScheduleTemplateCard(template: template)
                        .padding(.horizontal)
                }
            }
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
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                        .multilineTextAlignment(.leading)
                    
                    Text(preset.description)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding()
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                    .shadow(color: themeManager.currentTheme.textColor.color.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ScheduleTemplateCard: View {
    let template: ScheduleTemplate
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: CalendarViewModel
    @State private var showingDeleteAlert = false
    @State private var showingEditModal = false
    @State private var showingApplyConfirmation = false
    
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
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                    
                    if let description = template.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
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
                    
                    HStack(spacing: 8) {
                        Button(action: {
                            showingApplyConfirmation = true
                        }) {
                            Text("Apply")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.indigo)
                                .cornerRadius(4)
                        }
                        
                        Button(action: {
                            showingEditModal = true
                        }) {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                        
                        Button(action: {
                            showingDeleteAlert = true
                        }) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.red)
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                .shadow(color: themeManager.currentTheme.textColor.color.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .alert("Delete Schedule Template", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteTemplate()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(template.name)'? This action cannot be undone.")
        }
        .alert("Apply Schedule Template", isPresented: $showingApplyConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Apply") {
                applyTemplate()
            }
        } message: {
            Text("This will apply '\(template.name)' to all future dates starting tomorrow. Past custody events will not be changed. The schedule will automatically extend as you view future months.")
        }
        .sheet(isPresented: $showingEditModal) {
            ScheduleEditView(template: template)
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
    }
    
    private func applyTemplate() {
        // Templates now apply to all future dates automatically (next 90 days initially)
        // The backend will auto-generate more as needed when scrolling to future months
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 90, to: tomorrow) ?? tomorrow
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let application = ScheduleApplication(
            templateId: template.id,
            startDate: dateFormatter.string(from: tomorrow),
            endDate: dateFormatter.string(from: endDate),
            overwriteExisting: false
        )
        
        viewModel.applyScheduleTemplate(application) { success, message in
            if success {
                print("✅ Successfully applied template '\(template.name)': \(message ?? "No message")")
                print("📅 Template will apply to all future dates as you scroll")
            } else {
                print("❌ Failed to apply template '\(template.name)': \(message ?? "Unknown error")")
            }
        }
    }
    
    private func deleteTemplate() {
        viewModel.deleteScheduleTemplate(template.id) { success in
            if success {
                print("✅ Successfully deleted template '\(template.name)'")
            } else {
                print("❌ Failed to delete template '\(template.name)'")
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
    
    @State private var scheduleName: String
    @State private var scheduleDescription: String
    @State private var patternType: SchedulePatternType
    @State private var weeklyPattern: WeeklySchedulePattern
    @State private var alternatingWeeksPattern: AlternatingWeeksPattern?
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var overwriteExisting = false
    @State private var showingDatePicker = false
    
    private let daysOfWeek = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    
    private var custodianOneName: String {
        viewModel.custodianOneName
    }
    
    private var custodianTwoName: String {
        viewModel.custodianTwoName
    }
    
    init(selectedPreset: SchedulePreset?) {
        self.selectedPreset = selectedPreset
        
        // Initialize state with preset data immediately to avoid race condition
        if let preset = selectedPreset {
            self._scheduleName = State(initialValue: preset.name)
            self._scheduleDescription = State(initialValue: preset.description)
            self._patternType = State(initialValue: preset.patternType)
            self._weeklyPattern = State(initialValue: preset.weeklyPattern ?? WeeklySchedulePattern(
                sunday: nil, monday: nil, tuesday: nil, wednesday: nil,
                thursday: nil, friday: nil, saturday: nil
            ))
            self._alternatingWeeksPattern = State(initialValue: preset.alternatingWeeksPattern)
        } else {
            // Default values for custom schedule
            self._scheduleName = State(initialValue: "")
            self._scheduleDescription = State(initialValue: "")
            self._patternType = State(initialValue: .weekly)
            self._weeklyPattern = State(initialValue: WeeklySchedulePattern(
                sunday: nil, monday: nil, tuesday: nil, wednesday: nil,
                thursday: nil, friday: nil, saturday: nil
            ))
            self._alternatingWeeksPattern = State(initialValue: nil)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ScheduleBuilderHeaderView(selectedPreset: selectedPreset)
                    ScheduleInformationSection(scheduleName: $scheduleName, scheduleDescription: $scheduleDescription)
                    PatternTypeSelectionSection(patternType: $patternType)
                    
                    if patternType == .weekly {
                        WeeklyPatternConfigurationSection(weeklyPattern: $weeklyPattern)
                    } else if patternType == .alternatingWeeks || patternType == .alternatingDays {
                        AlternatingPatternConfigurationSection(
                            alternatingWeeksPattern: $alternatingWeeksPattern,
                            patternType: patternType
                        )
                    }
                    
                    SchedulePreviewSection(
                        patternType: patternType,
                        weeklyPattern: weeklyPattern,
                        alternatingWeeksPattern: alternatingWeeksPattern,
                        custodianOneName: custodianOneName,
                        custodianTwoName: custodianTwoName
                    )
                    .padding(.horizontal)
                    
                    ApplicationSettingsSection(
                        startDate: $startDate,
                        endDate: $endDate,
                        overwriteExisting: $overwriteExisting,
                        showingDatePicker: $showingDatePicker,
                        dateFormatter: dateFormatter
                    )
                    
                    Spacer(minLength: 80)
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColorSwiftUI)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.textColor.color)
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
        
        // For schedule templates, we store the logical pattern (parent1/parent2)
        // The conversion to actual IDs happens when applying the template
        let apiPattern = weeklyPattern
        
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
            
            // Apply the schedule to future dates (next 90 days)
            // The backend will auto-generate more as needed
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            let futureEndDate = Calendar.current.date(byAdding: .day, value: 90, to: tomorrow) ?? tomorrow
            
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            let application = ScheduleApplication(
                templateId: newTemplate.id,
                startDate: dateFormatter.string(from: tomorrow),
                endDate: dateFormatter.string(from: futureEndDate),
                overwriteExisting: overwriteExisting
            )
            
            viewModel.applyScheduleTemplate(application) { success, message in
                if success {
                    print("✅ Successfully applied schedule: \(message ?? "No message")")
                    print("📅 Schedule will automatically extend as you view future months")
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

// MARK: - Schedule Builder Components

struct ScheduleBuilderHeaderView: View {
    let selectedPreset: SchedulePreset?
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedPreset?.name ?? "Custom Schedule")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(themeManager.currentTheme.textColor.color)
            
            Text(selectedPreset?.description ?? "Create a custom custody schedule")
                .font(.subheadline)
                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
        }
        .padding(.horizontal)
    }
}

struct ScheduleInformationSection: View {
    @Binding var scheduleName: String
    @Binding var scheduleDescription: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Schedule Information")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.textColor.color)
            
            VStack(spacing: 12) {
                FloatingLabelTextField(
                    title: "Schedule Name",
                    text: $scheduleName,
                    isSecure: false
                )
                
                FloatingLabelTextField(
                    title: "Description (Optional)",
                    text: $scheduleDescription,
                    isSecure: false
                )
            }
        }
        .padding(.horizontal)
    }
}

struct PatternTypeSelectionSection: View {
    @Binding var patternType: SchedulePatternType
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pattern Type")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.textColor.color)
            
            ForEach(SchedulePatternType.allCases, id: \.self) { type in
                PatternTypeCard(
                    type: type,
                    isSelected: patternType == type,
                    action: { patternType = type }
                )
            }
        }
        .padding(.horizontal)
    }
}

struct WeeklyPatternConfigurationSection: View {
    @Binding var weeklyPattern: WeeklySchedulePattern
    @EnvironmentObject var viewModel: CalendarViewModel
    
    private var custodianOneName: String {
        viewModel.custodianOneName
    }
    
    private var custodianTwoName: String {
        viewModel.custodianTwoName
    }
    
    var body: some View {
        WeeklyPatternBuilder(
            pattern: $weeklyPattern,
            custodianOneName: custodianOneName,
            custodianTwoName: custodianTwoName
        )
        .padding(.horizontal)
    }
}

struct AlternatingPatternConfigurationSection: View {
    @Binding var alternatingWeeksPattern: AlternatingWeeksPattern?
    let patternType: SchedulePatternType
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    private var custodianOneName: String {
        viewModel.custodianOneName
    }
    
    private var custodianTwoName: String {
        viewModel.custodianTwoName
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(patternType == .alternatingWeeks ? "Alternating Weekly Pattern" : "Alternating Daily Pattern")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.textColor.color)
                .padding(.horizontal)
            
            if alternatingWeeksPattern == nil {
                Button("Set Up Pattern") {
                    initializeAlternatingPattern()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            } else {
                VStack(spacing: 20) {
                    AlternatingWeekPatternEditor(
                        title: "Week A Pattern",
                        pattern: Binding(
                            get: { alternatingWeeksPattern?.weekAPattern ?? WeeklySchedulePattern() },
                            set: { 
                                if alternatingWeeksPattern != nil {
                                    alternatingWeeksPattern?.weekAPattern = $0
                                }
                            }
                        ),
                        custodianOneName: custodianOneName,
                        custodianTwoName: custodianTwoName
                    )
                    
                    AlternatingWeekPatternEditor(
                        title: "Week B Pattern", 
                        pattern: Binding(
                            get: { alternatingWeeksPattern?.weekBPattern ?? WeeklySchedulePattern() },
                            set: {
                                if alternatingWeeksPattern != nil {
                                    alternatingWeeksPattern?.weekBPattern = $0
                                }
                            }
                        ),
                        custodianOneName: custodianOneName,
                        custodianTwoName: custodianTwoName
                    )
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func initializeAlternatingPattern() {
        let defaultWeekA = WeeklySchedulePattern(
            sunday: "parent1", monday: "parent1", tuesday: "parent1", wednesday: "parent1",
            thursday: "parent1", friday: "parent1", saturday: "parent1"
        )
        let defaultWeekB = WeeklySchedulePattern(
            sunday: "parent2", monday: "parent2", tuesday: "parent2", wednesday: "parent2",
            thursday: "parent2", friday: "parent2", saturday: "parent2"
        )
        
        alternatingWeeksPattern = AlternatingWeeksPattern(
            weekAPattern: defaultWeekA,
            weekBPattern: defaultWeekB,
            startingWeek: "A",
            referenceDate: "2024-01-01"
        )
    }
}

struct AlternatingWeekPatternEditor: View {
    let title: String
    @Binding var pattern: WeeklySchedulePattern
    let custodianOneName: String
    let custodianTwoName: String
    @EnvironmentObject var themeManager: ThemeManager
    
    private let daysOfWeek = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.currentTheme.textColor.color)
            
            VStack(spacing: 8) {
                ForEach(Array(daysOfWeek.enumerated()), id: \.offset) { index, day in
                    AlternatingDayAssignmentRow(
                        dayName: day,
                        selectedParent: bindingForDay(index),
                        custodianOneName: custodianOneName,
                        custodianTwoName: custodianTwoName
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
        )
    }
    
    private func bindingForDay(_ dayIndex: Int) -> Binding<String?> {
        switch dayIndex {
        case 0: return $pattern.sunday
        case 1: return $pattern.monday
        case 2: return $pattern.tuesday
        case 3: return $pattern.wednesday
        case 4: return $pattern.thursday
        case 5: return $pattern.friday
        case 6: return $pattern.saturday
        default: return .constant(nil)
        }
    }
}

struct AlternatingDayAssignmentRow: View {
    let dayName: String
    @Binding var selectedParent: String?
    let custodianOneName: String
    let custodianTwoName: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack {
            Text(dayName)
                .font(.subheadline)
                .foregroundColor(themeManager.currentTheme.textColor.color)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 8) {
                // Unassigned
                Button(action: { selectedParent = nil }) {
                    Text("None")
                        .font(.caption)
                        .foregroundColor(selectedParent == nil ? .white : themeManager.currentTheme.textColor.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(selectedParent == nil ? Color.gray : Color.clear)
                        )
                }
                
                // Parent 1
                Button(action: { selectedParent = "parent1" }) {
                    Text(custodianOneName)
                        .font(.caption)
                        .foregroundColor(selectedParent == "parent1" ? .white : themeManager.currentTheme.textColor.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(selectedParent == "parent1" ? themeManager.currentTheme.parentOneColor.color : Color.clear)
                        )
                }
                
                // Parent 2
                Button(action: { selectedParent = "parent2" }) {
                    Text(custodianTwoName)
                        .font(.caption)
                        .foregroundColor(selectedParent == "parent2" ? .white : themeManager.currentTheme.textColor.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(selectedParent == "parent2" ? themeManager.currentTheme.parentTwoColor.color : Color.clear)
                        )
                }
            }
        }
    }
}

struct ApplicationSettingsSection: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var overwriteExisting: Bool
    @Binding var showingDatePicker: Bool
    let dateFormatter: DateFormatter
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Apply Schedule")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.textColor.color)
            
            VStack(alignment: .leading, spacing: 12) {
                // Information about automatic application
                VStack(alignment: .leading, spacing: 8) {
                    Label("Applies to all future dates", systemImage: "calendar.badge.plus")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                    
                    Text("Schedule will start tomorrow and automatically extend as you view future months")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                        .padding(.leading, 28)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                )
                
                Toggle("Overwrite Future Schedule", isOn: $overwriteExisting)
                    .foregroundColor(themeManager.currentTheme.textColor.color)
                
                Text("Past custody events are always protected")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                    .padding(.leading, 28)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Schedule Edit View

struct ScheduleEditView: View {
    let template: ScheduleTemplate
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var isLoading = true
    @State private var dataLoaded = false
    @State private var scheduleName: String
    @State private var scheduleDescription: String
    @State private var patternType: SchedulePatternType
    @State private var weeklyPattern: WeeklySchedulePattern
    @State private var alternatingWeeksPattern: AlternatingWeeksPattern?
    @State private var isActive: Bool
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    init(template: ScheduleTemplate) {
        self.template = template
        
        // Initialize state with template data immediately to avoid empty fields
        self._scheduleName = State(initialValue: template.name)
        self._scheduleDescription = State(initialValue: template.description ?? "")
        self._patternType = State(initialValue: template.patternType)
        self._weeklyPattern = State(initialValue: template.weeklyPattern ?? WeeklySchedulePattern())
        self._alternatingWeeksPattern = State(initialValue: template.alternatingWeeksPattern)
        self._isActive = State(initialValue: template.isActive)
        
        print("🏗️ ScheduleEditView initialized with template: \(template.name)")
        print("🏗️ Initial weekly pattern: \(template.weeklyPattern?.description ?? "nil")")
    }
    
    private let daysOfWeek = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    
    var body: some View {
        NavigationView {
            if isLoading || !dataLoaded {
                VStack {
                    ProgressView()
                    Text("Loading template...")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                        .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(themeManager.currentTheme.mainBackgroundColorSwiftUI)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveChanges()
                        }
                        .disabled(scheduleName.isEmpty || isLoading)
                        .foregroundColor(scheduleName.isEmpty || isLoading ? .gray : .blue)
                    }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ScheduleEditHeaderView()
                        ScheduleEditInformationSection(scheduleName: $scheduleName, scheduleDescription: $scheduleDescription)
                        ScheduleEditStatusSection(isActive: $isActive)
                        
                        if patternType == .weekly {
                            ScheduleEditWeeklyPatternSection(
                                weeklyPattern: $weeklyPattern,
                                daysOfWeek: daysOfWeek,
                                bindingForDay: bindingForDay
                            )
                        }
                        
                        Spacer(minLength: 80)
                    }
                }
                .background(themeManager.currentTheme.mainBackgroundColorSwiftUI)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveChanges()
                        }
                        .disabled(scheduleName.isEmpty || isLoading)
                        .foregroundColor(scheduleName.isEmpty || isLoading ? .gray : .blue)
                    }
                }
            }
        }
        .alert("Edit Template", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            loadTemplateDetails()
        }
    }
    
    private func loadTemplateDetails() {
        print("🔄 Loading template details for template ID: \(template.id)")
        print("📄 Initial template passed to view: \(template)")
        
        viewModel.fetchScheduleTemplate(template.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fetchedTemplate):
                    print("✅ Successfully fetched detailed schedule template: \(fetchedTemplate)")
                    print("📅 Template weekly pattern: \(fetchedTemplate.weeklyPattern?.description ?? "nil")")
                    
                    self.scheduleName = fetchedTemplate.name
                    self.scheduleDescription = fetchedTemplate.description ?? ""
                    self.isActive = fetchedTemplate.isActive
                    self.patternType = fetchedTemplate.patternType
                    
                    if let weeklyPattern = fetchedTemplate.weeklyPattern {
                        print("📅 Loading weekly pattern: \(weeklyPattern)")
                        print("📅 Pattern details - Sunday: \(weeklyPattern.sunday ?? "nil"), Monday: \(weeklyPattern.monday ?? "nil"), Tuesday: \(weeklyPattern.tuesday ?? "nil"), Wednesday: \(weeklyPattern.wednesday ?? "nil"), Thursday: \(weeklyPattern.thursday ?? "nil"), Friday: \(weeklyPattern.friday ?? "nil"), Saturday: \(weeklyPattern.saturday ?? "nil")")
                        self.weeklyPattern = weeklyPattern
                    } else {
                        print("❌ No weekly pattern found in fetched template")
                        // Check if we can use the pattern from the initial template passed to the view
                        if let initialPattern = self.template.weeklyPattern {
                            print("🔄 Using initial template pattern as fallback: \(initialPattern)")
                            self.weeklyPattern = initialPattern
                        }
                    }
                    
                    if let alternatingPattern = fetchedTemplate.alternatingWeeksPattern {
                        print("📅 Loading alternating weeks pattern: \(alternatingPattern)")
                        self.alternatingWeeksPattern = alternatingPattern
                    }
                    
                    self.isLoading = false
                    self.dataLoaded = true
                    print("✅ Template loading completed successfully")
                    
                case .failure(let error):
                    print("❌ Failed to load schedule template: \(error)")
                    self.isLoading = false
                    self.dataLoaded = false  // Don't show content on error
                    self.alertMessage = "Could not load schedule details. Please try again."
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func bindingForDay(_ dayIndex: Int) -> Binding<String?> {
        switch dayIndex {
        case 0: return $weeklyPattern.sunday
        case 1: return $weeklyPattern.monday
        case 2: return $weeklyPattern.tuesday
        case 3: return $weeklyPattern.wednesday
        case 4: return $weeklyPattern.thursday
        case 5: return $weeklyPattern.friday
        case 6: return $weeklyPattern.saturday
        default: return .constant(nil)
        }
    }
    
    private func saveChanges() {
        // Store the logical pattern (parent1/parent2) in templates
        let apiPattern = weeklyPattern
        
        let templateData = ScheduleTemplateCreate(
            name: scheduleName,
            description: scheduleDescription.isEmpty ? nil : scheduleDescription,
            patternType: patternType,
            weeklyPattern: patternType == .weekly ? apiPattern : nil,
            alternatingWeeksPattern: alternatingWeeksPattern,
            isActive: isActive
        )
        
        viewModel.updateScheduleTemplate(template.id, templateData: templateData) { success in
            if success {
                alertMessage = "Schedule template updated successfully"
                showingAlert = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            } else {
                alertMessage = "Failed to update schedule template"
                showingAlert = true
            }
        }
    }
}

// MARK: - Schedule Edit Components

struct ScheduleEditHeaderView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Edit Schedule")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(themeManager.currentTheme.textColor.color)
            
            Text("Modify your custody schedule template")
                .font(.subheadline)
                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
        }
        .padding(.horizontal)
    }
}

struct ScheduleEditInformationSection: View {
    @Binding var scheduleName: String
    @Binding var scheduleDescription: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Schedule Information")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.textColor.color)
            
            VStack(spacing: 12) {
                FloatingLabelTextField(
                    title: "Schedule Name",
                    text: $scheduleName,
                    isSecure: false
                )
                
                FloatingLabelTextField(
                    title: "Description (Optional)",
                    text: $scheduleDescription,
                    isSecure: false
                )
            }
        }
        .padding(.horizontal)
    }
}

struct ScheduleEditStatusSection: View {
    @Binding var isActive: Bool
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.textColor.color)
                .padding(.horizontal)
            
            Toggle("Active", isOn: $isActive)
                .font(.subheadline)
                .foregroundColor(themeManager.currentTheme.textColor.color)
                .padding(.horizontal)
        }
    }
}

struct ScheduleEditWeeklyPatternSection: View {
    @Binding var weeklyPattern: WeeklySchedulePattern
    let daysOfWeek: [String]
    let bindingForDay: (Int) -> Binding<String?>
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    private var custodianOneName: String {
        viewModel.custodianOneName
    }
    
    private var custodianTwoName: String {
        viewModel.custodianTwoName
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Schedule")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.textColor.color)
                .padding(.horizontal)
            
            ForEach(Array(daysOfWeek.enumerated()), id: \.offset) { index, day in
                DayAssignmentRow(
                    dayName: day,
                    selectedParent: bindingForDay(index),
                    custodianOneName: custodianOneName,
                    custodianTwoName: custodianTwoName
                )
                .padding(.horizontal)
            }
        }
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
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                    
                    Text(type.description)
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Schedule")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.textColor.color)
            
            VStack(spacing: 8) {
                DayAssignmentRow(
                    dayName: "Sunday",
                    selectedParent: $pattern.sunday,
                    custodianOneName: custodianOneName,
                    custodianTwoName: custodianTwoName
                )
                DayAssignmentRow(
                    dayName: "Monday",
                    selectedParent: $pattern.monday,
                    custodianOneName: custodianOneName,
                    custodianTwoName: custodianTwoName
                )
                DayAssignmentRow(
                    dayName: "Tuesday",
                    selectedParent: $pattern.tuesday,
                    custodianOneName: custodianOneName,
                    custodianTwoName: custodianTwoName
                )
                DayAssignmentRow(
                    dayName: "Wednesday",
                    selectedParent: $pattern.wednesday,
                    custodianOneName: custodianOneName,
                    custodianTwoName: custodianTwoName
                )
                DayAssignmentRow(
                    dayName: "Thursday",
                    selectedParent: $pattern.thursday,
                    custodianOneName: custodianOneName,
                    custodianTwoName: custodianTwoName
                )
                DayAssignmentRow(
                    dayName: "Friday",
                    selectedParent: $pattern.friday,
                    custodianOneName: custodianOneName,
                    custodianTwoName: custodianTwoName
                )
                DayAssignmentRow(
                    dayName: "Saturday",
                    selectedParent: $pattern.saturday,
                    custodianOneName: custodianOneName,
                    custodianTwoName: custodianTwoName
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
        )
    }
}

struct DayAssignmentRow: View {
    let dayName: String
    @Binding var selectedParent: String?
    let custodianOneName: String
    let custodianTwoName: String
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: CalendarViewModel
    
    var body: some View {
        HStack {
            Text(dayName)
                .font(.subheadline)
                .foregroundColor(themeManager.currentTheme.textColor.color)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 8) {
                // Unassigned
                Button(action: { selectedParent = nil }) {
                    Text("None")
                        .font(.caption)
                        .foregroundColor(selectedParent == nil ? .white : themeManager.currentTheme.textColor.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(selectedParent == nil ? Color.gray : Color.clear)
                        )
                }
                
                // Parent 1
                Button(action: { selectedParent = "parent1" }) {
                    Text(custodianOneName)
                        .font(.caption)
                        .foregroundColor(selectedParent == "parent1" ? .white : themeManager.currentTheme.textColor.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(selectedParent == "parent1" ? themeManager.currentTheme.parentOneColor.color : Color.clear)
                        )
                }
                
                // Parent 2
                Button(action: { selectedParent = "parent2" }) {
                    Text(custodianTwoName)
                        .font(.caption)
                        .foregroundColor(selectedParent == "parent2" ? .white : themeManager.currentTheme.textColor.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(selectedParent == "parent2" ? themeManager.currentTheme.parentTwoColor.color : Color.clear)
                        )
                }
            }
        }
    }
}

struct SchedulePreviewSection: View {
    let patternType: SchedulePatternType
    let weeklyPattern: WeeklySchedulePattern
    let alternatingWeeksPattern: AlternatingWeeksPattern?
    let custodianOneName: String
    let custodianTwoName: String
    @EnvironmentObject var themeManager: ThemeManager
    
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Schedule Preview")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.textColor.color)
            
            if patternType == .weekly {
                WeeklyPreviewContent(weeklyPattern: weeklyPattern, daysOfWeek: daysOfWeek)
            } else if (patternType == .alternatingWeeks || patternType == .alternatingDays) && alternatingWeeksPattern != nil {
                AlternatingPreviewContent(
                    alternatingPattern: alternatingWeeksPattern!,
                    patternType: patternType,
                    daysOfWeek: daysOfWeek
                )
            } else {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                    Text("Configure the pattern above to see preview")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                        .italic()
                }
            }
            
            // Legend
            HStack(spacing: 24) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(themeManager.currentTheme.parentOneColor.color)
                        .frame(width: 16, height: 16)
                        .cornerRadius(2)
                    Text(custodianOneName)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                }
                
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(themeManager.currentTheme.parentTwoColor.color)
                        .frame(width: 16, height: 16)
                        .cornerRadius(2)
                    Text(custodianTwoName)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                }
                
                HStack(spacing: 8) {
                    Rectangle()
                        .stroke(themeManager.currentTheme.textColor.color, lineWidth: 1)
                        .frame(width: 15, height: 15)
                    Text("Unassigned")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
        )
    }

    private func getParentColor(for day: String) -> Color {
        let parent: String?
        switch day {
        case "Sun": parent = weeklyPattern.sunday
        case "Mon": parent = weeklyPattern.monday
        case "Tue": parent = weeklyPattern.tuesday
        case "Wed": parent = weeklyPattern.wednesday
        case "Thu": parent = weeklyPattern.thursday
        case "Fri": parent = weeklyPattern.friday
        case "Sat": parent = weeklyPattern.saturday
        default: parent = nil
        }
        
        if parent == "parent1" {
            return themeManager.currentTheme.parentOneColor.color
        } else if parent == "parent2" {
            return themeManager.currentTheme.parentTwoColor.color
        } else {
            return Color.gray.opacity(0.3)
        }
    }
}

struct WeeklyPreviewContent: View {
    let weeklyPattern: WeeklySchedulePattern
    let daysOfWeek: [String]
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.color)
                        .frame(maxWidth: .infinity)
                }
            }
            
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Rectangle()
                        .fill(getParentColor(for: day))
                        .frame(height: 20)
                        .cornerRadius(2)
                }
            }
        }
    }
    
    private func getParentColor(for day: String) -> Color {
        let parent: String?
        switch day {
        case "Sun": parent = weeklyPattern.sunday
        case "Mon": parent = weeklyPattern.monday
        case "Tue": parent = weeklyPattern.tuesday
        case "Wed": parent = weeklyPattern.wednesday
        case "Thu": parent = weeklyPattern.thursday
        case "Fri": parent = weeklyPattern.friday
        case "Sat": parent = weeklyPattern.saturday
        default: parent = nil
        }
        
        if parent == "parent1" {
            return themeManager.currentTheme.parentOneColor.color
        } else if parent == "parent2" {
            return themeManager.currentTheme.parentTwoColor.color
        } else {
            return Color.gray.opacity(0.3)
        }
    }
}

struct AlternatingPreviewContent: View {
    let alternatingPattern: AlternatingWeeksPattern
    let patternType: SchedulePatternType
    let daysOfWeek: [String]
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 12) {
            Text(patternType == .alternatingWeeks ? "2-Week Cycle" : "2-Week Daily Cycle")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
            
            VStack(spacing: 8) {
                // Week A
                VStack(spacing: 4) {
                    HStack {
                        Text("Week A")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.currentTheme.textColor.color)
                            .frame(width: 50, alignment: .leading)
                        
                        ForEach(daysOfWeek, id: \.self) { day in
                            Text(day)
                                .font(.caption2)
                                .foregroundColor(themeManager.currentTheme.textColor.color)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    
                    HStack {
                        Spacer()
                            .frame(width: 50)
                        
                        ForEach(daysOfWeek, id: \.self) { day in
                            Rectangle()
                                .fill(getParentColor(for: day, week: "A"))
                                .frame(height: 16)
                                .cornerRadius(2)
                        }
                    }
                }
                
                // Week B
                VStack(spacing: 4) {
                    HStack {
                        Text("Week B")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.currentTheme.textColor.color)
                            .frame(width: 50, alignment: .leading)
                        
                        ForEach(daysOfWeek, id: \.self) { day in
                            Text(day)
                                .font(.caption2)
                                .foregroundColor(themeManager.currentTheme.textColor.color)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    
                    HStack {
                        Spacer()
                            .frame(width: 50)
                        
                        ForEach(daysOfWeek, id: \.self) { day in
                            Rectangle()
                                .fill(getParentColor(for: day, week: "B"))
                                .frame(height: 16)
                                .cornerRadius(2)
                        }
                    }
                }
            }
        }
    }
    
    private func getParentColor(for day: String, week: String) -> Color {
        let pattern = week == "A" ? alternatingPattern.weekAPattern : alternatingPattern.weekBPattern
        let parent: String?
        
        switch day {
        case "Sun": parent = pattern.sunday
        case "Mon": parent = pattern.monday
        case "Tue": parent = pattern.tuesday
        case "Wed": parent = pattern.wednesday
        case "Thu": parent = pattern.thursday
        case "Fri": parent = pattern.friday
        case "Sat": parent = pattern.saturday
        default: parent = nil
        }
        
        if parent == "parent1" {
            return themeManager.currentTheme.parentOneColor.color
        } else if parent == "parent2" {
            return themeManager.currentTheme.parentTwoColor.color
        } else {
            return Color.gray.opacity(0.3)
        }
    }
}

// MARK: - Date Range Picker

struct DateRangePickerView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Start Date",
                    selection: $startDate,
                    displayedComponents: .date
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()
                
                DatePicker(
                    "End Date",
                    selection: $endDate,
                    in: startDate...,
                    displayedComponents: .date
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()
                
                Spacer()
            }
            .padding()
            .background(themeManager.currentTheme.mainBackgroundColorSwiftUI)
            .navigationTitle("Select Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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