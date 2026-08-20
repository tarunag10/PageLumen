import Foundation
import SwiftData

/// The schema is deliberately explicit so additive SwiftData changes cannot
/// silently rely on inferred migrations in a release build.
@available(macOS 14.0, *)
public enum PageLumenSchemaV1: VersionedSchema {
    public static var versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [PersistedDocument.self]
    }

    @Model
    public final class PersistedDocument {
        @Attribute(.unique) public var id: UUID
        public var title: String
        public var createdAt: Date
        public var lastOpened: Date
        public var pageCount: Int
        public var sourceType: String
        public var jsonData: Data

        public init(id: UUID, title: String, createdAt: Date, lastOpened: Date, pageCount: Int, sourceType: String, jsonData: Data) {
            self.id = id
            self.title = title
            self.createdAt = createdAt
            self.lastOpened = lastOpened
            self.pageCount = pageCount
            self.sourceType = sourceType
            self.jsonData = jsonData
        }
    }
}

@available(macOS 14.0, *)
public enum PageLumenSchemaV2: VersionedSchema {
    public static var versionIdentifier = Schema.Version(2, 0, 0)
    public static var models: [any PersistentModel.Type] { [PersistedDocument.self] }
}

@available(macOS 14.0, *)
public enum PageLumenMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [PageLumenSchemaV1.self, PageLumenSchemaV2.self]
    }

    public static var stages: [MigrationStage] {
        [.lightweight(fromVersion: PageLumenSchemaV1.self, toVersion: PageLumenSchemaV2.self)]
    }
}
