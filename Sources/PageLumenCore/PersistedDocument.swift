import Foundation
import SwiftData

@available(macOS 14.0, *)
@Model
public final class PersistedDocument {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var createdAt: Date
    public var lastOpened: Date
    public var pageCount: Int
    public var sourceType: String
    public var jsonData: Data
    public var storageRevision: Int?

    public init(
        id: UUID,
        title: String,
        createdAt: Date,
        lastOpened: Date,
        pageCount: Int,
        sourceType: String,
        jsonData: Data,
        storageRevision: Int = 2
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.lastOpened = lastOpened
        self.pageCount = pageCount
        self.sourceType = sourceType
        self.jsonData = jsonData
        self.storageRevision = storageRevision
    }
}
