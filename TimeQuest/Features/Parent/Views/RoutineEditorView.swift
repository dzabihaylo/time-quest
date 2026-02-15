import SwiftUI
import SwiftData

struct RoutineEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppDependencies.self) private var dependencies

    @State private var viewModel: RoutineEditorViewModel
    @State private var editingTaskIndex: Int?
    @State private var showingPlaylistPicker = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let repository: RoutineRepositoryProtocol

    init(routine: Routine?, repository: RoutineRepositoryProtocol, modelContext: ModelContext) {
        self.repository = repository
        _viewModel = State(initialValue: RoutineEditorViewModel(
            routine: routine,
            repository: repository,
            modelContext: modelContext
        ))
    }

    var body: some View {
        Form {
            namesSection
            scheduleSection
            calendarModeSection
            if dependencies.spotifyAuthManager.isConnected {
                spotifyPlaylistSection
            }
            tasksSection
        }
        .navigationTitle(viewModel.isNewRoutine ? "New Routine" : "Edit Routine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveRoutine()
                }
                .disabled(!viewModel.canSave)
                .fontWeight(.semibold)
            }
        }
        .sheet(item: $editingTaskIndex) { index in
            if index < viewModel.editState.tasks.count {
                TaskEditorView(task: $viewModel.editState.tasks[index])
            }
        }
        .sheet(isPresented: $showingPlaylistPicker) {
            PlaylistPickerView(
                selectedPlaylistID: $viewModel.editState.spotifyPlaylistID,
                selectedPlaylistName: $viewModel.editState.spotifyPlaylistName
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Sections

    private var namesSection: some View {
        Section {
            TextField("e.g., School Morning", text: $viewModel.editState.name)
            TextField("e.g., Morning Quest", text: $viewModel.editState.displayName)
        } header: {
            Text("Names")
        } footer: {
            Text("The quest name is what the player sees")
        }
    }

    private var scheduleSection: some View {
        Section("Schedule") {
            SchedulePickerView(activeDays: $viewModel.editState.activeDays)
        }
    }

    private var calendarModeSection: some View {
        Section {
            Picker("Calendar Mode", selection: $viewModel.editState.calendarModeRaw) {
                Text("Always").tag("always")
                Text("School Days Only").tag("schoolDayOnly")
                Text("Free Days Only").tag("freeDayOnly")
            }
        } header: {
            Text("Calendar Mode")
        } footer: {
            Text("Controls when this routine appears based on calendar context")
        }
    }

    private var spotifyPlaylistSection: some View {
        Section {
            if let playlistName = viewModel.editState.spotifyPlaylistName {
                HStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .foregroundStyle(.secondary)
                    Text(playlistName)
                }

                Button("Change Playlist") {
                    showingPlaylistPicker = true
                }

                Button("Remove Playlist", role: .destructive) {
                    viewModel.editState.spotifyPlaylistID = nil
                    viewModel.editState.spotifyPlaylistName = nil
                }
            } else {
                Button("Link a Playlist") {
                    showingPlaylistPicker = true
                }
            }
        } header: {
            Text("Spotify Playlist")
        }
    }

    private var tasksSection: some View {
        Section {
            ForEach(viewModel.editState.tasks.indices, id: \.self) { index in
                taskRow(index: index)
            }
            .onMove(perform: viewModel.moveTask)
            .onDelete(perform: viewModel.removeTask)

            Button {
                viewModel.addTask()
                editingTaskIndex = viewModel.editState.tasks.count - 1
            } label: {
                Label("Add Task", systemImage: "plus.circle")
            }
        } header: {
            HStack {
                Text("Tasks")
                Spacer()
                EditButton()
                    .font(.caption)
            }
        } footer: {
            if viewModel.editState.tasks.isEmpty {
                Text("Add at least one task to save")
            }
        }
    }

    private func taskRow(index: Int) -> some View {
        Button {
            editingTaskIndex = index
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                let task = viewModel.editState.tasks[index]
                if !task.displayName.isEmpty {
                    Text(task.displayName)
                        .font(.body)
                        .foregroundStyle(.primary)
                } else {
                    Text("Untitled step")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .italic()
                }

                if !task.name.isEmpty {
                    Text(task.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let duration = task.referenceDurationSeconds {
                    Text("~\(TimeFormatting.formatDuration(TimeInterval(duration)))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Actions

    private func saveRoutine() {
        do {
            try viewModel.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Int Identifiable for sheet binding

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}
