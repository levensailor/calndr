import SwiftUI

struct OnboardingStepTwoView: View {
    @State private var children: [OnboardingChild] = [OnboardingChild(name: "", dob: Date())]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAlert = false
    @State private var createdChildrenCount = 0

    var onNext: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack {
            Text("Add Your Children").font(.largeTitle).padding()
            
            ScrollView {
                VStack(spacing: 15) {
                    ForEach($children) { $child in
                        VStack(spacing: 10) {
                            FloatingLabelTextField(title: "Child's Name", text: $child.name, isSecure: false)
                                .autocapitalization(.words)
                            
                            HStack {
                                Text("Date of Birth:")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Spacer()
                                DatePicker("", selection: $child.dob, displayedComponents: .date)
                                    .labelsHidden()
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        children.append(OnboardingChild(name: "", dob: Date()))
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Another Child")
                        }
                        .foregroundColor(.blue)
                    }
                    .padding()
                }
            }
            .padding(.horizontal)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            HStack {
                Button(action: onSkip) {
                    Text("Skip")
                        .padding()
                }
                
                Spacer()
                
                Button(action: {
                    if hasValidChildren() {
                        createChildren()
                    } else {
                        onNext()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(hasValidChildren() ? "Add Children & Next" : "Next")
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isLoading)
            }
            .padding()
        }
        .padding()
        .alert("Children Added", isPresented: $showingAlert) {
            Button("OK") {
                onNext()
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            } else {
                Text("\(createdChildrenCount) children added successfully!")
            }
        }
    }
    
    private func hasValidChildren() -> Bool {
        return children.contains { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    private func createChildren() {
        isLoading = true
        errorMessage = nil
        createdChildrenCount = 0
        
        let validChildren = children.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        let group = DispatchGroup()
        var errors: [String] = []
        
        for child in validChildren {
            group.enter()
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dobString = dateFormatter.string(from: child.dob)
            
            // Split name into first and last name
            let nameParts = child.name.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ")
            let firstName = nameParts.first ?? ""
            let lastName = nameParts.count > 1 ? nameParts.dropFirst().joined(separator: " ") : ""
            
            APIService.shared.createChild(
                firstName: firstName,
                lastName: lastName,
                dob: dobString
            ) { result in
                switch result {
                case .success(_):
                    createdChildrenCount += 1
                case .failure(let error):
                    errors.append(error.localizedDescription)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            isLoading = false
            
            if !errors.isEmpty {
                errorMessage = "Some children could not be added: \(errors.joined(separator: ", "))"
            } else if createdChildrenCount > 0 {
                errorMessage = nil
            }
            
            showingAlert = true
        }
    }
}

struct OnboardingChild: Identifiable {
    let id = UUID()
    var name: String
    var dob: Date
}
