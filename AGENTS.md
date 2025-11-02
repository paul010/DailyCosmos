### Overview
I'll help you build this step by step. Since directly accessing the system's Apple Notes app storage programmatically isn't possible in a standard iOS app (due to sandboxing and privacy restrictions—Apple doesn't provide a public API for reading/writing Notes data without user interaction via sharing), I'll interpret "system's Notes folder" as a local folder within your app's Documents directory named "Notes". We'll store the to-do list as a JSON file (`todo.json`) there. This keeps it simple, persistent, and file-based.

The app will be a basic SwiftUI iOS app:
- **Step 1 (Basic App):** A list view for to-dos, manual add/edit/delete, with optional due dates. Data loads/saves automatically to the local "Notes" folder.
- **Step 2 (Gemini Integration):** A natural language input field that calls Google's Gemini 2.5 Flash API to parse input (e.g., "Move trash to road at 9:30 tomorrow") into structured JSON (title + due date), then adds it to the list.

**Prerequisites:**
- Xcode 16+ (for iOS 18+ compatibility).
- Get a free Google Gemini API key from [Google AI Studio](https://aistudio.google.com/app/apikey). Replace `YOUR_GEMINI_API_KEY` in the code.
- For reminders: We'll store due dates and optionally schedule local notifications using `UserNotifications`. Add `NSUserNotificationsUsageDescription` to your `Info.plist` for permission.
- Run on a physical device/simulator with internet for API calls.

**Project Setup:**
1. Create a new SwiftUI iOS app in Xcode.
2. Add these files: `TodoItem.swift`, `TodoViewModel.swift`.
3. Replace `ContentView.swift` with the code below.
4. In `TodoViewModel.swift`, replace the API key placeholder.

### Step 1: Basic To-Do List App
This handles UI, logic, and local storage.

#### TodoItem.swift
```swift
import Foundation

struct TodoItem: Codable, Identifiable {
    let id = UUID()
    var title: String
    var dueDate: Date?
    var isCompleted: Bool = false
    
    // Custom coding for JSON without id (generated on load)
    enum CodingKeys: String, CodingKey {
        case title, dueDate, isCompleted
    }
}
```

#### TodoViewModel.swift
```swift
import Foundation
import SwiftUI
import UserNotifications  // For scheduling reminders

@MainActor
class TodoViewModel: ObservableObject {
    @Published var items: [TodoItem] = []
    @Published var newTitle: String = ""
    @Published var newDueDate: Date? = nil
    @Published var showAddSheet = false
    
    private let fileManager = FileManager.default
    private let documentsURL: URL
    private let notesURL: URL
    private let todoFileURL: URL
    
    init() {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        documentsURL = paths[0]
        notesURL = documentsURL.appendingPathComponent("Notes")
        todoFileURL = notesURL.appendingPathComponent("todo.json")
        
        // Create Notes folder if needed
        try? fileManager.createDirectory(at: notesURL, withIntermediateDirectories: true)
        
        loadItems()
        requestNotificationPermission()
    }
    
    private func loadItems() {
        guard let data = try? Data(contentsOf: todoFileURL) else { return }
        if let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) {
            // Re-attach IDs if missing
            items = decoded.map { item in
                var newItem = item
                if newItem.id.uuidString.isEmpty { newItem.id = UUID() }
                return newItem
            }
        }
    }
    
    func saveItems() {
        // Sort by due date or title for consistency
        let sortedItems = items.sorted { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) }
        if let encoded = try? JSONEncoder().encode(sortedItems) {
            try? encoded.write(to: todoFileURL)
        }
    }
    
    func addManualItem() {
        guard !newTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let item = TodoItem(title: newTitle, dueDate: newDueDate)
        items.append(item)
        scheduleNotification(for: item)
        newTitle = ""
        newDueDate = nil
        saveItems()
        showAddSheet = false
    }
    
    func toggleCompletion(_ item: TodoItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isCompleted.toggle()
            saveItems()
        }
    }
    
    func deleteItem(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    private func scheduleNotification(for item: TodoItem) {
        guard let dueDate = item.dueDate else { return }
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = "Time to complete your task!"
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate), repeats: false)
        let request = UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // Step 2: Gemini Integration (see below)
    func addFromGemini(input: String) async {
        // Implementation added in Step 2
    }
}
```

#### ContentView.swift (Basic UI)
```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TodoViewModel()
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.items) { item in
                    HStack {
                        Button(action: { viewModel.toggleCompletion(item) }) {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(item.isCompleted ? .green : .gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        VStack(alignment: .leading) {
                            Text(item.title)
                                .strikethrough(item.isCompleted)
                            if let dueDate = item.dueDate {
                                Text(dueDate, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                }
                .onDelete(perform: viewModel.deleteItem)
            }
            .navigationTitle("To-Do List")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") { viewModel.showAddSheet = true }
                }
            }
            .sheet(isPresented: $viewModel.showAddSheet) {
                VStack(spacing: 20) {
                    Text("Add New Task")
                        .font(.headline)
                    
                    TextField("Title", text: $viewModel.newTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    DatePicker("Due Date (Optional)", selection: Binding(
                        get: { viewModel.newDueDate ?? Date() },
                        set: { viewModel.newDueDate = $0 }
                    ), displayedComponents: .hourAndMinute)
                    .datePickerStyle(CompactDatePickerStyle())
                    .disabled(viewModel.newDueDate == nil)
                    
                    Button("Add Task") {
                        viewModel.addManualItem()
                    }
                    .disabled(viewModel.newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    
                    Button("Cancel") { viewModel.showAddSheet = false }
                }
                .padding()
            }
        }
        .onChange(of: viewModel.items) { _ in
            viewModel.saveItems()
        }
    }
}

#Preview {
    ContentView()
}
```

**How it Works (Step 1):**
- **Storage:** Items save/load as JSON in `Documents/Notes/todo.json`. Folder auto-creates.
- **UI:** List shows tasks with checkboxes and due times. Swipe to delete. "+" button for manual add with optional time picker.
- **Logic:** Completions toggle, saves auto-trigger on changes. Notifications schedule if due date set (e.g., alert at 9:30).
- Test: Run the app, add items—they persist across launches.

### Step 2: Integrate Google's Gemini 2.5 Flash
Add a new section to the UI for natural language input. We'll call the Gemini API via `URLSession` to parse input into structured JSON.

#### Update TodoViewModel.swift (Add this function)
```swift
// Add to TodoViewModel class
@Published var naturalInput: String = ""
@Published var isProcessing = false

func addFromGemini(input: String) async {
    guard !input.trimmingCharacters(in: .whitespaces).isEmpty else { return }
    
    isProcessing = true
    defer { isProcessing = false }
    
    let apiKey = "YOUR_GEMINI_API_KEY"  // Replace with your key
    let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent")!
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
    
    let prompt = """
    Parse the following natural language into a to-do item. Extract:
    - title: A short, clear task title.
    - dueDate: ISO 8601 format (e.g., "2025-10-31T09:30:00Z") if a specific time/date is mentioned (like "tomorrow at 9:30"), else null.
    
    Respond ONLY with valid JSON: {"title": "string", "dueDate": "string or null"}
    
    Input: \(input)
    """
    
    let body: [String: Any] = [
        "contents": [
            [
                "parts": [
                    ["text": prompt]
                ]
            ]
        ]
    ]
    
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    
    do {
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let responseText = firstPart["text"] as? String else {
            print("Failed to parse Gemini response")
            return
        }
        
        // Parse the JSON from response text
        guard let jsonData = responseText.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(GeminiResponse.self, from: jsonData) else {
            print("Failed to parse structured JSON from Gemini")
            return
        }
        
        let dueDate: Date?
        if let dateString = parsed.dueDate, !dateString.isEmpty {
            dueDate = ISO8601DateFormatter().date(from: dateString)
        } else {
            dueDate = nil
        }
        
        let item = TodoItem(title: parsed.title, dueDate: dueDate)
        items.append(item)
        scheduleNotification(for: item)
        naturalInput = ""  // Clear input
        saveItems()
        
    } catch {
        print("Gemini API error: \(error)")
    }
}

// Helper struct for Gemini's parsed JSON
struct GeminiResponse: Codable {
    let title: String
    let dueDate: String?
}
```

#### Update ContentView.swift (Add Gemini Section)
Add this after the List in the NavigationStack body:
```swift
// Add this Section inside the List, e.g., at the top
Section("Quick Add with AI") {
    HStack {
        TextField("E.g., Move trash at 9:30 tomorrow", text: $viewModel.naturalInput)
            .onSubmit {
                Task { await viewModel.addFromGemini(input: viewModel.naturalInput) }
            }
        Button(action: {
            Task { await viewModel.addFromGemini(input: viewModel.naturalInput) }
        }) {
            if viewModel.isProcessing {
                ProgressView()
            } else {
                Image(systemName: "wand.and.stars")
            }
        }
        .disabled(viewModel.isProcessing || viewModel.naturalInput.trimmingCharacters(in: .whitespaces).isEmpty)
    }
}
```

**How it Works (Step 2):**
- **Input Example:** Type "Move the trash can to the side of the road at 9:30 tomorrow" and tap the wand icon (or submit).
- **API Call:** Sends a prompt to Gemini 2.5 Flash via POST. It extracts title/due date into JSON.
- **Parsing:** Decodes Gemini's response text as JSON, converts due date to `Date` (handles "tomorrow" via Gemini's understanding).
- **Auto-Add:** Inserts the item, schedules a notification if timed, and saves to file.
- **Error Handling:** Logs issues (check console). Rate limits apply (free tier: ~15 RPM).

**Testing:**
- Manual: Add a task with time—get a notification preview in simulator.
- AI: Input your example—Gemini should output ~{"title": "Move trash can to side of road", "dueDate": "2025-10-31T09:30:00Z"} (based on current date Oct 30, 2025).
- Storage: Quit/relaunch—data persists in Simulator's Documents/Notes/todo.json.

If you need enhancements (e.g., full EventKit for Reminders app sync, error UI, or macOS version), let me know!