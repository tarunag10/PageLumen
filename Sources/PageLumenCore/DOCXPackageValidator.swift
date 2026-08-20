import Foundation

/// Deterministic checks for the required parts and relationships in a generated
/// Office Open XML package. Archive framing is deliberately supplied by the
/// caller so this contract remains usable by export tests without adding an
/// archive dependency to the core model target.
public struct DOCXPackageValidation: Equatable, Sendable {
    public enum IssueCode: String, Equatable, Sendable {
        case missingRequiredPart
        case invalidXML
        case invalidContentTypes
        case invalidRootRelationships
        case invalidDocumentRelationships
        case invalidDocumentPart
    }

    public let issues: [IssueCode]
    public var isValid: Bool { issues.isEmpty }

    public init(issues: [IssueCode] = []) { self.issues = issues }
}

public enum DOCXPackageValidator {
    private static let requiredParts = [
        "[Content_Types].xml", "_rels/.rels",
        "word/_rels/document.xml.rels", "word/document.xml"
    ]

    public static func validate(parts: [String: Data]) -> DOCXPackageValidation {
        var issues: [DOCXPackageValidation.IssueCode] = []
        guard requiredParts.allSatisfy({ parts[$0] != nil }) else {
            return DOCXPackageValidation(issues: [.missingRequiredPart])
        }

        let contentTypes = parts["[Content_Types].xml"]!
        let rootRelationships = parts["_rels/.rels"]!
        let documentRelationships = parts["word/_rels/document.xml.rels"]!
        let document = parts["word/document.xml"]!
        guard [contentTypes, rootRelationships, documentRelationships, document]
            .allSatisfy({ XMLParser(data: $0).parse() }) else {
            return DOCXPackageValidation(issues: [.invalidXML])
        }

        let contentTypesXML = String(decoding: contentTypes, as: UTF8.self)
        let rootRelationshipsXML = String(decoding: rootRelationships, as: UTF8.self)
        let documentRelationshipsXML = String(decoding: documentRelationships, as: UTF8.self)
        let documentXML = String(decoding: document, as: UTF8.self)
        if !contentTypesXML.contains("<Types") ||
            !contentTypesXML.contains("Extension=\"rels\"") ||
            !contentTypesXML.contains("Extension=\"xml\"") ||
            !contentTypesXML.contains("PartName=\"/word/document.xml\"") ||
            !contentTypesXML.contains("application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml") {
            issues.append(.invalidContentTypes)
        }
        if !rootRelationshipsXML.contains("<Relationships") ||
            !rootRelationshipsXML.contains("officeDocument") ||
            !rootRelationshipsXML.contains("Target=\"word/document.xml\"") {
            issues.append(.invalidRootRelationships)
        }
        if !documentRelationshipsXML.contains("<Relationships") {
            issues.append(.invalidDocumentRelationships)
        }
        if !documentXML.contains("<w:document") || !documentXML.contains("<w:body>") ||
            !documentXML.contains("</w:body>") || !documentXML.contains("</w:document>") {
            issues.append(.invalidDocumentPart)
        }
        return DOCXPackageValidation(issues: issues)
    }
}
