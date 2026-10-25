import Foundation
import Combine

/// The detected semantic type of a clipboard item.
public enum ClipContentType: String, Codable, CaseIterable {
    case code
    case link
    case text
    case color
}

/// Represents a single history item recorded by Clipstream.
public final class ClipItem: Identifiable, Codable, ObservableObject {
    public let id: UUID
    public var rawContent: String
    public var contentTypeRaw: String
    public var detectedLanguage: String?
    public var title: String
    public var timestamp: Date
    public var isPinned: Bool
    public var wordCount: Int
    public var charCount: Int
    
    public var contentType: ClipContentType {
        get { ClipContentType(rawValue: contentTypeRaw) ?? .text }
        set { contentTypeRaw = newValue.rawValue }
    }
    
    public init(
        id: UUID = UUID(),
        rawContent: String,
        contentType: ClipContentType = .text,
        detectedLanguage: String? = nil,
        title: String? = nil,
        timestamp: Date = Date(),
        isPinned: Bool = false
    ) {
        self.id = id
        self.rawContent = rawContent
        self.contentTypeRaw = contentType.rawValue
        self.detectedLanguage = detectedLanguage
        self.timestamp = timestamp
        self.isPinned = isPinned
        self.charCount = rawContent.count
        self.wordCount = rawContent.split { $0.isWhitespace || $0.isNewline }.count
        
        if let title = title, !title.isEmpty {
            self.title = title
        } else {
            let firstLine = rawContent.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespaces) ?? ""
            self.title = firstLine.isEmpty ? "Empty Snippet" : String(firstLine.prefix(60))
        }
    }
}
