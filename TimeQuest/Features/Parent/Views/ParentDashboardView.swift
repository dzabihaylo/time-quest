import SwiftUI

struct ParentDashboardView: View {
    @Environment(RoleState.self) private var roleState

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("Routines will appear here")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Setup")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        roleState.exitParentMode()
                    }
                }
            }
        }
    }
}
