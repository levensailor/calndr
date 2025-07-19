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
                    SchedulesHeaderView()
                    QuickStartSection(onPresetSelected: selectPreset)
                    AllPresetsSection(onPresetSelected: selectPreset)
                    CustomScheduleSection(onCreateCustom: createCustomSchedule)
                    SavedTemplatesSection()
                    Spacer(minLength: 80)
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColorSwiftUI)
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
    
    private func selectPreset(_ preset: SchedulePreset) {
        selectedPreset = preset
        showingScheduleBuilder = true
    }
    
    private func createCustomSchedule() {
        selectedPreset = nil
        showingScheduleBuilder = true
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

// MARK: - Quick Start Section

struct QuickStartSection: View {
    let onPresetSelected: (SchedulePreset) -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Start")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.textColor.color)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(SchedulePreset.commonPresets.filter { $0.isPopular }, id: \.id) { preset in
                    SchedulePresetCard(preset: preset) {
                        onPresetSelected(preset)
                    }
                }
            }
            .padding(.horizontal)
        }
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
        .sheet(isPresented: $showingEditModal) {
            ScheduleEditView(template: template)
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
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
    
    private var custodianOneName: String {
        viewModel.custodianOneName
    }
    
    private var custodianTwoName: String {
        viewModel.custodianTwoName
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
            
            VStack(spacing: 12) {
                Button(action: { showingDatePicker = true }) {
                    HStack {
                        Text("Date Range")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.color)
                        
                        Spacer()
                        
                        Text("\(startDate, formatter: dateFormatter) - \(endDate, formatter: dateFormatter)")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                    )
                }
                
                Toggle("Overwrite Existing Schedule", isOn: $overwriteExisting)
                    .foregroundColor(themeManager.currentTheme.textColor.color)
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
    @State private var detailedTemplate: ScheduleTemplate?
    @State private var scheduleName = ""
    @State private var scheduleDescription = ""
    @State private var patternType: SchedulePatternType = .weekly
    @State private var weeklyPattern = WeeklySchedulePattern()
    @State private var alternatingWeeksPattern: AlternatingWeeksPattern?
    @State private var isActive = true
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    private let daysOfWeek = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    
    var body: some View {
        NavigationView {
            if isLoading {
                VStack {
                    ProgressView()
                    Text("Loading template...")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.7))
                        .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(themeManager.currentTheme.mainBackgroundColorSwiftUI)
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
            }
        }
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
        viewModel.fetchScheduleTemplate(template.id) { result in
            switch result {
            case .success(let detailedTemplate):
                self.detailedTemplate = detailedTemplate
                self.scheduleName = detailedTemplate.name
                self.scheduleDescription = detailedTemplate.description ?? ""
                self.isActive = detailedTemplate.isActive
                self.patternType = detailedTemplate.patternType
                
                // Load the weekly pattern if available
                if let weeklyPattern = detailedTemplate.weeklyPattern {
                    self.weeklyPattern = weeklyPattern
                }
                
                // Load alternating weeks pattern if available
                if let alternatingPattern = detailedTemplate.alternatingWeeksPattern {
                    self.alternatingWeeksPattern = alternatingPattern
                }
                
                self.isLoading = false
                
            case .failure(let error):
                print("❌ Failed to load template details: \(error)")
                // Fallback to basic template data
                self.scheduleName = template.name
                self.scheduleDescription = template.description ?? ""
                self.isActive = template.isActive
                self.patternType = .weekly
                self.isLoading = false
                
                self.alertMessage = "Could not load full template details. Some features may be limited."
                self.showingAlert = true
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
        let apiPattern = viewModel.convertPatternToAPIFormat(weeklyPattern)
        
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
            } else {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(themeManager.currentTheme.textColor.color.opacity(0.6))
                    Text("Preview for \(patternType.displayName) coming soon")
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