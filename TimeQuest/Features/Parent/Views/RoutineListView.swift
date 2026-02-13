import SwiftUI
import SwiftData

struct RoutineListView: View {
    @Query(sort: \Routine.createdAt) private var routines: [Routine]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if routines.isEmpty {
                emptyState
            } else {
                routineList
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Routines", systemImage: "list.bullet.clipboard")
        } description: {
            Text("Create your first routine to get started")
        }
    }

    private var routineList: some View {
        List {
            ForEach(routines) { routine in
                NavigationLink(value: routine.persistentModelID) {
                    routineRow(routine)
                }
            }
            .onDelete(perform: deleteRoutines)
        }
    }

    private func routineRow(_ routine: Routine) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(routine.displayName)
                    .font(.headline)

                Text(routine.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(formatActiveDays(routine.activeDays))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("\(routine.orderedTasks.count) tasks")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { routine.isActive },
                set: { newValue in
                    routine.isActive = newValue
                    routine.updatedAt = .now
                    try? modelContext.save()
                }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 2)
    }

    private func deleteRoutines(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(routines[index])
        }
        try? modelContext.save()
    }

    private func formatActiveDays(_ days: [Int]) -> String {
        let sorted = days.sorted()
        if sorted == [2, 3, 4, 5, 6] { return "Weekdays" }
        if sorted == [1, 7] { return "Weekends" }
        if sorted == Array(1...7) { return "Every day" }

        let symbols = Calendar.current.shortWeekdaySymbols
        return sorted.map { symbols[$0 - 1] }.joined(separator: ", ")
    }
}
