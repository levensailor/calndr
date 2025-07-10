import SwiftUI

struct SettingsSectionCard: View {
    let section: SettingsSection
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: section.icon)
                    .font(.title2)
                    .foregroundColor(section.color)
                    .frame(width: 30, height: 30)
                
                Spacer()
                
                if let count = section.itemCount {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(section.color)
                        .clipShape(Capsule())
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.textColor)
                
                Text(section.description)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.otherMonthBackgroundColor)
                .shadow(color: themeManager.currentTheme.textColor.opacity(0.1), radius: 3, x: 0, y: 2)
        )
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Settings")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.currentTheme.textColor)
                        
                        Text("Manage your account, family, and preferences")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Settings Sections Grid
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(settingsSections) { section in
                            NavigationLink(destination: destinationView(for: section.destination)) {
                                SettingsSectionCard(section: section)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 80)
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.textColor)
                }
            }
        }
    }
    
    private var settingsSections: [SettingsSection] {
        [
            SettingsSection(
                title: "Account",
                icon: "person.crop.circle",
                description: "Profile, subscription, and account details",
                color: .blue,
                destination: .account,
                itemCount: nil
            ),
            SettingsSection(
                title: "Security",
                icon: "shield.lefthalf.filled",
                description: "Password, authentication, and privacy",
                color: .red,
                destination: .security,
                itemCount: nil
            ),
            SettingsSection(
                title: "Preferences",
                icon: "slider.horizontal.3",
                description: "App settings, themes, and display options",
                color: .purple,
                destination: .preferences,
                itemCount: nil
            ),
            SettingsSection(
                title: "Daycare",
                icon: "building.2",
                description: "Daycare providers and childcare information",
                color: .green,
                destination: .daycare,
                itemCount: viewModel.daycareProviders.count
            ),
            SettingsSection(
                title: "Sitters",
                icon: "person.2",
                description: "Babysitters and emergency contacts",
                color: .orange,
                destination: .sitters,
                itemCount: viewModel.babysitters.count + viewModel.emergencyContacts.count
            ),
            SettingsSection(
                title: "Schedules",
                icon: "calendar.badge.clock",
                description: "Schedule templates and routines",
                color: .indigo,
                destination: .schedules,
                itemCount: viewModel.scheduleTemplates.count
            ),
            SettingsSection(
                title: "Family",
                icon: "house.fill",
                description: "Coparents, children, and family members",
                color: .pink,
                destination: .family,
                itemCount: viewModel.coparents.count + viewModel.children.count + viewModel.otherFamilyMembers.count
            )
        ]
    }
    
    @ViewBuilder
    private func destinationView(for destination: SettingsDestination) -> some View {
        switch destination {
        case .account:
            AccountsView()
        case .security:
            SecuritySettingsView()
        case .preferences:
            PreferencesView(themeManager: themeManager).environmentObject(viewModel)
        case .daycare:
            DaycareView().environmentObject(viewModel)
        case .sitters:
            SittersView().environmentObject(viewModel)
        case .schedules:
            SchedulesView().environmentObject(viewModel)
        case .family:
            FamilyView().environmentObject(viewModel)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let themeManager = ThemeManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager, themeManager: themeManager)
        
        SettingsView(viewModel: calendarViewModel)
            .environmentObject(themeManager)
    }
} 