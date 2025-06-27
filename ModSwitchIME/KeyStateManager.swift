import Foundation
import CoreGraphics

/// Thread-safe key state management using Actor
@available(macOS 13.0, *)
actor KeyStateManager {
    private struct KeyState {
        var isDown: Bool
        var downTime: CFAbsoluteTime
    }
    
    private var keyStates: [ModifierKey: KeyState] = [:]
    
    func setKeyDown(_ key: ModifierKey, at time: CFAbsoluteTime) {
        keyStates[key] = KeyState(isDown: true, downTime: time)
    }
    
    func setKeyUp(_ key: ModifierKey) {
        if var state = keyStates[key] {
            state.isDown = false
            keyStates[key] = state
        }
    }
    
    func getKeyState(_ key: ModifierKey) -> (isDown: Bool, downTime: CFAbsoluteTime)? {
        guard let state = keyStates[key] else { return nil }
        return (state.isDown, state.downTime)
    }
    
    func getAllPressedKeys() -> [ModifierKey] {
        return keyStates.compactMap { key, state in
            state.isDown ? key : nil
        }
    }
    
    func resetAll() {
        keyStates.removeAll()
    }
}

/// Thread-safe key state management for macOS < 13.0
class LegacyKeyStateManager {
    private struct KeyState {
        var isDown: Bool
        var downTime: CFAbsoluteTime
    }
    
    private var keyStates: [ModifierKey: KeyState] = [:]
    private let lock = NSLock()
    
    func setKeyDown(_ key: ModifierKey, at time: CFAbsoluteTime) {
        lock.lock()
        defer { lock.unlock() }
        keyStates[key] = KeyState(isDown: true, downTime: time)
    }
    
    func setKeyUp(_ key: ModifierKey) {
        lock.lock()
        defer { lock.unlock() }
        if var state = keyStates[key] {
            state.isDown = false
            keyStates[key] = state
        }
    }
    
    func getKeyState(_ key: ModifierKey) -> (isDown: Bool, downTime: CFAbsoluteTime)? {
        lock.lock()
        defer { lock.unlock() }
        guard let state = keyStates[key] else { return nil }
        return (state.isDown, state.downTime)
    }
    
    func getAllPressedKeys() -> [ModifierKey] {
        lock.lock()
        defer { lock.unlock() }
        return keyStates.compactMap { key, state in
            state.isDown ? key : nil
        }
    }
    
    func resetAll() {
        lock.lock()
        defer { lock.unlock() }
        keyStates.removeAll()
    }
}