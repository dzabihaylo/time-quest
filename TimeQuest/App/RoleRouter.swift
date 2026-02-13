import SwiftUI

// MARK: - Role Types

enum AppRole {
    case player
    case parent
}

// MARK: - Role State

@Observable
final class RoleState {
    var currentRole: AppRole = .player
    var showingPINEntry = false

    func requestParentAccess() {
        showingPINEntry = true
    }

    func grantParentAccess() {
        showingPINEntry = false
        currentRole = .parent
    }

    func exitParentMode() {
        currentRole = .player
    }
}

// MARK: - Role Router View

struct RoleRouter: View {
    @State private var roleState = RoleState()

    var body: some View {
        Group {
            switch roleState.currentRole {
            case .player:
                PlayerHomeView()
            case .parent:
                ParentDashboardView()
            }
        }
        .environment(roleState)
        .sheet(isPresented: $roleState.showingPINEntry) {
            PINEntryView(onSuccess: {
                roleState.grantParentAccess()
            })
        }
    }
}
