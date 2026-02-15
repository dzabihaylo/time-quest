import Foundation
@preconcurrency import SwiftData

enum TimeQuestMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [TimeQuestSchemaV1.self, TimeQuestSchemaV2.self, TimeQuestSchemaV3.self, TimeQuestSchemaV4.self, TimeQuestSchemaV5.self, TimeQuestSchemaV6.self]
    }

    static var stages: [MigrationStage] {
        [v1ToV2, v2ToV3, v3ToV4, v4ToV5, v5ToV6]
    }

    static let v1ToV2 = MigrationStage.lightweight(
        fromVersion: TimeQuestSchemaV1.self,
        toVersion: TimeQuestSchemaV2.self
    )

    static let v2ToV3 = MigrationStage.lightweight(
        fromVersion: TimeQuestSchemaV2.self,
        toVersion: TimeQuestSchemaV3.self
    )

    static let v3ToV4 = MigrationStage.lightweight(
        fromVersion: TimeQuestSchemaV3.self,
        toVersion: TimeQuestSchemaV4.self
    )

    static let v4ToV5 = MigrationStage.lightweight(
        fromVersion: TimeQuestSchemaV4.self,
        toVersion: TimeQuestSchemaV5.self
    )

    static let v5ToV6 = MigrationStage.lightweight(
        fromVersion: TimeQuestSchemaV5.self,
        toVersion: TimeQuestSchemaV6.self
    )
}
