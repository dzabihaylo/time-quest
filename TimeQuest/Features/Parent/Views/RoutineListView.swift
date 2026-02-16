import SwiftUI
import SwiftData

struct RoutineListView: View {
    @Query(filter: #Predicate<Routine> { $0.createdBy == "parent" }, sort: \Routine.createdAt)
    private var routines: [Routine]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.designTokens) private var tokens

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
                    .font(tokens.font(.headline))

                Text(routine.name)
                    .font(tokens.font(.caption))
                    .foregroundStyle(tokens.textSecondary)

                HStack(spacing: tokens.spacingSM) {
                    Text(formatActiveDays(routine.activeDays))
                        .font(tokens.font(.caption2))
                        .foregroundStyle(tokens.textSecondary)

                    Text("\(routine.orderedTasks.count) tasks")
                        .font(tokens.font(.caption2))
                        .foregroundStyle(tokens.textSecondary)
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
            let routine = routines[index]
            guard routine.createdBy == "parent" else { continue }
            modelContext.delete(routine)
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
