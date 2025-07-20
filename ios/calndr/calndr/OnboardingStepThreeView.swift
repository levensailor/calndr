import SwiftUI

struct OnboardingStepThreeView: View {
    @State private var selectedDays: [String: Int] = [
        "Monday": 0,
        "Tuesday": 0,
        "Wednesday": 0,
        "Thursday": 0,
        "Friday": 0,
        "Saturday": 0,
        "Sunday": 0
    ]
    
    @State private var parentNames = ["Parent 1", "Parent 2"]
    @State private var showingCustomNames = false
    @State private var customParent1Name = ""
    @State private var customParent2Name = ""
    
    var onComplete: () -> Void
    
    private let daysOfWeek = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Set Your Custody Schedule")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Text("Choose which parent has custody on each day of the week")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Parent Names Section
                VStack(spacing: 15) {
                    Text("Parent Names")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack {
                        Button(action: {
                            showingCustomNames.toggle()
                        }) {
                            HStack {
                                Image(systemName: "person.2")
                                Text("\(parentNames[0]) & \(parentNames[1])")
                                Image(systemName: "pencil")
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal)
                
                // Weekly Schedule Section
                VStack(spacing: 15) {
                    Text("Weekly Schedule")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 12) {
                        ForEach(daysOfWeek, id: \.self) { day in
                            HStack {
                                Text(day)
                                    .font(.body)
                                    .frame(width: 100, alignment: .leading)
                                
                                Spacer()
                                
                                Picker("", selection: Binding(
                                    get: { selectedDays[day] ?? 0 },
                                    set: { selectedDays[day] = $0 }
                                )) {
                                    Text(parentNames[0]).tag(0)
                                    Text(parentNames[1]).tag(1)
                                    Text("Shared").tag(2)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 200)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Quick Setup Templates
                VStack(spacing: 15) {
                    Text("Quick Setup Templates")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 10) {
                        Button("Alternating Weeks") {
                            setAlternatingWeeks()
                        }
                        .buttonStyle(TemplateButtonStyle())
                        
                        Button("Weekdays/Weekends") {
                            setWeekdaysWeekends()
                        }
                        .buttonStyle(TemplateButtonStyle())
                    }
                    
                    HStack(spacing: 10) {
                        Button("Equal Split") {
                            setEqualSplit()
                        }
                        .buttonStyle(TemplateButtonStyle())
                        
                        Button("Clear All") {
                            clearSchedule()
                        }
                        .buttonStyle(TemplateButtonStyle(backgroundColor: .red))
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 30)
                
                // Complete Button
                Button(action: {
                    saveScheduleAndComplete()
                }) {
                    Text("Complete Setup")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .sheet(isPresented: $showingCustomNames) {
            NavigationView {
                VStack(spacing: 20) {
                    Text("Customize Parent Names")
                        .font(.headline)
                        .padding(.top)
                    
                    FloatingLabelTextField(title: "First Parent Name", text: $customParent1Name, isSecure: false)
                        .padding(.horizontal)
                    
                    FloatingLabelTextField(title: "Second Parent Name", text: $customParent2Name, isSecure: false)
                        .padding(.horizontal)
                    
                    Spacer()
                }
                .navigationBarItems(
                    leading: Button("Cancel") {
                        showingCustomNames = false
                    },
                    trailing: Button("Save") {
                        if !customParent1Name.isEmpty && !customParent2Name.isEmpty {
                            parentNames[0] = customParent1Name
                            parentNames[1] = customParent2Name
                        }
                        showingCustomNames = false
                    }
                )
            }
        }
        .onAppear {
            // Set default names if empty
            if customParent1Name.isEmpty {
                customParent1Name = parentNames[0]
            }
            if customParent2Name.isEmpty {
                customParent2Name = parentNames[1]
            }
        }
    }
    
    private func setAlternatingWeeks() {
        // Simple alternating pattern - this would be enhanced for actual alternating weeks
        for (index, day) in daysOfWeek.enumerated() {
            selectedDays[day] = index % 2
        }
    }
    
    private func setWeekdaysWeekends() {
        let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
        let weekends = ["Saturday", "Sunday"]
        
        for day in weekdays {
            selectedDays[day] = 0 // Parent 1 gets weekdays
        }
        for day in weekends {
            selectedDays[day] = 1 // Parent 2 gets weekends
        }
    }
    
    private func setEqualSplit() {
        selectedDays["Monday"] = 0
        selectedDays["Tuesday"] = 0
        selectedDays["Wednesday"] = 0
        selectedDays["Thursday"] = 1
        selectedDays["Friday"] = 1
        selectedDays["Saturday"] = 1
        selectedDays["Sunday"] = 0
    }
    
    private func clearSchedule() {
        for day in daysOfWeek {
            selectedDays[day] = 0
        }
    }
    
    private func saveScheduleAndComplete() {
        // Here you would typically save the schedule to the backend
        // For now, we'll just log it and complete the onboarding
        print("Custody Schedule:")
        for day in daysOfWeek {
            let parentIndex = selectedDays[day] ?? 0
            let parentName = parentIndex == 2 ? "Shared" : parentNames[parentIndex]
            print("\(day): \(parentName)")
        }
        
        onComplete()
    }
}

struct TemplateButtonStyle: ButtonStyle {
    var backgroundColor: Color = .blue
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundColor.opacity(configuration.isPressed ? 0.7 : 1.0))
            .cornerRadius(6)
    }
}
