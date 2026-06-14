import Foundation

public enum BatchImportItemStatus: Equatable, Sendable {
    case pending
    case processing
    case complete
    case cancelled
    case failed(String)

    public var label: String {
        switch self {
        case .pending:
            return "Pending"
        case .processing:
            return "Processing"
        case .complete:
            return "Complete"
        case .cancelled:
            return "Cancelled"
        case .failed:
            return "Failed"
        }
    }
}

public struct BatchImportItem: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var url: URL
    public var status: BatchImportItemStatus
    public var document: ReaderDocument?

    public init(
        id: UUID = UUID(),
        url: URL,
        status: BatchImportItemStatus = .pending,
        document: ReaderDocument? = nil
    ) {
        self.id = id
        self.url = url
        self.status = status
        self.document = document
    }

    public var fileName: String {
        url.lastPathComponent
    }
}

public struct BatchImportQueue: Equatable, Sendable {
    public private(set) var items: [BatchImportItem]

    public init(items: [BatchImportItem] = []) {
        self.items = items
    }

    public init(urls: [URL]) {
        self.items = urls
            .filter(Self.isSupportedURL)
            .map { BatchImportItem(url: $0) }
    }

    public var pendingItem: BatchImportItem? {
        items.first { $0.status == .pending }
    }

    public var isActive: Bool {
        items.contains { $0.status == .pending || $0.status == .processing }
    }

    public var completedCount: Int {
        items.filter { $0.status == .complete }.count
    }

    public var failedCount: Int {
        items.filter {
            if case .failed = $0.status {
                return true
            }
            return false
        }.count
    }

    public var totalCount: Int {
        items.count
    }

    public var completedDocuments: [ReaderDocument] {
        items.compactMap(\.document)
    }

    public mutating func append(urls: [URL]) {
        items.append(contentsOf: urls.filter(Self.isSupportedURL).map { BatchImportItem(url: $0) })
    }

    public mutating func markProcessing(_ id: UUID) {
        update(id) { item in
            item.status = .processing
        }
    }

    public mutating func markCompleted(_ id: UUID, document: ReaderDocument) {
        update(id) { item in
            item.status = .complete
            item.document = document
        }
    }

    public mutating func markFailed(_ id: UUID, message: String) {
        update(id) { item in
            item.status = .failed(message)
            item.document = nil
        }
    }

    public mutating func cancelActiveAndPendingItems() {
        for index in items.indices {
            switch items[index].status {
            case .pending, .processing:
                items[index].status = .cancelled
                items[index].document = nil
            case .complete, .cancelled, .failed:
                break
            }
        }
    }

    public func item(with id: UUID) -> BatchImportItem? {
        items.first { $0.id == id }
    }

    public static func isSupportedURL(_ url: URL) -> Bool {
        DocumentProcessor.supportedExtensions.contains(url.pathExtension.lowercased())
    }

    private mutating func update(_ id: UUID, mutate: (inout BatchImportItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }
        mutate(&items[index])
    }
}
