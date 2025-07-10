//
//  PreferencesView.swift
//  calndr
//
//  Created by Levi Sailor on 10/7/23.
//

import SwiftUI

struct PreferenceItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let description: String
    let isToggle: Bool
    let toggleBinding: Binding<Bool>?
    let action: (() -> Void)?
    let activeColor: Color
    
    init(title: String, icon: String, description: String, isToggle: Bool = false, toggleBinding: Binding<Bool>? = nil, action: (() -> Void)? = nil, activeColor: Color = .blue) {
        self.title = title
        self.icon = icon
        self.description = description
        self.isToggle = isToggle
        self.toggleBinding = toggleBinding
        self.action = action
        self.activeColor = activeColor
    }
}

struct PreferenceRow: View {
    let item: PreferenceItem
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: item.icon)
                .font(.title2)
                .foregroundColor(item.isToggle && item.toggleBinding?.wrappedValue == true ? item.activeColor : themeManager.currentTheme.iconColor)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.textColor)
                
                Text(item.description)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
            }
            
            Spacer()
            
            if item.isToggle, let binding = item.toggleBinding {
                Toggle("", isOn: binding)
                    .labelsHidden()
            } else if let action = item.action {
                Button(action: action) {
                    Image(systemName: "chevron.right")
                        .font(.body)
                        .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct ThemeSpotlightView: View {
    let theme: Theme
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(theme.name)
                        .font(theme.font)
                        .foregroundColor(theme.textColor)
                        .font(.largeTitle)
                    
                    Button("Set Theme", action: action)
                        .buttonStyle(.borderedProminent)
                        .tint(theme.highlightColor)
                }
                
                Spacer()
                
                HStack(spacing: 0) {
                    theme.mainBackgroundColor
                        .frame(width: 40, height: 60)
                    theme.highlightColor
                        .frame(width: 20, height: 60)
                    theme.otherMonthBackgroundColor
                        .frame(width: 20, height: 60)
                }
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.textColor.opacity(0.5), lineWidth: 1)
                )
            }
            .padding()
            .background(theme.secondaryBackgroundColor)
            .cornerRadius(12)
        }
    }
}

struct ThemeSelectorView: View {
    @Binding var selectedTheme: Theme
    let themes: [Theme]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(themes) { theme in
                        Button(action: {
                            withAnimation {
                                selectedTheme = theme
                            }
                        }) {
                            Text(theme.name)
                                .font(.headline)
                                .padding()
                                .background(selectedTheme.id == theme.id ? Color.gray.opacity(0.3) : Color.clear)
                                .cornerRadius(8)
                        }
                        .id(theme.id)
                    }
                }
                .padding()
            }
            .onChange(of: selectedTheme) { _, newTheme in
                withAnimation {
                    proxy.scrollTo(newTheme.id, anchor: .center)
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo(selectedTheme.id, anchor: .center)
                }
            }
        }
    }
}

struct PreferencesView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var allowPastCustodyEditing = UserDefaults.standard.bool(forKey: "allowPastCustodyEditing")
    @State private var previewTheme: Theme

    init(themeManager: ThemeManager) {
        _previewTheme = State(initialValue: themeManager.currentTheme)
    }

    var body: some View {
        Form {
            // Features Section
            Section(header: Text("Features")) {
                ForEach(featurePreferences) { item in
                    PreferenceRow(item: item)
                }
            }
            
            // Theme Selection Section
            Section(header: Text("Themes")) {
                VStack {
                    ThemeSpotlightView(theme: previewTheme, action: {
                        themeManager.setTheme(to: previewTheme)
                        viewModel.saveThemePreference(themeName: previewTheme.name)
                    })
                    
                    ThemeSelectorView(selectedTheme: $previewTheme, themes: themeManager.themes)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Preferences")
        .background(themeManager.currentTheme.mainBackgroundColor)
        .onChange(of: allowPastCustodyEditing) { oldValue, newValue in
            UserDefaults.standard.set(newValue, forKey: "allowPastCustodyEditing")
        }
        .onAppear {
            self.previewTheme = themeManager.currentTheme
        }
    }
    
    // MARK: - Preference Items
    
    private var featurePreferences: [PreferenceItem] {
        [
            PreferenceItem(
                title: "Weather Effects",
                icon: "cloud.sun.fill",
                description: "Show weather and visual effects",
                isToggle: true,
                toggleBinding: $viewModel.showWeather,
                activeColor: .blue
            ),
            PreferenceItem(
                title: "School Events",
                icon: "graduationcap.fill",
                description: "Display school calendar",
                isToggle: true,
                toggleBinding: $viewModel.showSchoolEvents,
                activeColor: .green
            ),
            PreferenceItem(
                title: "Edit Past Custody",
                icon: "calendar.badge.clock",
                description: "Allow editing of past custody",
                isToggle: true,
                toggleBinding: $allowPastCustodyEditing,
                activeColor: .orange
            )
        ]
    }
} 