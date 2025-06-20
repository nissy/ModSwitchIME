import SwiftUI

// MARK: - Privacy Notice View

struct PrivacyNoticeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lock.shield")
                    .foregroundColor(.blue)
                Text("Privacy & Security")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("ModSwitchIME monitors ONLY modifier keys (⌘, ⇧, ⌃, ⌥)")
                    .font(.caption)
                    .foregroundColor(.primary)
                
                HStack(alignment: .top, spacing: 4) {
                    Text("•")
                    Text("No typing content is recorded or stored")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                
                HStack(alignment: .top, spacing: 4) {
                    Text("•")
                    Text("No data is transmitted over the network")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                
                HStack(alignment: .top, spacing: 4) {
                    Text("•")
                    Text("All processing happens locally on your Mac")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                
                HStack(alignment: .top, spacing: 4) {
                    Text("•")
                    Text("Open source for complete transparency")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding(.leading, 20)
            
            HStack {
                Link("View security policy",
                     destination: URL(string: "https://github.com/nissy/ModSwitchIME/blob/main/SECURITY_POLICY.md")!)
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text("You can revoke access anytime in System Settings")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
}

struct PreferencesView: View {
    @EnvironmentObject var preferences: Preferences
    @State private var selectedModifierKey: ModifierKey?
    @State private var showIdleIMEPicker = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // Idle timeout settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Auto Switch on Idle")
                        .font(.headline)
                    
                    Toggle("Switch IME automatically when idle", isOn: $preferences.idleOffEnabled)
                    
                    if preferences.idleOffEnabled {
                        HStack {
                            Text("After idle for:")
                            Stepper(value: $preferences.idleTimeout, in: 1...300, step: 1) {
                                Text("\(Int(preferences.idleTimeout)) seconds")
                            }
                            .frame(width: 150)
                        }
                        
                        // Return IME selection (only enabled when multiple keys are configured)
                        HStack {
                            Text("Return to:")
                            Button(action: {
                                showIdleIMEPicker = true
                            }, label: {
                                HStack {
                                    if let imeId = preferences.idleReturnIME {
                                        if let icon = Preferences.getInputSourceIcon(imeId) {
                                            Text(icon)
                                        }
                                        Text(getIMEDisplayName(imeId))
                                            .foregroundColor(.primary)
                                    } else {
                                        Text("English (Default)")
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                            })
                            .buttonStyle(.plain)
                            .frame(maxWidth: 300)
                        }
                    }
                }
                
                Divider()
                
                // Command key timeout settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Modifier Key Detection")
                        .font(.headline)
                    
                    Toggle(
                        "Wait before switching (prevent accidental triggers)",
                        isOn: $preferences.cmdKeyTimeoutEnabled
                    )
                    
                    if preferences.cmdKeyTimeoutEnabled {
                        HStack {
                            Text("Hold time:")
                            Stepper(value: $preferences.cmdKeyTimeout, in: 0.1...1.0, step: 0.1) {
                                Text(String(format: "%.1f seconds", preferences.cmdKeyTimeout))
                            }
                            .frame(width: 150)
                        }
                        
                        Text("Only switch if key is released within this time")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Keys switch immediately when released (may conflict with shortcuts)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // Modifier key mappings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Modifier Key Assignments")
                        .font(.headline)
                    
                    Text("Press a modifier key alone to switch input methods")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(ModifierKey.allCases, id: \.self) { key in
                        ModifierKeyRow(
                            modifierKey: key,
                            selectedIME: preferences.modifierKeyMappings[key]
                        ) {
                            selectedModifierKey = key
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .frame(width: 500, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(item: $selectedModifierKey) { key in
            ModifierKeyInputSourcePicker(
                modifierKey: key,
                selectedSourceId: Binding(
                    get: { preferences.getIME(for: key) ?? "" },
                    set: { preferences.setIME($0, for: key) }
                ),
                isPresented: Binding(
                    get: { selectedModifierKey != nil },
                    set: { if !$0 { selectedModifierKey = nil } }
                )
            )
        }
        .sheet(isPresented: $showIdleIMEPicker) {
            IdleIMEPicker(
                selectedSourceId: Binding(
                    get: { preferences.idleReturnIME ?? "" },
                    set: { 
                        if $0.isEmpty {
                            preferences.idleReturnIME = nil
                        } else {
                            preferences.idleReturnIME = $0
                        }
                    }
                ),
                isPresented: $showIdleIMEPicker
            )
        }
    }
    
    private func getIMEDisplayName(_ imeId: String) -> String {
        // Use Preferences.getAllInputSources (back to working implementation)
        let cachedSources = Preferences.getAllInputSources(includeDisabled: false)
        
        if let source = cachedSources.first(where: { $0.sourceId == imeId }) {
            return source.localizedName
        }
        return imeId
    }
}

// MARK: - Modifier Key Row

struct ModifierKeyRow: View {
    let modifierKey: ModifierKey
    let selectedIME: String?
    let onSelect: () -> Void
    
    var body: some View {
        HStack {
            Text(modifierKey.displayName)
                .frame(width: 120, alignment: .leading)
            
            Button(action: onSelect) {
                HStack {
                    if let imeId = selectedIME, !imeId.isEmpty {
                        if let icon = Preferences.getInputSourceIcon(imeId) {
                            Text(icon)
                        }
                        Text(getIMEDisplayName(imeId))
                            .foregroundColor(.primary)
                    } else {
                        Text("Click to assign")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 300)
        }
    }
    
    private func getIMEDisplayName(_ imeId: String) -> String {
        // Use Preferences.getAllInputSources (back to working implementation)
        let cachedSources = Preferences.getAllInputSources(includeDisabled: false)
        
        if let source = cachedSources.first(where: { $0.sourceId == imeId }) {
            return source.localizedName
        }
        return imeId
    }
}

// MARK: - Modifier Key Input Source Picker

struct ModifierKeyInputSourcePicker: View {
    let modifierKey: ModifierKey
    @Binding var selectedSourceId: String
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var selectedLanguage: String?
    @State private var showDisabledSources = false
    
    private var groupedInputSources: [String: [Preferences.InputSource]] {
        // Use Preferences.getAllInputSources (back to working implementation)
        let cachedSources = Preferences.getAllInputSources(includeDisabled: showDisabledSources)
        
        let filtered = searchText.isEmpty ? cachedSources : cachedSources.filter { 
            $0.localizedName.localizedCaseInsensitiveContains(searchText) ||
            $0.sourceId.localizedCaseInsensitiveContains(searchText)
        }
        
        return Dictionary(grouping: filtered) { source in
            Preferences.getInputSourceLanguage(source.sourceId)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select IME for \(modifierKey.displayName)")
                    .font(.headline)
                Spacer()
                Toggle("Show disabled sources", isOn: $showDisabledSources)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            
            // Clear selection button
            if !selectedSourceId.isEmpty {
                Button("Remove Assignment") {
                    selectedSourceId = ""
                    isPresented = false
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            Divider()
            
            // Language list or Input source list
            if selectedLanguage == nil {
                // Language selection screen
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(groupedInputSources.keys.sorted(), id: \.self) { language in
                            LanguageRowView(
                                language: language,
                                count: groupedInputSources[language]?.count ?? 0
                            ) { selectedLanguage = language }
                            
                            let sortedKeys = groupedInputSources.keys.sorted()
                            if language != sortedKeys.last {
                                Divider()
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else {
                // Input source selection screen
                VStack(spacing: 0) {
                    // Back button
                    HStack {
                        Button {
                            selectedLanguage = nil
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Languages")
                            }
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Text(selectedLanguage ?? "")
                            .font(.headline)
                        
                        Spacer()
                        
                        // Keep spacing
                        Text("").frame(width: 50)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            if let sources = groupedInputSources[selectedLanguage ?? ""] {
                                ForEach(sources) { source in
                                    InputSourceRowView(
                                        source: source,
                                        isSelected: source.sourceId == selectedSourceId
                                    ) {
                                        selectedSourceId = source.sourceId
                                        isPresented = false
                                    }
                                    
                                    if source.id != sources.last?.id {
                                        Divider()
                                            .padding(.leading, 52)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// Make ModifierKey conform to Identifiable for sheet presentation
extension ModifierKey: Identifiable {
    var id: String { rawValue }
}

// MARK: - Input Source Row View

struct InputSourceRowView: View {
    let source: Preferences.InputSource
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            // Only allow selection if the source is enabled
            if source.isEnabled {
                action()
            }
        }, label: {
            HStack(spacing: 12) {
                // Flag Icon - display larger
                Text(Preferences.getInputSourceIcon(source.sourceId) ?? "⌨️")
                    .font(.system(size: 20))
                    .frame(width: 28, height: 28)
                
                // Name only (no source ID)
                Text(getDisplayName())
                    .font(.system(size: 13))
                    .foregroundColor(source.isEnabled ? .primary : .secondary)
                
                Spacer()
                
                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        })
        .buttonStyle(.plain)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .disabled(!source.isEnabled) // Disable interaction for disabled sources
        .opacity(source.isEnabled ? 1.0 : 0.5) // Disabled sources are shown with reduced opacity
    }
    
    private func getDisplayName() -> String {
        if let googleName = getGoogleInputDisplayName() {
            return googleName
        }
        
        if let atokName = getATOKDisplayName() {
            return atokName
        }
        
        if let kotoeriName = getKotoeriDisplayName() {
            return kotoeriName
        }
        
        if let keyboardName = getKeyboardLayoutDisplayName() {
            return keyboardName
        }
        
        return source.localizedName
    }
    
    private func getGoogleInputDisplayName() -> String? {
        guard source.sourceId.contains("com.google.inputmethod.Japanese") else { return nil }
        
        if source.sourceId.contains("Hiragana") {
            return "Hiragana (Google)"
        } else if source.sourceId.contains("Katakana") {
            return "Katakana (Google)"
        } else if source.sourceId.contains("FullWidthRoman") {
            return "Full-width Alphanumeric (Google)"
        } else if source.sourceId.contains("HalfWidthKana") {
            return "Half-width Katakana (Google)"
        } else if source.sourceId.contains("Roman") {
            return "Alphanumeric (Google)"
        }
        return nil
    }
    
    private func getATOKDisplayName() -> String? {
        guard source.sourceId.contains("ATOK") else { return nil }
        
        if source.sourceId.contains("Japanese.Katakana") {
            return "Katakana (ATOK)"
        } else if source.sourceId.contains("Japanese.FullWidthRoman") {
            return "Full-width Alphanumeric (ATOK)"
        } else if source.sourceId.contains("Japanese.HalfWidthEiji") {
            return "Half-width Alphanumeric (ATOK)"
        } else if source.sourceId.contains("Roman") {
            return "Alphanumeric (ATOK)"
        } else if source.sourceId.hasSuffix(".Japanese") {
            return "Hiragana (ATOK)"
        }
        return nil
    }
    
    private func getKotoeriDisplayName() -> String? {
        guard source.sourceId.contains("com.apple.inputmethod.Kotoeri") else { return nil }
        
        if source.sourceId.contains("Hiragana") {
            return "Hiragana"
        } else if source.sourceId.contains("Katakana") {
            return "Katakana"
        } else if source.sourceId.contains("FullWidthRoman") {
            return "Full-width Alphanumeric"
        } else if source.sourceId.contains("HalfWidthKana") {
            return "Half-width Katakana"
        } else if source.sourceId.contains("Roman") {
            return "Alphanumeric"
        }
        return nil
    }
    
    private func getKeyboardLayoutDisplayName() -> String? {
        if source.sourceId == "com.apple.keylayout.ABC" {
            return "ABC"
        } else if source.sourceId == "com.apple.keylayout.US" {
            return "US"
        }
        return nil
    }
}

// MARK: - Idle IME Picker

struct IdleIMEPicker: View {
    @Binding var selectedSourceId: String
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var selectedLanguage: String?
    @State private var showDisabledSources = false
    
    private var groupedInputSources: [String: [Preferences.InputSource]] {
        // Use Preferences.getAllInputSources (back to working implementation)
        let cachedSources = Preferences.getAllInputSources(includeDisabled: showDisabledSources)
        
        let filtered = searchText.isEmpty ? cachedSources : cachedSources.filter { 
            $0.localizedName.localizedCaseInsensitiveContains(searchText) ||
            $0.sourceId.localizedCaseInsensitiveContains(searchText)
        }
        
        return Dictionary(grouping: filtered) { source in
            Preferences.getInputSourceLanguage(source.sourceId)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select IME for Idle Return")
                    .font(.headline)
                Spacer()
                Toggle("Show disabled sources", isOn: $showDisabledSources)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            
            // Clear selection button  
            Button("Reset to English") {
                selectedSourceId = ""
                isPresented = false
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            Divider()
            
            // Language list or Input source list
            if selectedLanguage == nil {
                // Language selection screen
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(groupedInputSources.keys.sorted(), id: \.self) { language in
                            LanguageRowView(
                                language: language,
                                count: groupedInputSources[language]?.count ?? 0
                            ) { selectedLanguage = language }
                            
                            let sortedKeys = groupedInputSources.keys.sorted()
                            if language != sortedKeys.last {
                                Divider()
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else {
                // Input source selection screen
                VStack(spacing: 0) {
                    // Back button
                    HStack {
                        Button {
                            selectedLanguage = nil
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Languages")
                            }
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Text(selectedLanguage ?? "")
                            .font(.headline)
                        
                        Spacer()
                        
                        // Keep spacing
                        Text("").frame(width: 50)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            if let sources = groupedInputSources[selectedLanguage ?? ""] {
                                ForEach(sources) { source in
                                    InputSourceRowView(
                                        source: source,
                                        isSelected: source.sourceId == selectedSourceId
                                    ) {
                                        selectedSourceId = source.sourceId
                                        isPresented = false
                                    }
                                    
                                    if source.id != sources.last?.id {
                                        Divider()
                                            .padding(.leading, 52)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Language Row View

struct LanguageRowView: View {
    let language: String
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                // Language icon
                Text(getLanguageIcon())
                    .font(.system(size: 24))
                    .frame(width: 32, height: 32)
                
                // Language name
                Text(language)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Number of input sources
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.clear)
    }
    
    private func getLanguageIcon() -> String {
        switch language {
        case "Japanese": return "🇯🇵"
        case "Chinese": return "🇨🇳"
        case "Korean": return "🇰🇷"
        case "Vietnamese": return "🇻🇳"
        case "Arabic": return "🇸🇦"
        case "Hebrew": return "🇮🇱"
        case "Thai": return "🇹🇭"
        case "Indic Languages": return "🇮🇳"
        case "Cyrillic Scripts": return "🇷🇺"
        case "European Languages": return "🇪🇺"
        default: return "🌐"
        }
    }
}
