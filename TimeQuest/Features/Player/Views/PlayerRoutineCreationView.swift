import SwiftUI
import SwiftData

struct PlayerRoutineCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PlayerRoutineCreationViewModel
    @State private var showError = false
    @State private var errorMessage = ""

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: PlayerRoutineCreationViewModel(modelContext: modelContext))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step indicator
                stepIndicator
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                // Step content
                Group {
                    switch viewModel.currentStep {
                    case .chooseTemplate:
                        templateStep
                    case .nameQuest:
                        nameStep
                    case .addTasks:
                        tasksStep
                    case .chooseDays:
                        daysStep
                    case .review:
                        reviewStep
                    }
                }
                .frame(maxHeight: .infinity)

                // Bottom action button
                if viewModel.currentStep != .chooseTemplate {
                    bottomButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                }
            }
            .navigationTitle("Create Quest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if viewModel.currentStep == .chooseTemplate {
                        Button("Cancel") { dismiss() }
                    } else {
                        Button {
                            viewModel.previousStep()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alert("Something went wrong", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(PlayerRoutineCreationViewModel.CreationStep.allCases, id: \.rawValue) { step in
                Capsule()
                    .fill(step.rawValue <= viewModel.currentStep.rawValue ? Color.accentColor : Color(.systemGray4))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 1: Choose Template

    private var templateStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Pick a starter quest")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 8)

                Text("Choose a template to start with, or build your own from scratch")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    ForEach(RoutineTemplateProvider.templates) { template in
                        templateCard(template)
                    }

                    // Custom option
                    Button {
                        viewModel.startFromScratch()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .foregroundStyle(.purple)
                                .frame(width: 40, height: 40)
                                .background(Color.purple.opacity(0.1))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Custom Quest")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Start from scratch")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 24)
        }
    }

    private func templateCard(_ template: RoutineTemplate) -> some View {
        Button {
            viewModel.selectTemplate(template)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: templateIcon(for: template.name))
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(template.suggestedTasks.count) steps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func templateIcon(for name: String) -> String {
        switch name {
        case "homework": return "book.fill"
        case "friends_house": return "house.fill"
        case "activity_prep": return "figure.run"
        default: return "star.fill"
        }
    }

    // MARK: - Step 2: Name Quest

    private var nameStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Name your quest")
                .font(.title2)
                .fontWeight(.bold)

            Text("Pick a name that makes you excited to start")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Quest name", text: $viewModel.editState.displayName)
                .font(.title3)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Step 3: Add Tasks

    private var tasksStep: some View {
        VStack(spacing: 16) {
            Text("Add your steps")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 8)

            Text("What do you need to do? You can add up to 10 steps.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            List {
                ForEach(viewModel.editState.tasks.indices, id: \.self) { index in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.accentColor)
                            .clipShape(Circle())

                        TextField("Step name", text: $viewModel.editState.tasks[index].displayName)
                    }
                }
                .onMove(perform: viewModel.moveTask)
                .onDelete { offsets in
                    viewModel.removeTask(at: offsets)
                }

                if viewModel.editState.tasks.count < 10 {
                    Button {
                        viewModel.addTask()
                    } label: {
                        Label("Add Step", systemImage: "plus.circle")
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    // MARK: - Step 4: Choose Days

    private var daysStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Pick your days")
                .font(.title2)
                .fontWeight(.bold)

            Text("Which days do you want to do this quest?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            SchedulePickerView(activeDays: $viewModel.editState.activeDays)
                .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Step 5: Review

    private var reviewStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Ready to go!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 8)

                // Quest name
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.orange)
                        Text(viewModel.editState.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }

                // Tasks summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Steps")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    ForEach(viewModel.editState.tasks.indices, id: \.self) { index in
                        let task = viewModel.editState.tasks[index]
                        if !task.displayName.trimmingCharacters(in: .whitespaces).isEmpty {
                            HStack(spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Color.accentColor)
                                    .clipShape(Circle())

                                Text(task.displayName)
                                    .font(.body)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)

                // Days summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Days")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    Text(formatActiveDays(viewModel.editState.activeDays))
                        .font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        Button {
            if viewModel.currentStep == .review {
                saveAndDismiss()
            } else {
                viewModel.nextStep()
            }
        } label: {
            Text(viewModel.currentStep == .review ? "Create Quest!" : "Next")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(viewModel.canProceed ? Color.accentColor : Color(.systemGray3))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!viewModel.canProceed)
    }

    // MARK: - Actions

    private func saveAndDismiss() {
        do {
            try viewModel.saveQuest()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Helpers

    private func formatActiveDays(_ days: [Int]) -> String {
        let sorted = days.sorted()
        if sorted == [2, 3, 4, 5, 6] { return "Weekdays" }
        if sorted == [1, 7] { return "Weekends" }
        if sorted == Array(1...7) { return "Every day" }

        let symbols = Calendar.current.shortWeekdaySymbols
        return sorted.map { symbols[$0 - 1] }.joined(separator: ", ")
    }
}
