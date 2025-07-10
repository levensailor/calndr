import SwiftUI

struct DaycareView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAddDaycare = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daycare")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.currentTheme.textColor)
                        
                        Text("Manage daycare providers and childcare information")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                    }
                    .padding(.horizontal)
                    
                    // Add Button
                    HStack {
                        Spacer()
                        Button(action: { showingAddDaycare = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Daycare Provider")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Daycare Providers List
                    if viewModel.daycareProviders.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "building.2")
                                .font(.largeTitle)
                                .foregroundColor(themeManager.currentTheme.textColor.opacity(0.3))
                            
                            Text("No daycare providers added yet")
                                .font(.headline)
                                .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                            
                            Text("Add your first daycare provider to get started")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.textColor.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    } else {
                        ForEach(viewModel.daycareProviders) { provider in
                            DaycareProviderCard(provider: provider)
                                .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 80)
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor)
        }
        .sheet(isPresented: $showingAddDaycare) {
            AddDaycareView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
    }
}

struct DaycareProviderCard: View {
    let provider: DaycareProvider
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "building.2")
                    .font(.title2)
                    .foregroundColor(.green)
                    .frame(width: 30, height: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.name)
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textColor)
                    
                    if let address = provider.address {
                        Text(address)
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                    }
                }
                
                Spacer()
            }
            
            if let hours = provider.hours {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                    
                    Text(hours)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                }
            }
            
            HStack {
                if let phone = provider.phoneNumber {
                    HStack {
                        Image(systemName: "phone")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                        
                        Text(phone)
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                    }
                }
                
                Spacer()
                
                if let email = provider.email {
                    HStack {
                        Image(systemName: "envelope")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                        
                        Text(email)
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textColor.opacity(0.7))
                    }
                }
            }
            
            if let notes = provider.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textColor.opacity(0.6))
                    .padding(.top, 4)
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

struct AddDaycareView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var address = ""
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var hours = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Daycare Information") {
                    FloatingLabelTextField(
                        title: "Daycare Name",
                        text: $name,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    
                    FloatingLabelTextField(
                        title: "Address (Optional)",
                        text: $address,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    
                    FloatingLabelTextField(
                        title: "Phone Number (Optional)",
                        text: $phoneNumber,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    .keyboardType(.phonePad)
                    
                    FloatingLabelTextField(
                        title: "Email (Optional)",
                        text: $email,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    
                    FloatingLabelTextField(
                        title: "Hours (Optional)",
                        text: $hours,
                        isSecure: false,
                        themeManager: themeManager
                    )
                    
                    FloatingLabelTextField(
                        title: "Notes (Optional)",
                        text: $notes,
                        isSecure: false,
                        themeManager: themeManager
                    )
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColor)
            .navigationTitle("Add Daycare Provider")
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

struct DaycareView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let themeManager = ThemeManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager, themeManager: themeManager)
        
        DaycareView()
            .environmentObject(calendarViewModel)
            .environmentObject(themeManager)
    }
} 