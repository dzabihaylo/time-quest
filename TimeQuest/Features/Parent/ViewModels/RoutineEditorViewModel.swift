import Foundation
import SwiftData

// MARK: - Value-Type Edit State

/// Struct copy of routine data. Prevents SwiftData auto-save surprises.
/// The @Model is only mutated when save() is explicitly called.
struct RoutineEditState {
    var name: String
    var displayName: String
    var activeDays: [Int]  // 1=Sun through 7=Sat
    var isActive: Bool
    var tasks: [TaskEditState]

    static var `default`: RoutineEditState {
        RoutineEditState(
            name: "",
            displayName: "",
            activeDays: [2, 3, 4, 5, 6],  // Weekdays
            isActive: true,
            tasks: []
        )
    }
}

/// Struct copy of task data for editing.
struct TaskEditState: Identifiable {
    let id: UUID
    var name: String
    var displayName: String
    var referenceDurationSeconds: Int?
    var orderIndex: Int

    init(
        id: UUID = UUID(),
        name: String = "",
        displayName: String = "",
        referenceDurationSeconds: Int? = nil,
        orderIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.referenceDurationSeconds = referenceDurationSeconds
        self.orderIndex = orderIndex
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class RoutineEditorViewModel {
    var editState: RoutineEditState

    /// Reference to existing routine (nil for new)
    private let existingRoutine: Routine?
    private let repository: RoutineRepositoryProtocol
    private let modelContext: ModelContext

    var isNewRoutine: Bool { existingRoutine == nil }

    var canSave: Bool {
        !editState.name.trimmingCharacters(in: .whitespaces).isEmpty
        && !editState.displayName.trimmingCharacters(in: .whitespaces).isEmpty
        && editState.tasks.contains { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty
            && !$0.displayName.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    init(routine: Routine?, repository: RoutineRepositoryProtocol, modelContext: ModelContext) {
        self.existingRoutine = routine
        self.repository = repository
        self.modelContext = modelContext

        if let routine {
            self.editState = RoutineEditState(
                name: routine.name,
                displayName: routine.displayName,
                activeDays: routine.activeDays,
                isActive: routine.isActive,
                tasks: routine.orderedTasks.map { task in
                    TaskEditState(
                        id: UUID(),
                        name: task.name,
                        displayName: task.displayName,
                        referenceDurationSeconds: task.referenceDurationSeconds,
                        orderIndex: task.orderIndex
                    )
                }
            )
        } else {
            self.editState = .default
        }
    }

    // MARK: - Task Management

    func addTask() {
        let nextIndex = editState.tasks.count
        let newTask = TaskEditState(orderIndex: nextIndex)
        editState.tasks.append(newTask)
    }

    func removeTask(at offsets: IndexSet) {
        editState.tasks.remove(atOffsets: offsets)
        reindexTasks()
    }

    func moveTask(from source: IndexSet, to destination: Int) {
        editState.tasks.move(fromOffsets: source, toOffset: destination)
        reindexTasks()
    }

    private func reindexTasks() {
        for i in editState.tasks.indices {
            editState.tasks[i].orderIndex = i
        }
    }

    // MARK: - Save

    func save() throws {
        if let routine = existingRoutine {
            try updateExisting(routine)
        } else {
            try createNew()
        }
    }

    private func createNew() throws {
        let routine = Routine(
            name: editState.name.trimmingCharacters(in: .whitespaces),
            displayName: editState.displayName.trimmingCharacters(in: .whitespaces),
            activeDays: editState.activeDays,
            isActive: editState.isActive
        )
        // Insert BEFORE relating (SwiftData pitfall)
        modelContext.insert(routine)

        for taskState in editState.tasks where !taskState.name.trimmingCharacters(in: .whitespaces).isEmpty {
            let task = RoutineTask(
                name: taskState.name.trimmingCharacters(in: .whitespaces),
                displayName: taskState.displayName.trimmingCharacters(in: .whitespaces),
                referenceDurationSeconds: taskState.referenceDurationSeconds,
                orderIndex: taskState.orderIndex
            )
            modelContext.insert(task)
            task.routine = routine
        }

        try modelContext.save()
    }

    private func updateExisting(_ routine: Routine) throws {
        routine.name = editState.name.trimmingCharacters(in: .whitespaces)
        routine.displayName = editState.displayName.trimmingCharacters(in: .whitespaces)
        routine.activeDays = editState.activeDays
        routine.isActive = editState.isActive
        routine.updatedAt = .now

        // Remove old tasks
        for task in routine.tasks {
            modelContext.delete(task)
        }

        // Add tasks from edit state
        for taskState in editState.tasks where !taskState.name.trimmingCharacters(in: .whitespaces).isEmpty {
            let task = RoutineTask(
                name: taskState.name.trimmingCharacters(in: .whitespaces),
                displayName: taskState.displayName.trimmingCharacters(in: .whitespaces),
                referenceDurationSeconds: taskState.referenceDurationSeconds,
                orderIndex: taskState.orderIndex
            )
            modelContext.insert(task)
            task.routine = routine
        }

        try modelContext.save()
    }

    // MARK: - Display Name Suggestions

    static let displayNameSuggestions = [
        "Morning Quest",
        "Adventure Time",
        "Launch Sequence",
        "Daily Mission",
        "Power Up",
        "Ready Set Go",
    ]
}
