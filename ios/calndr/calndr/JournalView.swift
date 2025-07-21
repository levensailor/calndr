import SwiftUI

struct JournalView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAddEntry = false
    @State private var showingEditEntry = false
    @State private var selectedEntry: JournalEntry?
    @State private var searchText = ""
    @State private var hasCheckedForAutoOpen = false
    @State private var showPlusButtonHighlight = false
    
    var filteredEntries: [JournalEntry] {
        if searchText.isEmpty {
            return viewModel.journalEntries
        } else {
            return viewModel.journalEntries.filter { entry in
                entry.content.localizedCaseInsensitiveContains(searchText) ||
                entry.title?.localizedCaseInsensitiveContains(searchText) == true ||
                entry.author_name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.journalEntries.isEmpty {
                    EmptyJournalView(onAddEntry: {
                        showingAddEntry = true
                    })
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredEntries) { entry in
                                JournalEntryCard(entry: entry) {
                                    selectedEntry = entry
                                    showingEditEntry = true
                                }
                                .environmentObject(themeManager)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    .searchable(text: $searchText, prompt: "Search journal entries...")
                }
            }
            .background(themeManager.currentTheme.mainBackgroundColorSwiftUI)
            .navigationTitle("Family Journal")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddEntry = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(themeManager.currentTheme.iconColorSwiftUI)
                            .scaleEffect(showPlusButtonHighlight ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: showPlusButtonHighlight)
                    }
                }
            }
        }
        .themeNavigationBar(themeManager: themeManager)
        .onAppear {
            viewModel.fetchJournalEntries()
        }
        .onChange(of: viewModel.journalEntries) { entries in
            // Auto-open add entry modal if journal is empty and we haven't checked yet
            if !hasCheckedForAutoOpen && entries.isEmpty {
                hasCheckedForAutoOpen = true
                // Create animation sequence that looks like it's coming from the + button
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // First, highlight the + button
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showPlusButtonHighlight = true
                    }
                    
                    // Then show the modal after a brief pause
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showPlusButtonHighlight = false
                        }
                        showingAddEntry = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddEntry) {
            AddEditJournalEntryView(viewModel: viewModel, isEditing: false)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingEditEntry) {
            if let entry = selectedEntry {
                AddEditJournalEntryView(viewModel: viewModel, isEditing: true, existingEntry: entry)
                    .environmentObject(themeManager)
            }
        }
    }
}

struct EmptyJournalView: View {
    let onAddEntry: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(themeManager.currentTheme.iconColorSwiftUI.opacity(0.5))
            
            VStack(spacing: 12) {
                Text("No Journal Entries Yet")
                    .font(.title2.bold())
                    .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                
                Text("Start capturing your family memories and daily moments by adding your first journal entry.")
                    .font(.body)
                    .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: onAddEntry) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("Create First Entry")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(themeManager.currentTheme.accentColor.color)
                .cornerRadius(8)
            }
            .scaleEffect(1.0)
            .animation(.easeInOut(duration: 0.1), value: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct JournalEntryCard: View {
    let entry: JournalEntry
    let onTap: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    private var displayDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = dateFormatter.date(from: entry.entry_date) else {
            return entry.entry_date
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        return displayFormatter.string(from: date)
    }
    
    private var displayTime: String {
        let isoFormatter = ISO8601DateFormatter()
        guard let date = isoFormatter.date(from: entry.created_at) else {
            return ""
        }
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        return timeFormatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title/date and author
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if let title = entry.title, !title.isEmpty {
                        Text(title)
                            .font(.headline.bold())
                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                    }
                    
                    Text(displayDate)
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.author_name)
                        .font(.caption.bold())
                        .foregroundColor(themeManager.currentTheme.iconColorSwiftUI)
                    
                    Text(displayTime)
                        .font(.caption2)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.5))
                }
            }
            
            // Content preview
            Text(entry.content)
                .font(.body)
                .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
        .cornerRadius(12)
        .onTapGesture {
            onTap()
        }
    }
}

struct AddEditJournalEntryView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    let isEditing: Bool
    let existingEntry: JournalEntry?
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var entryDate: Date = Date()
    @State private var isLoading = false
    @State private var showingDeleteAlert = false
    
    init(viewModel: CalendarViewModel, isEditing: Bool, existingEntry: JournalEntry? = nil) {
        self.viewModel = viewModel
        self.isEditing = isEditing
        self.existingEntry = existingEntry
        
        if let entry = existingEntry {
            _title = State(initialValue: entry.title ?? "")
            _content = State(initialValue: entry.content)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let date = dateFormatter.date(from: entry.entry_date) {
                _entryDate = State(initialValue: date)
            }
        }
    }
    
    private var canSave: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Date picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Entry Date")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                        
                        DatePicker("Entry Date", selection: $entryDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .accentColor(themeManager.currentTheme.iconColorSwiftUI)
                    }
                    
                    // Title field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title (Optional)")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                        
                        TextField("Enter a title for this entry...", text: $title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                    }
                    
                    // Content field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                        
                        TextEditor(text: $content)
                            .frame(minHeight: 200)
                            .padding(8)
                            .background(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                            .cornerRadius(8)
                            .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .background(themeManager.currentTheme.mainBackgroundColorSwiftUI)
            .navigationTitle(isEditing ? "Edit Entry" : "New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if isEditing {
                            Button("Delete") {
                                showingDeleteAlert = true
                            }
                            .foregroundColor(.red)
                        }
                        
                        Button(isEditing ? "Save" : "Add") {
                            saveEntry()
                        }
                        .disabled(!canSave || isLoading)
                        .foregroundColor(canSave ? themeManager.currentTheme.iconColorSwiftUI : .gray)
                    }
                }
            }
        }
        .alert("Delete Entry", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteEntry()
            }
        } message: {
            Text("Are you sure you want to delete this journal entry? This action cannot be undone.")
        }
    }
    
    private func saveEntry() {
        isLoading = true
        
        let titleToSave = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : title
        
        if isEditing, let entry = existingEntry {
            viewModel.updateJournalEntry(
                id: entry.id,
                title: titleToSave,
                content: content,
                entryDate: entryDate
            ) { success in
                isLoading = false
                if success {
                    dismiss()
                }
            }
        } else {
            viewModel.createJournalEntry(
                title: titleToSave,
                content: content,
                entryDate: entryDate
            ) { success in
                isLoading = false
                if success {
                    dismiss()
                }
            }
        }
    }
    
    private func deleteEntry() {
        guard let entry = existingEntry else { return }
        
        isLoading = true
        viewModel.deleteJournalEntry(id: entry.id) { success in
            isLoading = false
            if success {
                dismiss()
            }
        }
    }
}

struct JournalView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        let themeManager = ThemeManager()
        let calendarViewModel = CalendarViewModel(authManager: authManager, themeManager: themeManager)
        
        JournalView(viewModel: calendarViewModel)
            .environmentObject(themeManager)
    }
} 