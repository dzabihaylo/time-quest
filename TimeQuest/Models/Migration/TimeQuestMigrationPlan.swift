import Foundation
@preconcurrency import SwiftData

enum TimeQuestMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [TimeQuestSchemaV1.self, TimeQuestSchemaV2.self, TimeQuestSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [v1ToV2, v2ToV3]
    }

    static let v1ToV2 = MigrationStage.lightweight(
        fromVersion: TimeQuestSchemaV1.self,
        toVersion: TimeQuestSchemaV2.self
    )

    static let v2ToV3 = MigrationStage.lightweight(
        fromVersion: TimeQuestSchemaV2.self,
        toVersion: TimeQuestSchemaV3.self
    )
}
