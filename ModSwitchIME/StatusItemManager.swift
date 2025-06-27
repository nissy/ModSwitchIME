import SwiftUI
import Cocoa

/// Manages the status bar item and its visual representation
class StatusItemManager {
    private var statusBarItem: NSStatusItem?
    private weak var menuDelegate: NSMenuDelegate?
    
    init() {
        setupStatusBarItem()
    }
    
    private func setupStatusBarItem() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon(hasPermission: false)
    }
    
    func setMenu(_ menu: NSMenu, delegate: NSMenuDelegate?) {
        statusBarItem?.menu = menu
        self.menuDelegate = delegate
        menu.delegate = delegate
    }
    
    func updateIcon(hasPermission: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let button = self?.statusBarItem?.button else { return }
            
            if hasPermission {
                if let image = NSImage(systemSymbolName: "globe", accessibilityDescription: "IME Switcher") {
                    image.isTemplate = true
                    button.image = image
                    button.imagePosition = .imageOnly
                    button.title = ""
                } else {
                    button.image = nil
                    button.title = "🌐"
                }
            } else {
                if let image = NSImage(
                    systemSymbolName: "globe.badge.chevron.backward",
                    accessibilityDescription: "IME Switcher - Permission Required"
                ) {
                    image.isTemplate = true
                    button.image = image
                    button.imagePosition = .imageOnly
                    button.title = ""
                } else {
                    button.image = nil
                    button.title = "🌐❓"
                }
            }
            button.toolTip = "ModSwitchIME - IME Switcher"
        }
    }
    
    func updateIconForIME(_ imeId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let button = self?.statusBarItem?.button else { return }
            
            let (iconName, fallbackText, tooltip) = self?.getIconForIME(imeId) ?? ("globe", "🌐", "ModSwitchIME")
            
            if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: tooltip) {
                image.isTemplate = true
                button.image = image
                button.imagePosition = .imageOnly
                button.title = ""
            } else {
                button.image = nil
                button.title = fallbackText
            }
            
            button.toolTip = tooltip
        }
    }
    
    func showTemporaryIcon(_ symbolName: String, duration: TimeInterval = 3.0) {
        DispatchQueue.main.async { [weak self] in
            guard let button = self?.statusBarItem?.button else { return }
            
            let originalImage = button.image
            let originalTitle = button.title
            
            if let tempImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Temporary Status") {
                tempImage.isTemplate = true
                button.image = tempImage
                button.title = ""
            } else {
                button.image = nil
                button.title = symbolName == "checkmark.circle.fill" ? "✓" : "⚠️"
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                button.image = originalImage
                button.title = originalTitle
            }
        }
    }
    
    private func getIconForIME(_ imeId: String) -> (String, String, String) {
        if imeId.contains("ABC") || imeId.contains("US") {
            return ("globe", "🌐", "ModSwitchIME - English (\(imeId))")
        } else if imeId.contains("Japanese") || imeId.contains("Hiragana") {
            return ("globe.asia.australia", "🇯🇵", "ModSwitchIME - Japanese (\(imeId))")
        } else if imeId.contains("Korean") {
            return ("globe.asia.australia", "🇰🇷", "ModSwitchIME - Korean (\(imeId))")
        } else if imeId.contains("Chinese") || imeId.contains("Pinyin") ||
                  imeId.contains("Simplified") || imeId.contains("Traditional") {
            return ("globe.asia.australia", "🇨🇳", "ModSwitchIME - Chinese (\(imeId))")
        } else {
            return ("globe.central.south.asia", "🌏", "ModSwitchIME - IME (\(imeId))")
        }
    }
    
    deinit {
        if let statusBarItem = statusBarItem {
            NSStatusBar.system.removeStatusItem(statusBarItem)
        }
    }
}