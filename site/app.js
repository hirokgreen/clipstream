// Clipstream Interactive HUD & Page Controller

const mockClips = [
  {
    id: 1,
    title: "struct ClipstreamView: View",
    type: "code",
    lang: "Swift",
    isPinned: true,
    time: "Just now",
    content: `import SwiftUI
import SwiftData

struct ClipstreamView: View {
    @Query(sort: \\.timestamp, order: .reverse) var items: [ClipItem]
    @State private var search = ""
    
    var body: some View {
        HStack(spacing: 0) {
            HistoryListView(items: items)
                .frame(width: 288)
            Divider()
            LiveInspectorPane()
        }
        .frame(width: 720, height: 460)
        .background(.hudWindow)
    }
}`
  },
  {
    id: 2,
    title: "https://github.com/clipstream/macos",
    type: "link",
    host: "github.com",
    isPinned: true,
    time: "2m ago",
    content: "https://github.com/clipstream/macos"
  },
  {
    id: 3,
    title: "#38BDF8 - Sky Cyan 400",
    type: "color",
    hex: "#38BDF8",
    rgb: "rgb(56, 189, 248)",
    swiftui: 'Color(hex: "#38BDF8")',
    nscolor: 'NSColor(srgbRed: 0.22, green: 0.74, blue: 0.97, alpha: 1.0)',
    isPinned: false,
    time: "5m ago",
    content: "#38BDF8"
  },
  {
    id: 5,
    title: "Clipstream v1.0.0 Release Notes",
    type: "text",
    words: 42,
    chars: 295,
    isPinned: false,
    time: "25m ago",
    content: `Clipstream 1.0.0 is officially released for macOS Sonoma & Sequoia!
- Ultra-lightweight background memory footprint (<0.1% CPU).
- Global ⌘ + ⇧ + V instant summons HUD.
- Live syntax highlighting & smart type auto-detection.
- SwiftData persistent storage with automatic password manager exclusion.`
  },
  {
    id: 6,
    title: "SELECT * FROM clipboard_history",
    type: "code",
    lang: "SQL",
    isPinned: false,
    time: "1h ago",
    content: `SELECT 
    id, 
    content_type, 
    detected_lang, 
    created_at 
FROM clipboard_history 
WHERE is_pinned = TRUE 
ORDER BY created_at DESC 
LIMIT 200;`
  }
];

// State
let activeFilter = 'all';
let searchQuery = '';
let selectedClipId = 1;

// Elements
const hudList = document.getElementById('hudList');
const hudInspector = document.getElementById('hudInspector');
const hudSearchInput = document.getElementById('hudSearchInput');
const hudPills = document.querySelectorAll('.hud-pill');
const toastHud = document.getElementById('toastHud');

// Render List
function renderList() {
  const filtered = mockClips.filter(item => {
    // Search filter
    const matchesSearch = !searchQuery || 
      item.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      item.content.toLowerCase().includes(searchQuery.toLowerCase());
    
    if (!matchesSearch) return false;
    
    // Category pill filter
    if (activeFilter === 'all') return true;
    if (activeFilter === 'code') return item.type === 'code';
    if (activeFilter === 'links') return item.type === 'link';
    if (activeFilter === 'text') return item.type === 'text' || item.type === 'color';
    if (activeFilter === 'pinned') return item.isPinned;
    return true;
  });

  hudList.innerHTML = '';
  
  if (filtered.length === 0) {
    hudList.innerHTML = `<div style="padding: 24px 12px; text-align: center; color: var(--text-muted); font-size: 12px;">No matching clips</div>`;
    renderInspector(null);
    return;
  }

  // Ensure selection remains valid
  if (!filtered.some(i => i.id === selectedClipId)) {
    selectedClipId = filtered[0].id;
  }

  filtered.forEach((item, index) => {
    const isSelected = item.id === selectedClipId;
    const itemEl = document.createElement('div');
    itemEl.className = `hud-item ${isSelected ? 'selected' : ''}`;
    
    // Icon by type
    let icon = '📄';
    if (item.type === 'code') icon = '⚡️';
    if (item.type === 'link') icon = '🔗';
    if (item.type === 'color') icon = '🎨';

    itemEl.innerHTML = `
      <span class="item-num">${index < 9 ? (index + 1) : ''}</span>
      <span class="item-icon">${icon}</span>
      <span class="item-text">${item.title}</span>
      ${item.isPinned ? '<span class="item-pin">📌</span>' : ''}
    `;

    itemEl.addEventListener('click', () => {
      selectedClipId = item.id;
      renderList();
      showToast(`Simulated Paste: "${item.title}"`);
    });

    itemEl.addEventListener('mouseenter', () => {
      selectedClipId = item.id;
      document.querySelectorAll('.hud-item').forEach(el => el.classList.remove('selected'));
      itemEl.classList.add('selected');
      renderInspector(item);
    });

    hudList.appendChild(itemEl);
  });

  const selectedItem = filtered.find(i => i.id === selectedClipId);
  renderInspector(selectedItem);
}

// Render Right Inspector Pane
function renderInspector(item) {
  if (!item) {
    hudInspector.innerHTML = `<div style="margin: auto; color: var(--text-muted); font-size: 13px;">No preview available</div>`;
    return;
  }

  hudInspector.classList.add('inspector-fade');

  if (item.type === 'code') {
    const lines = item.content.split('\n');
    const gutterHtml = lines.map((_, i) => `<div>${i + 1}</div>`).join('');
    
    hudInspector.innerHTML = `
      <div class="code-preview-card">
        <div class="code-header">
          <div style="display: flex; align-items: center; gap: 8px;">
            <span class="lang-tag">${item.lang}</span>
            <span class="code-meta">${lines.length} lines • ${item.content.length} chars</span>
          </div>
          <button class="btn-clean-copy" onclick="copyCleanCode(${item.id})">Copy Clean</button>
        </div>
        <div class="code-viewport">
          <div class="code-gutter">${gutterHtml}</div>
          <div class="code-lines">${escapeHtml(item.content)}</div>
        </div>
      </div>
    `;
  } else if (item.type === 'link') {
    hudInspector.innerHTML = `
      <div class="link-preview-box">
        <div class="link-host-header">
          <div class="link-icon-box">🌐</div>
          <div>
            <div class="link-domain">${item.host}</div>
            <div class="link-url-text">${item.content}</div>
          </div>
        </div>
        <div style="display: flex; gap: 8px; margin-top: 8px;">
          <a href="${item.content}" target="_blank" class="btn-primary" style="padding: 6px 12px; font-size: 12px; border-radius: 6px;">
            Open in Browser ↗
          </a>
          <button class="fmt-btn" onclick="copyTextDirect('${item.content}', 'URL Copied!')">Copy Link</button>
        </div>
      </div>
    `;
  } else if (item.type === 'color') {
    hudInspector.innerHTML = `
      <div class="color-preview-box">
        <div class="color-swatch-large" style="background-color: ${item.hex};"></div>
        <div>
          <div style="font-family: var(--font-mono); font-size: 18px; font-weight: 700;">${item.hex}</div>
          <div style="font-size: 12px; color: var(--text-muted);">${item.rgb}</div>
        </div>
      </div>
      <div style="margin-top: 14px;">
        <div style="font-size: 11px; font-weight: 600; color: var(--text-muted); margin-bottom: 6px; text-transform: uppercase;">
          Quick Conversion Formats
        </div>
        <div class="format-pills">
          <button class="fmt-btn" onclick="copyTextDirect('${item.hex}', 'HEX Copied!')">HEX</button>
          <button class="fmt-btn" onclick="copyTextDirect('${item.rgb}', 'RGB Copied!')">RGB</button>
          <button class="fmt-btn" onclick="copyTextDirect('${item.swiftui}', 'SwiftUI Color Copied!')">SwiftUI</button>
          <button class="fmt-btn" onclick="copyTextDirect('${item.nscolor}', 'NSColor Copied!')">NSColor</button>
        </div>
      </div>
    `;
  } else if (item.type === 'text') {
    hudInspector.innerHTML = `
      <div style="display: flex; flex-direction: column; height: 100%;">
        <div style="flex: 1; background: rgba(0,0,0,0.3); border: 1px solid rgba(255,255,255,0.06); border-radius: 8px; padding: 14px; font-size: 13px; line-height: 1.6; color: #E2E8F0; overflow-y: auto;">
          ${escapeHtml(item.content)}
        </div>
        <div style="display: flex; justify-content: space-between; margin-top: 10px; font-size: 11px; color: var(--text-muted); font-family: var(--font-mono);">
          <span>${item.words} words • ${item.chars} chars</span>
          <span>${item.time}</span>
        </div>
      </div>
    `;
  }
}

function escapeHtml(text) {
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// Search input
hudSearchInput.addEventListener('input', (e) => {
  searchQuery = e.target.value.trim();
  renderList();
});

// Category Filter Pills
hudPills.forEach(pill => {
  pill.addEventListener('click', () => {
    hudPills.forEach(p => p.classList.remove('active'));
    pill.classList.add('active');
    activeFilter = pill.dataset.filter;
    renderList();
  });
});

// Toast notification
let toastTimer = null;
function showToast(msg) {
  if (toastTimer) clearTimeout(toastTimer);
  toastHud.textContent = msg;
  toastHud.classList.add('show');
  toastTimer = setTimeout(() => {
    toastHud.classList.remove('show');
  }, 2200);
}

// Copy actions
window.copyCleanCode = function(id) {
  const item = mockClips.find(i => i.id === id);
  if (item) {
    const clean = item.content.trim();
    navigator.clipboard.writeText(clean).then(() => {
      showToast("Copied clean code to clipboard!");
    });
  }
};

window.copyTextDirect = function(text, toastMsg) {
  navigator.clipboard.writeText(text).then(() => {
    showToast(toastMsg || "Copied to clipboard!");
  });
};

window.copyBrewCommand = function() {
  const cmd = "brew install --cask clipstream";
  navigator.clipboard.writeText(cmd).then(() => {
    showToast("Copied: " + cmd);
  });
};

// Keyboard navigation in playground
document.addEventListener('keydown', (e) => {
  const activeTag = document.activeElement ? document.activeElement.tagName.toLowerCase() : '';
  
  // If user is inside another input other than HUD search, skip
  if (activeTag === 'input' && document.activeElement !== hudSearchInput) return;
  
  const filtered = mockClips.filter(item => {
    if (activeFilter === 'all') return true;
    if (activeFilter === 'code') return item.type === 'code';
    if (activeFilter === 'links') return item.type === 'link';
    if (activeFilter === 'text') return item.type === 'text' || item.type === 'color';
    if (activeFilter === 'pinned') return item.isPinned;
    return true;
  });

  const currentIndex = filtered.findIndex(i => i.id === selectedClipId);

  if (e.key === 'ArrowDown' || (e.key === 'j' && activeTag !== 'input')) {
    if (currentIndex < filtered.length - 1) {
      selectedClipId = filtered[currentIndex + 1].id;
      renderList();
    }
    e.preventDefault();
  } else if (e.key === 'ArrowUp' || (e.key === 'k' && activeTag !== 'input')) {
    if (currentIndex > 0) {
      selectedClipId = filtered[currentIndex - 1].id;
      renderList();
    }
    e.preventDefault();
  } else if (e.key >= '1' && e.key <= '9' && activeTag !== 'input') {
    const num = parseInt(e.key, 10) - 1;
    if (num < filtered.length) {
      selectedClipId = filtered[num].id;
      renderList();
      showToast(`Pasted #${e.key}: "${filtered[num].title}"`);
    }
  } else if (e.key === 'Enter' && activeTag !== 'input') {
    const current = filtered.find(i => i.id === selectedClipId);
    if (current) {
      showToast(`Pasted: "${current.title}"`);
    }
  } else if ((e.key === 'p' || e.key === 'P') && activeTag !== 'input') {
    const current = mockClips.find(i => i.id === selectedClipId);
    if (current) {
      current.isPinned = !current.isPinned;
      showToast(current.isPinned ? "Snippet pinned to top!" : "Snippet unpinned");
      renderList();
    }
  }
});

// Swift Deliverables Code Tab Switcher
const swiftSnippets = {
  "ClipboardManager.swift": `import AppKit
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
    
    public func startObserving() {
        // 0.25s interval provides instant capture with < 0.1% CPU
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForChanges()
            }
        }
    }
}`,
  "HotKeyManager.swift": `import AppKit
import Carbon

/// Registers and manages global system hotkeys using Carbon EventHotKey API.
/// Default: ⌘ + ⇧ + V summons Clipstream HUD.
public final class HotKeyManager {
    public static let shared = HotKeyManager()
    private var hotKeyRef: EventHotKeyRef?
    public var onHotKeyTriggered: (() -> Void)?
    
    public func registerDefaultHotKey() {
        let hotKeyID = EventHotKeyID(signature: OSType(0x434C4950), id: 1)
        let modifiers = UInt32(cmdKey | shiftKey)
        let keyCode = UInt32(kVK_ANSI_V)
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}`,
  "ClipItem.swift": `import Foundation
import SwiftData

public enum ClipContentType: String, Codable, CaseIterable {
    case code, link, text, color
}

@Model
public final class ClipItem {
    @Attribute(.unique) public var id: UUID
    public var rawContent: String
    public var contentTypeRaw: String
    public var detectedLanguage: String?
    public var title: String
    public var timestamp: Date
    public var isPinned: Bool
    public var wordCount: Int
    public var charCount: Int
    
    public init(rawContent: String, contentType: ClipContentType = .text) {
        self.id = UUID()
        self.rawContent = rawContent
        self.contentTypeRaw = contentType.rawValue
        self.timestamp = Date()
        self.isPinned = false
        self.charCount = rawContent.count
        self.wordCount = rawContent.split { $0.isWhitespace || $0.isNewline }.count
        self.title = String(rawContent.prefix(60))
    }
}`,
  "AutoPaster.swift": `import AppKit
import ApplicationServices

public struct AutoPaster {
    @MainActor
    public static func paste(text: String, hideWindowHandler: () -> Void) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        hideWindowHandler()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            simulateCmdV()
        }
    }
    
    private static func simulateCmdV() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let vKeyCode: CGKeyCode = 9
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}`,
  "ClipstreamView.swift": `import SwiftUI
import SwiftData

public struct ClipstreamView: View {
    @Query(sort: \\ClipItem.timestamp, order: .reverse) private var allItems: [ClipItem]
    @State private var searchText = ""
    @State private var selectedFilter = "All"
    
    public var body: some View {
        VStack(spacing: 0) {
            TopSearchBar(search: $searchText, filter: $selectedFilter)
            Divider()
            HStack(spacing: 0) {
                CompactListView(items: allItems)
                    .frame(width: 288)
                Divider()
                LiveInspectorPane()
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 720, height: 460)
        .background(VisualEffectBackground(material: .hudWindow))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}`,
  "SyntaxHighlighter.swift": `import SwiftUI

public struct SyntaxHighlighterView: View {
    public let code: String
    public let language: String
    
    public var body: some View {
        VStack(spacing: 0) {
            InspectorHeader(language: language)
            Divider()
            ScrollView([.horizontal, .vertical]) {
                HStack(alignment: .top, spacing: 0) {
                    LineNumberGutter(count: code.components(separatedBy: .newlines).count)
                    Divider()
                    TokenColorizer(code: code)
                }
            }
        }
        .cornerRadius(10)
    }
}`
};

window.switchCodeTab = function(fileName, btnEl) {
  document.querySelectorAll('.code-tab-btn').forEach(b => b.classList.remove('active'));
  btnEl.classList.add('active');
  document.getElementById('codeTabFileName').textContent = fileName;
  document.getElementById('codeTabBody').textContent = swiftSnippets[fileName] || '// File not found';
};

window.copyCurrentCodeTab = function() {
  const currentCode = document.getElementById('codeTabBody').textContent;
  navigator.clipboard.writeText(currentCode).then(() => {
    showToast("Swift file copied to clipboard!");
  });
};

// Mobile Navigation Toggle
const mobileToggle = document.getElementById('mobileNavToggle');
const navLinksEl = document.getElementById('navLinks');

if (mobileToggle && navLinksEl) {
  mobileToggle.addEventListener('click', (e) => {
    e.stopPropagation();
    mobileToggle.classList.toggle('active');
    navLinksEl.classList.toggle('open');
  });

  navLinksEl.querySelectorAll('a').forEach(link => {
    link.addEventListener('click', () => {
      mobileToggle.classList.remove('active');
      navLinksEl.classList.remove('open');
    });
  });

  document.addEventListener('click', (e) => {
    if (!mobileToggle.contains(e.target) && !navLinksEl.contains(e.target)) {
      mobileToggle.classList.remove('active');
      navLinksEl.classList.remove('open');
    }
  });
}

// Initialize
renderList();
