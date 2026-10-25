import SwiftUI

/// Notification definitions for global keyboard events inside HUD
extension Notification.Name {
    static let clipstreamNavigateUp = Notification.Name("clipstreamNavigateUp")
    static let clipstreamNavigateDown = Notification.Name("clipstreamNavigateDown")
    static let clipstreamPasteSelected = Notification.Name("clipstreamPasteSelected")
    static let clipstreamQuickPaste = Notification.Name("clipstreamQuickPaste")
}

/// The primary floating HUD window view for Clipstream (720x460pt) featuring
/// a quick search bar, category filter pills, 40/60 split list and live inspector pane.
public struct ClipstreamView: View {
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    
    @State private var searchText: String = ""
    @State private var selectedFilter: FilterCategory = .all
    @State private var selectedItemId: UUID?
    @State private var hoveredItemId: UUID?
    
    public var onDismiss: () -> Void = {}
    
    public enum FilterCategory: String, CaseIterable {
        case all = "All"
        case code = "Code"
        case links = "Links"
        case text = "Text"
        case pinned = "Pinned"
    }
    
    public init(onDismiss: @escaping () -> Void = {}) {
        self.onDismiss = onDismiss
    }
    
    private var filteredItems: [ClipItem] {
        clipboardManager.items.filter { item in
            let matchesSearch = searchText.isEmpty ||
                item.rawContent.localizedCaseInsensitiveContains(searchText) ||
                item.title.localizedCaseInsensitiveContains(searchText) ||
                (item.detectedLanguage?.localizedCaseInsensitiveContains(searchText) == true)
            
            guard matchesSearch else { return false }
            
            switch selectedFilter {
            case .all:
                return true
            case .code:
                return item.contentType == .code
            case .links:
                return item.contentType == .link
            case .text:
                return item.contentType == .text || item.contentType == .color
            case .pinned:
                return item.isPinned
            }
        }
        .sorted { (a, b) -> Bool in
            if a.isPinned != b.isPinned {
                return a.isPinned && !b.isPinned
            }
            return a.timestamp > b.timestamp
        }
    }
    
    private var activeInspectorItem: ClipItem? {
        if let hovered = hoveredItemId, let item = clipboardManager.items.first(where: { $0.id == hovered }) {
            return item
        }
        if let selected = selectedItemId, let item = clipboardManager.items.first(where: { $0.id == selected }) {
            return item
        }
        return filteredItems.first
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            topBarView
            Divider().opacity(0.15)
            HStack(spacing: 0) {
                historyListView
                    .frame(width: 288)
                Divider().opacity(0.18)
                inspectorView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 720, height: 460)
        .background(
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 15)
        .onAppear {
            syncInitialSelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipstreamNavigateUp)) { _ in
            navigateSelection(by: -1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipstreamNavigateDown)) { _ in
            navigateSelection(by: 1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipstreamPasteSelected)) { _ in
            if let item = activeInspectorItem {
                pasteItem(item)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipstreamQuickPaste)) { note in
            if let index = note.object as? Int, index < filteredItems.count {
                pasteItem(filteredItems[index])
            }
        }
    }
    
    private func syncInitialSelection() {
        if selectedItemId == nil, let first = filteredItems.first {
            selectedItemId = first.id
        }
    }
    
    private func navigateSelection(by delta: Int) {
        guard !filteredItems.isEmpty else { return }
        let currentIdx = filteredItems.firstIndex(where: { $0.id == selectedItemId }) ?? 0
        let nextIdx = max(0, min(filteredItems.count - 1, currentIdx + delta))
        selectedItemId = filteredItems[nextIdx].id
    }
    
    private var topBarView: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13, weight: .medium))
                
                TextField("Search snippets, links, code...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(8)
            
            HStack(spacing: 4) {
                ForEach(FilterCategory.allCases, id: \.self) { cat in
                    Button(action: {
                        selectedFilter = cat
                        DispatchQueue.main.async {
                            syncInitialSelection()
                        }
                    }) {
                        Text(cat.rawValue)
                            .font(.system(size: 11, weight: selectedFilter == cat ? .semibold : .regular))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(
                                selectedFilter == cat ? Color.accentColor : Color.primary.opacity(0.04)
                            )
                            .foregroundColor(selectedFilter == cat ? .white : .secondary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var historyListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                        let isSelected = (item.id == (hoveredItemId ?? selectedItemId))
                        
                        HStack(spacing: 8) {
                            if index < 9 {
                                Text("\(index + 1)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                                    .frame(width: 14)
                            } else {
                                Spacer().frame(width: 14)
                            }
                            
                            typeIcon(for: item.contentType)
                                .foregroundColor(isSelected ? .white : iconColor(for: item.contentType))
                                .frame(width: 16)
                            
                            Text(item.title)
                                .font(.system(size: 12, weight: .regular))
                                .lineLimit(1)
                                .foregroundColor(isSelected ? .white : .primary)
                            
                            Spacer()
                            
                            if item.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(isSelected ? .white : .orange)
                            }
                        }
                        .id(item.id)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isSelected ? Color.accentColor : Color.clear)
                        )
                        .contentShape(Rectangle())
                        .onHover { isHovered in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                hoveredItemId = isHovered ? item.id : nil
                            }
                        }
                        .onTapGesture {
                            selectedItemId = item.id
                            pasteItem(item)
                        }
                    }
                }
                .padding(8)
            }
            .onChange(of: selectedItemId) { _, newId in
                if let newId = newId {
                    withAnimation {
                        proxy.scrollTo(newId, anchor: .center)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var inspectorView: some View {
        if let item = activeInspectorItem {
            VStack(alignment: .leading, spacing: 12) {
                switch item.contentType {
                case .code:
                    codeInspectorView(item)
                case .link:
                    linkInspectorView(item)
                case .color:
                    colorInspectorView(item)
                case .text:
                    textInspectorView(item)
                }
            }
            .padding(14)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.15), value: item.id)
        } else {
            VStack {
                Image(systemName: "tray")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.4))
                Text("No Clips Found")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func codeInspectorView(_ item: ClipItem) -> some View {
        SyntaxHighlighterView(
            code: item.rawContent,
            language: item.detectedLanguage ?? "Code",
            onCopyClean: {
                let clean = item.rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(clean, forType: .string)
            }
        )
    }
    
    private func linkInspectorView(_ item: ClipItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    if let url = URL(string: item.rawContent), let host = url.host {
                        Text(host)
                            .font(.system(size: 14, weight: .bold))
                    }
                    Text(item.rawContent)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(10)
            
            HStack(spacing: 8) {
                Button(action: {
                    if let url = URL(string: item.rawContent) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Label("Open in Browser", systemImage: "arrow.up.right.square")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: { pasteItem(item) }) {
                    Label("Paste Link", systemImage: "doc.on.clipboard")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
    }
    
    private func colorInspectorView(_ item: ClipItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hexOrFallback: item.rawContent))
                    .frame(width: 64, height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.rawContent.uppercased())
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                    Text("RGB / Hex Color Swatch")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Copy Formats")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    Button("HEX") { copyText(item.rawContent) }
                        .buttonStyle(.bordered)
                    Button("NSColor") { copyText("NSColor(hex: \"\(item.rawContent)\")") }
                        .buttonStyle(.bordered)
                    Button("SwiftUI.Color") { copyText("Color(hex: \"\(item.rawContent)\")") }
                        .buttonStyle(.bordered)
                }
                .controlSize(.small)
            }
            
            Spacer()
        }
    }
    
    private func textInspectorView(_ item: ClipItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView {
                Text(item.rawContent)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(8)
            }
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)
            
            HStack {
                Text("\(item.wordCount) words • \(item.charCount) characters")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Text(relativeTimeString(from: item.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }
    
    @MainActor
    private func pasteItem(_ item: ClipItem) {
        AutoPaster.paste(item: item, hideWindowHandler: onDismiss)
    }
    
    private func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    @ViewBuilder
    private func typeIcon(for type: ClipContentType) -> some View {
        switch type {
        case .code:
            Image(systemName: "curlybraces")
                .font(.system(size: 11, weight: .bold))
        case .link:
            Image(systemName: "link")
                .font(.system(size: 11, weight: .medium))
        case .color:
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 11))
        case .text:
            Image(systemName: "text.alignleft")
                .font(.system(size: 11))
        }
    }
    
    private func iconColor(for type: ClipContentType) -> Color {
        switch type {
        case .code: return .purple
        case .link: return .blue
        case .color: return .orange
        case .text: return .secondary
        }
    }
    
    private func relativeTimeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

public struct VisualEffectBackground: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

extension Color {
    init(hexOrFallback: String) {
        var hex = hexOrFallback.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hex.hasPrefix("#") { hex.removeFirst() }
        
        var rgbValue: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgbValue)
        
        if hex.count == 6 {
            self.init(
                red: Double((rgbValue & 0xFF0000) >> 16) / 255.0,
                green: Double((rgbValue & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgbValue & 0x0000FF) / 255.0
            )
        } else {
            self = .indigo
        }
    }
}
