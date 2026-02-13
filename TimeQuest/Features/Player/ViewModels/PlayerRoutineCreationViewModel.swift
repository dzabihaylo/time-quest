import Foundation
import SwiftData

@MainActor
@Observable
final class PlayerRoutineCreationViewModel {

    // MARK: - Types

    enum CreationStep: Int, CaseIterable, Sendable {
        case chooseTemplate
        case nameQuest
        case addTasks
        case chooseDays
        case review
    }

    // MARK: - State

    var editState: RoutineEditState
    var currentStep: CreationStep = .chooseTemplate
    var selectedTemplate: RoutineTemplate?

    private let modelContext: ModelContext

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.editState = .default
    }

    // MARK: - Template Selection

    func selectTemplate(_ template: RoutineTemplate?) {
        selectedTemplate = template
        if let template {
            editState.displayName = template.displayName
            editState.name = template.displayName.lowercased()
            editState.activeDays = template.suggestedDays
            editState.tasks = template.suggestedTasks.enumerated().map { index, taskName in
                TaskEditState(
                    name: taskName.lowercased(),
                    displayName: taskName,
                    orderIndex: index
                )
            }
        } else {
            editState = .default
            editState.displayName = "My Quest"
            editState.name = "my quest"
            editState.tasks = [
                TaskEditState(name: "step 1", displayName: "Step 1", orderIndex: 0)
            ]
        }
        currentStep = .nameQuest
    }

    func startFromScratch() {
        selectTemplate(nil)
    }

    // MARK: - Navigation

    func nextStep() {
        guard let nextIndex = CreationStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = nextIndex
    }

    func previousStep() {
        guard let prevIndex = CreationStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prevIndex
    }

    // MARK: - Task Management

    func addTask() {
        guard editState.tasks.count < 10 else { return }
        let nextIndex = editState.tasks.count
        let newTask = TaskEditState(orderIndex: nextIndex)
        editState.tasks.append(newTask)
    }

    func removeTask(at offsets: IndexSet) {
        guard editState.tasks.count > 1 else { return }
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

    // MARK: - Validation

    var canProceed: Bool {
        switch currentStep {
        case .chooseTemplate:
            return true
        case .nameQuest:
            return !editState.displayName.trimmingCharacters(in: .whitespaces).isEmpty
        case .addTasks:
            let validTasks = editState.tasks.filter {
                !$0.displayName.trimmingCharacters(in: .whitespaces).isEmpty
            }
            return !validTasks.isEmpty && editState.tasks.count <= 10
        case .chooseDays:
            return !editState.activeDays.isEmpty
        case .review:
            return canSave
        }
    }

    var canSave: Bool {
        let nameValid = !editState.displayName.trimmingCharacters(in: .whitespaces).isEmpty
        let validTasks = editState.tasks.filter {
            !$0.displayName.trimmingCharacters(in: .whitespaces).isEmpty
        }
        let tasksValid = !validTasks.isEmpty && editState.tasks.count <= 10
        let daysValid = !editState.activeDays.isEmpty
        return nameValid && tasksValid && daysValid
    }

    // MARK: - Save

    func saveQuest() throws {
        let routine = Routine(
            name: editState.displayName.trimmingCharacters(in: .whitespaces).lowercased(),
            displayName: editState.displayName.trimmingCharacters(in: .whitespaces),
            activeDays: editState.activeDays,
            isActive: true,
            createdBy: "player"
        )
        modelContext.insert(routine)

        for taskState in editState.tasks where !taskState.displayName.trimmingCharacters(in: .whitespaces).isEmpty {
            let task = RoutineTask(
                name: taskState.displayName.trimmingCharacters(in: .whitespaces).lowercased(),
                displayName: taskState.displayName.trimmingCharacters(in: .whitespaces),
                referenceDurationSeconds: nil,
                orderIndex: taskState.orderIndex
            )
            modelContext.insert(task)
            task.routine = routine
        }

        try modelContext.save()
    }
}
