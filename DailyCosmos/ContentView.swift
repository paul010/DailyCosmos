//
//  ContentView.swift
//  DailyCosmos
//
//  Created by Paul on 2025/11/2.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TodoViewModel()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List {
                Section("Quick Add with Gemini") {
                    HStack {
                        TextField("Move trash tomorrow at 9:30", text: $viewModel.naturalInput)
                            .submitLabel(.done)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.sentences)
                            .onSubmit {
                                Task {
                                    await viewModel.addFromGemini(input: viewModel.naturalInput)
                                }
                            }

                        Button {
                            Task {
                                await viewModel.addFromGemini(input: viewModel.naturalInput)
                            }
                        } label: {
                            if viewModel.isProcessingNaturalInput {
                                ProgressView()
                            } else {
                                Image(systemName: "wand.and.stars")
                            }
                        }
                        .disabled(viewModel.naturalInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isProcessingNaturalInput)
                        .buttonStyle(.borderedProminent)
                    }

                    if let error = viewModel.naturalInputError {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }

                Section("Tasks") {
                    ForEach(viewModel.items) { item in
                        HStack(alignment: .center, spacing: 12) {
                            Button {
                                viewModel.toggleCompletion(item)
                            } label: {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isCompleted ? .green : .gray)
                                    .imageScale(.large)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.body)
                                    .foregroundColor(item.isCompleted ? .secondary : .primary)
                                    .strikethrough(item.isCompleted, pattern: .solid, color: .secondary)

                                if let dueDate = item.dueDate {
                                    Text(dueDate, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(dueDate, style: .time)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: viewModel.deleteItems)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("To-Do List")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Task")
                }
            }
            .overlay {
                if viewModel.items.isEmpty {
                    ContentUnavailableView("No Tasks", systemImage: "checklist", description: Text("Add a task to get started."))
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddSheet) {
            AddTaskSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

private struct AddTaskSheet: View {
    @ObservedObject var viewModel: TodoViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $viewModel.newTitle)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.sentences)
                }

                Section("Due Date") {
                    Toggle("Add due date", isOn: $viewModel.includeDueDate)
                    DatePicker("Reminder time", selection: $viewModel.newDueDate, displayedComponents: [.date, .hourAndMinute])
                        .disabled(!viewModel.includeDueDate)
                }
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        viewModel.showAddSheet = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        viewModel.addManualItem()
                    }
                    .disabled(viewModel.newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

private struct SettingsView: View {
    @AppStorage(StorageKeys.geminiAPIKey) private var geminiAPIKey: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Google Gemini") {
                    TextField("Gemini API Key", text: $geminiAPIKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .foregroundStyle(.primary)
                }

                Section {
                    Text("Add your Gemini 2.5 Flash API key from Google AI Studio so the app can parse natural-language tasks.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
