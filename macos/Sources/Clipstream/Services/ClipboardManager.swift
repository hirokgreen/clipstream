import AppKit
import Combine
import Foundation
import SwiftData

/// Observes NSPasteboard for changes, filters sensitive content, classifies types,
/// and persists snippets to SwiftData.
@MainActor
public final class ClipboardManager: ObservableObject {
    public static let shared = ClipboardManager()
    
    @Published public var items: [ClipItem] = []
    
    private var lastChangeCount: Int
    private var timer: Timer?
    private var modelContext: ModelContext?
    private let historyLimit = 200
    
    // Concealed pasteboard types from 1Password, Bitwarden, Keychain, etc.
    private let concealedTypes: [NSPasteboard.PasteboardType] = [
        NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
        NSPasteboard.PasteboardType("com.agilebits.onepassword"),
        NSPasteboard.PasteboardType("de.blinksoft.ConcealedType"),
        NSPasteboard.PasteboardType("Pasteboard type flag - transient")
    ]
    
    private init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
    }
    
    public func configure(with context: ModelContext) {
        self.modelContext = context
        loadExistingItems()
        startObserving()
    }
    
    public func startObserving() {
        timer?.invalidate()
        // 0.25s interval provides near-instant capture while consuming < 0.1% CPU
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForChanges()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    public func stopObserving() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkForChanges() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        
        // 1. Privacy filter: ignore password managers and concealed entries
        for concealed in concealedTypes {
            if pasteboard.types?.contains(concealed) == true {
                return
            }
        }
        
        // 2. Read string content
        guard let copiedString = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !copiedString.isEmpty else {
            return
        }
        
        // Avoid duplicate of most recent item
        if let first = items.first, first.rawContent == copiedString {
            return
        }
        
        // 3. Classify content
        let classification = classify(content: copiedString)
        
        let newItem = ClipItem(
            rawContent: copiedString,
            contentType: classification.type,
            detectedLanguage: classification.language
        )
        
        // 4. Persist and update items list
        modelContext?.insert(newItem)
        try? modelContext?.save()
        
        items.insert(newItem, at: 0)
        enforceLimit()
    }
    
    private func loadExistingItems() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        if let fetched = try? context.fetch(descriptor) {
            self.items = fetched
        }
    }
    
    private func enforceLimit() {
        if items.count > historyLimit {
            let unpinned = items.filter { !$0.isPinned }
            if unpinned.count > (historyLimit - items.filter(\.isPinned).count) {
                if let toRemove = unpinned.last {
                    modelContext?.delete(toRemove)
                    try? modelContext?.save()
                    items.removeAll { $0.id == toRemove.id }
                }
            }
        }
    }
    
    // MARK: - Intelligent Content Auto-Detection Engine
    
    public struct Classification {
        public let type: ClipContentType
        public let language: String?
    }
    
    public func classify(content: String) -> Classification {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Color Value Detection (Hex, RGB, HSL)
        if isColorValue(trimmed) {
            return Classification(type: .color, language: nil)
        }
        
        // 2. URL / Link Detection
        if isWebURL(trimmed) {
            return Classification(type: .link, language: nil)
        }
        
        // 3. Code Detection & Language Classification
        if let lang = detectCodeLanguage(trimmed) {
            return Classification(type: .code, language: lang)
        }
        
        // 4. Default: Plain / Formatted Text
        return Classification(type: .text, language: nil)
    }
    
    private func isColorValue(_ str: String) -> Bool {
        let hexPattern = #"^#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$"#
        let rgbPattern = #"^(?:rgb|rgba)\s*\(\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}(?:\s*,\s*(?:0|1|0?\.\d+))?\s*\)$"#
        let hslPattern = #"^(?:hsl|hsla)\s*\(\s*\d{1,3}\s*,\s*\d{1,3}%\s*,\s*\d{1,3}%(?:\s*,\s*(?:0|1|0?\.\d+))?\s*\)$"#
        
        return str.range(of: hexPattern, options: .regularExpression) != nil ||
               str.range(of: rgbPattern, options: .regularExpression) != nil ||
               str.range(of: hslPattern, options: .regularExpression) != nil
    }
    
    private func isWebURL(_ str: String) -> Bool {
        guard let url = URL(string: str),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            return false
        }
        return !str.contains("\n") && !str.contains(" ")
    }
    
    private func detectCodeLanguage(_ text: String) -> String? {
        let lower = text.lowercased()
        
        // JSON detection
        if (text.hasPrefix("{") && text.hasSuffix("}")) || (text.hasPrefix("[") && text.hasSuffix("]")) {
            if let data = text.data(using: .utf8), (try? JSONSerialization.jsonObject(with: data)) != nil {
                return "JSON"
            }
        }
        
        // HTML / XML
        if text.range(of: #"<(!DOCTYPE|[a-z0-9-]+)[^>]*>.*<\/[a-z0-9-]+>"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return "HTML"
        }
        
        // Swift
        let swiftKeywords = ["struct ", "func ", "guard let", "if let", "import SwiftUI", "import AppKit", "var body: some View", "@State", "@Binding", "@Observable"]
        if swiftKeywords.contains(where: { text.contains($0) }) {
            return "Swift"
        }
        
        // Python
        let pythonKeywords = ["def ", "import ", "from ", "elif ", "__init__", "class ", "print("]
        if (text.contains("def ") || text.contains("import ")) && (text.contains(":\n") || text.contains("self.")) {
            return "Python"
        }
        
        // TypeScript / JavaScript
        let jsKeywords = ["const ", "let ", "function", "export default", "console.log", "=>", "import {", "interface "]
        if jsKeywords.contains(where: { text.contains($0) }) {
            return text.contains("interface ") || text.contains(": string") || text.contains(": number") ? "TypeScript" : "JavaScript"
        }
        
        // SQL
        let sqlKeywords = ["SELECT ", "FROM ", "WHERE ", "INSERT INTO", "UPDATE ", "DELETE FROM", "CREATE TABLE"]
        if sqlKeywords.contains(where: { text.uppercased().contains($0) }) {
            return "SQL"
        }
        
        // Bash / Shell
        if text.hasPrefix("#!/bin/") || text.contains("npm run") || text.contains("git commit") || text.contains("brew install") {
            return "Bash"
        }
        
        // General syntax check: curly brackets, semicolons, function syntax
        let codeCues = [" {", "} ", "();", "() {", " = ", " == ", " -> "]
        if codeCues.filter({ text.contains($0) }).count >= 2 {
            return "Code"
        }
        
        return nil
    }
}
