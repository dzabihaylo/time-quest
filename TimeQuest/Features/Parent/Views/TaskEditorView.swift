import SwiftUI

struct TaskEditorView: View {
    @Binding var task: TaskEditState
    @Environment(\.dismiss) private var dismiss

    @State private var showDuration = false
    @State private var durationMinutes = 0
    @State private var durationSeconds = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g., Take a shower", text: $task.name)
                    TextField("e.g., Shower Power", text: $task.displayName)
                } header: {
                    Text("Task Names")
                } footer: {
                    Text("The quest step name is what the player sees")
                }

                Section {
                    Toggle("I know roughly how long this takes", isOn: $showDuration)

                    if showDuration {
                        HStack {
                            Picker("Minutes", selection: $durationMinutes) {
                                ForEach(0...60, id: \.self) { min in
                                    Text("\(min) min").tag(min)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 120)

                            Picker("Seconds", selection: $durationSeconds) {
                                ForEach(0...59, id: \.self) { sec in
                                    Text("\(sec) sec").tag(sec)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 120)
                        }
                        .frame(height: 120)
                    }
                } header: {
                    Text("Reference Duration")
                } footer: {
                    Text("This is hidden from the player -- it's just for your reference")
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let duration = task.referenceDurationSeconds {
                    showDuration = true
                    durationMinutes = duration / 60
                    durationSeconds = duration % 60
                } else {
                    showDuration = false
                }
            }
            .onChange(of: showDuration) { _, isOn in
                if isOn {
                    let total = durationMinutes * 60 + durationSeconds
                    task.referenceDurationSeconds = total > 0 ? total : nil
                } else {
                    task.referenceDurationSeconds = nil
                }
            }
            .onChange(of: durationMinutes) { _, _ in
                if showDuration {
                    let total = durationMinutes * 60 + durationSeconds
                    task.referenceDurationSeconds = total > 0 ? total : nil
                }
            }
            .onChange(of: durationSeconds) { _, _ in
                if showDuration {
                    let total = durationMinutes * 60 + durationSeconds
                    task.referenceDurationSeconds = total > 0 ? total : nil
                }
            }
        }
    }
}
