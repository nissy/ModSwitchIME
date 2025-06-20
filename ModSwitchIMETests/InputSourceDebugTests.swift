import XCTest
import Carbon
@testable import ModSwitchIME

class InputSourceDebugTests: XCTestCase {
    
    func testDebugAllInputSources() {
        // すべての入力ソースを取得
        guard let inputSourceList = TISCreateInputSourceList(nil, false).takeRetainedValue() as? [TISInputSource] else {
            XCTFail("Failed to get input source list")
            return
        }
        
        // === 全入力ソース一覧 ===
        // 総数: \(inputSourceList.count)
        
        for (index, inputSource) in inputSourceList.enumerated() {
            debugPrintInputSource(inputSource, index: index)
        }
        
        // 日本語入力を探す
        debugJapaneseInputSources(inputSourceList)
    }
    
    private func debugPrintInputSource(_ inputSource: TISInputSource, index: Int) {
        // --- 入力ソース #\(index + 1) ---
        
        // ID
        if let sourceId = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) {
            let cfString = Unmanaged<CFString>.fromOpaque(sourceId).takeUnretainedValue()
            // ID: \(cfString as String)
        }
        
        // ローカライズ名
        if let localizedName = TISGetInputSourceProperty(inputSource, kTISPropertyLocalizedName) {
            let cfString = Unmanaged<CFString>.fromOpaque(localizedName).takeUnretainedValue()
            // 名前: \(cfString as String)
        }
        
        debugPrintInputSourceProperties(inputSource)
    }
    
    private func debugPrintInputSourceProperties(_ inputSource: TISInputSource) {
        // カテゴリー
        if let category = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceCategory) {
            let cfString = Unmanaged<CFString>.fromOpaque(category).takeUnretainedValue()
            // カテゴリー: \(cfString as String)
        }
        
        // タイプ
        if let type = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceType) {
            let cfString = Unmanaged<CFString>.fromOpaque(type).takeUnretainedValue()
            // タイプ: \(cfString as String)
        }
        
        // 選択可能か
        if let selectablePtr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsSelectCapable) {
            let selectable = Unmanaged<CFBoolean>.fromOpaque(selectablePtr).takeUnretainedValue()
            // 選択可能: \(CFBooleanGetValue(selectable))
        }
        
        // 有効か
        if let enabledPtr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsEnabled) {
            let enabled = Unmanaged<CFBoolean>.fromOpaque(enabledPtr).takeUnretainedValue()
            // 有効: \(CFBooleanGetValue(enabled))
        }
    }
    
    private func debugJapaneseInputSources(_ inputSourceList: [TISInputSource]) {
        // === 日本語入力の検索 ===
        let japaneseInputs = inputSourceList.filter { inputSource in
            if let sourceId = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) {
                let cfString = Unmanaged<CFString>.fromOpaque(sourceId).takeUnretainedValue() as String
                return cfString.contains("Kotoeri") || cfString.contains("Japanese")
            }
            return false
        }
        
        // 日本語入力の数: \(japaneseInputs.count)
        for input in japaneseInputs {
            if let sourceId = TISGetInputSourceProperty(input, kTISPropertyInputSourceID) {
                let cfString = Unmanaged<CFString>.fromOpaque(sourceId).takeUnretainedValue()
                // - \(cfString as String)
            }
        }
    }
    
    func testDebugSelectableInputMethods() {
        // Preferences.getAvailableInputSources()と同じロジックでテスト
        guard let inputSourceList = TISCreateInputSourceList(nil, false).takeRetainedValue() as? [TISInputSource] else {
            XCTFail("Failed to get input source list")
            return
        }
        
        // === 選択可能な入力メソッド ===
        
        var selectableCount = 0
        for inputSource in inputSourceList {
            guard let selectablePtr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsSelectCapable),
                  CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(selectablePtr).takeUnretainedValue()) else {
                continue
            }
            
            selectableCount += 1
            
            if let sourceId = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID),
               let localizedName = TISGetInputSourceProperty(inputSource, kTISPropertyLocalizedName) {
                let id = Unmanaged<CFString>.fromOpaque(sourceId).takeUnretainedValue() as String
                let name = Unmanaged<CFString>.fromOpaque(localizedName).takeUnretainedValue() as String
                // \(selectableCount). \(name) (\(id))
            }
        }
        
        // 選択可能な入力ソースの総数: \(selectableCount)
    }
    
    func testDebugInputMethodsOnly() {
        guard let inputSourceList = TISCreateInputSourceList(nil, false).takeRetainedValue() as? [TISInputSource] else {
            XCTFail("Failed to get input source list")
            return
        }
        
        // === 入力メソッドのみ（カテゴリーでフィルタ） ===
        
        var inputMethodCount = 0
        for inputSource in inputSourceList {
            // カテゴリーをチェック
            guard let categoryPtr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceCategory) else {
                continue
            }
            let category = Unmanaged<CFString>.fromOpaque(categoryPtr).takeUnretainedValue() as String
            
            // 入力メソッドカテゴリーのみを対象とする
            if category != (kTISCategoryKeyboardInputSource as String) {
                continue
            }
            
            inputMethodCount += 1
            
            if let sourceId = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID),
               let localizedName = TISGetInputSourceProperty(inputSource, kTISPropertyLocalizedName) {
                let id = Unmanaged<CFString>.fromOpaque(sourceId).takeUnretainedValue() as String
                let name = Unmanaged<CFString>.fromOpaque(localizedName).takeUnretainedValue() as String
                // \(inputMethodCount). \(name) (\(id))
                
                // 選択可能かもチェック
                if let selectablePtr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsSelectCapable) {
                    let selectable = CFBooleanGetValue(
                        Unmanaged<CFBoolean>.fromOpaque(selectablePtr).takeUnretainedValue()
                    )
                    // 選択可能: \(selectable)
                }
            }
        }
        
        // 入力メソッドの総数: \(inputMethodCount)
    }
}
