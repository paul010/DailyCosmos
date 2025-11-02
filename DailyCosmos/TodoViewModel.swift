import Foundation
import Combine
import SwiftUI
import UserNotifications

@MainActor
final class TodoViewModel: ObservableObject {
    @Published var items: [TodoItem] = []
    @Published var newTitle: String = ""
    @Published var includeDueDate: Bool = false
    @Published var newDueDate: Date = Date()
    @Published var showAddSheet: Bool = false

    private let fileManager = FileManager.default
    private let documentsURL: URL
    private let notesURL: URL
    private let todoFileURL: URL

    init() {
        let documentDirectories = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        documentsURL = documentDirectories[0]
        notesURL = documentsURL.appendingPathComponent("Notes")
        todoFileURL = notesURL.appendingPathComponent("todo.json")

        createNotesDirectoryIfNeeded()
        loadItems()
        requestNotificationPermission()
    }

    func addManualItem() {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let dueDate = includeDueDate ? newDueDate : nil
        let item = TodoItem(title: trimmedTitle, dueDate: dueDate)

        items.append(item)
        scheduleNotification(for: item)
        resetNewItemFields()
        saveItems()
        showAddSheet = false
    }

    func toggleCompletion(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }

        items[index].isCompleted.toggle()
        saveItems()
    }

    func deleteItems(at offsets: IndexSet) {
        let identifiers = offsets.map { items[$0].id.uuidString }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        items.remove(atOffsets: offsets)
        saveItems()
    }

    private func createNotesDirectoryIfNeeded() {
        do {
            try fileManager.createDirectory(at: notesURL, withIntermediateDirectories: true)
        } catch {
            print("Failed to create Notes directory: \(error)")
        }
    }

    private func loadItems() {
        guard fileManager.fileExists(atPath: todoFileURL.path) else { return }

        do {
            let data = try Data(contentsOf: todoFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decodedItems = try decoder.decode([TodoItem].self, from: data)
            items = decodedItems
        } catch {
            print("Failed to load to-do items: \(error)")
        }
    }

    func saveItems() {
        let sortedItems = items.sorted { lhs, rhs in
            switch (lhs.dueDate, rhs.dueDate) {
            case let (l?, r?):
                return l < r
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            default:
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }

        items = sortedItems

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(sortedItems)
            try data.write(to: todoFileURL, options: [.atomic])
        } catch {
            print("Failed to save to-do items: \(error)")
        }
    }

    private func resetNewItemFields() {
        newTitle = ""
        includeDueDate = false
        newDueDate = Date()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error {
                print("Notification authorization failed: \(error)")
            }
        }
    }

    private func scheduleNotification(for item: TodoItem) {
        guard let dueDate = item.dueDate, dueDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = "Time to complete your task!"
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
}
