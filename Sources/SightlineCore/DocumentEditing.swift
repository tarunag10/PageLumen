import Foundation

public enum BlockMoveDirection: Sendable {
    case up
    case down
}

public enum DocumentEditing {
    public static func moveBlock(id: UUID, direction: BlockMoveDirection, in document: inout ReaderDocument) {
        guard let pageIndex = document.pages.firstIndex(where: { page in
            page.blocks.contains(where: { $0.id == id })
        }),
        let blockIndex = document.pages[pageIndex].blocks.firstIndex(where: { $0.id == id }) else {
            return
        }

        let destinationIndex: Int
        switch direction {
        case .up:
            destinationIndex = max(blockIndex - 1, 0)
        case .down:
            destinationIndex = min(blockIndex + 1, document.pages[pageIndex].blocks.count - 1)
        }

        guard destinationIndex != blockIndex else {
            return
        }

        document.pages[pageIndex].blocks.swapAt(blockIndex, destinationIndex)
        renumberBlocks(on: &document.pages[pageIndex])
    }

    public static func fullText(for document: ReaderDocument, includeHeadersAndFooters: Bool) -> String {
        document.pages
            .flatMap { exportableBlocks(on: $0, includeHeadersAndFooters: includeHeadersAndFooters) }
            .map(\.text)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
    }

    public static func exportableBlocks(on page: ReaderPage, includeHeadersAndFooters: Bool) -> [TextBlock] {
        let sorted = page.blocks.sorted { lhs, rhs in
            lhs.readingOrderIndex < rhs.readingOrderIndex
        }

        if includeHeadersAndFooters {
            return sorted
        }

        return sorted.filter { block in
            block.type != .header && block.type != .footer
        }
    }

    public static func renumberBlocks(on page: inout ReaderPage) {
        for index in page.blocks.indices {
            page.blocks[index].readingOrderIndex = index
        }
    }
}
