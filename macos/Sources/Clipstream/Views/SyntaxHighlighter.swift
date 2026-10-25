import SwiftUI

/// Renders syntax-highlighted code with gutter line numbers, language tag, and copy actions.
public struct SyntaxHighlighterView: View {
    public let code: String
    public let language: String
    public let onCopyClean: () -> Void
    
    public init(code: String, language: String = "Code", onCopyClean: @escaping () -> Void = {}) {
        self.code = code
        self.language = language
        self.onCopyClean = onCopyClean
    }
    
    private var lines: [String] {
        code.components(separatedBy: .newlines)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            codeScrollView
        }
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.cyan)
                Text(language.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.cyan.opacity(0.12))
            .cornerRadius(6)
            
            Spacer()
            
            Text("\(lines.count) lines • \(code.count) chars")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
            
            Button(action: onCopyClean) {
                Label("Copy Clean", systemImage: "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.03))
    }
    
    private var codeScrollView: some View {
        ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 0) {
                gutterView
                Divider().opacity(0.3)
                codeContentView
            }
            .frame(minWidth: 400, alignment: .leading)
        }
        .background(Color.black.opacity(0.25))
    }
    
    private var gutterView: some View {
        VStack(alignment: .trailing, spacing: 3) {
            ForEach(0..<lines.count, id: \.self) { idx in
                Text("\(idx + 1)")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(Color.secondary.opacity(0.45))
                    .frame(height: 18)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.15))
    }
    
    private var codeContentView: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(0..<lines.count, id: \.self) { idx in
                highlightLine(lines[idx])
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .frame(height: 18, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
    
    @ViewBuilder
    private func highlightLine(_ line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("//") || trimmed.hasPrefix("#") {
            Text(line).foregroundColor(Color.gray.opacity(0.8))
        } else if trimmed.hasPrefix("import ") || trimmed.hasPrefix("from ") {
            Text(line).foregroundColor(Color.pink.opacity(0.9))
        } else if trimmed.contains("func ") || trimmed.contains("def ") {
            Text(line).foregroundColor(Color.purple.opacity(0.95))
        } else if trimmed.contains("return ") || trimmed.contains("guard ") {
            Text(line).foregroundColor(Color.orange.opacity(0.95))
        } else {
            Text(line).foregroundColor(Color.white.opacity(0.92))
        }
    }
}
