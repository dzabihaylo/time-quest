import Foundation

struct RoutineTemplate: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let displayName: String
    let suggestedTasks: [String]
    let suggestedDays: [Int]
}

struct RoutineTemplateProvider: Sendable {
    static let templates: [RoutineTemplate] = [
        RoutineTemplate(
            name: "homework",
            displayName: "Homework Quest",
            suggestedTasks: ["Get supplies ready", "Work on assignment", "Pack up"],
            suggestedDays: [2, 3, 4, 5, 6]
        ),
        RoutineTemplate(
            name: "friends_house",
            displayName: "Friend's House Prep",
            suggestedTasks: ["Pick what to bring", "Get dressed", "Pack bag"],
            suggestedDays: Array(1...7)
        ),
        RoutineTemplate(
            name: "activity_prep",
            displayName: "Activity Prep",
            suggestedTasks: ["Gather gear", "Get changed", "Fill water bottle"],
            suggestedDays: [2, 3, 4, 5, 6]
        ),
    ]
}
