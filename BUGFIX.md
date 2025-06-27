# ModSwitchIME バグ修正項目

## 概要
このドキュメントは、2025年6月27日に実施した総合システム監査で発見された設計欠陥とバグ修正項目を詳細に記載しています。修正項目は優先度別に分類され、具体的なファイル名・行番号と修正方法を含んでいます。

## 📊 修正項目サマリー

| カテゴリ | 重大 | 中程度 | 軽微 | 合計 | 修正済み |
|---------|-----|-------|-----|------|----------|
| MenuBarApp | 6 | 4 | 0 | 10 | 1 |
| KeyMonitor | 5 | 3 | 0 | 8 | 0 |
| ImeController | 6 | 4 | 0 | 10 | 2 |
| メモリ・リソース管理 | 5 | 2 | 1 | 8 | 1 |
| スレッドセーフティ | 5 | 0 | 0 | 5 | 1 |
| エラーハンドリング | 4 | 0 | 0 | 4 | 0 |
| パフォーマンス | 5 | 0 | 0 | 5 | 0 |

**合計**: 36件の重大問題、13件の中程度問題、1件の軽微問題  
**修正済み**: 5件の重大問題（ImeController重複、メモリリーク、キャッシュ競合）

---

## 🚨 重大問題（優先度: 高）

### 1. MenuBarApp設計欠陥

#### 1.1 ImeController重複インスタンス生成 ✅ **修正完了**
- **ファイル**: `MenuBarApp.swift:109`, `KeyMonitor.swift`
- **問題**: MenuBarAppとKeyMonitorがそれぞれ独自のImeControllerインスタンスを生成
- **修正内容**: 
  - ImeControllerをシングルトンパターンに変更（`static let shared = ImeController()`）
  - KeyMonitorに依存性注入を実装
  - テスト用に`createForTesting()`メソッドを追加（DEBUG環境のみ）
- **影響**: メモリリーク、パフォーマンス低下
- **修正日**: 2025-06-27

#### 1.2 単一責任原則（SRP）違反
- **ファイル**: `MenuBarApp.swift:1-200`
- **問題**: UI管理、イベント処理、設定管理、権限管理を一つのクラスで実装
- **現在の責任**:
  - NSStatusItem管理
  - アクセシビリティ権限チェック
  - KeyMonitor制御
  - IME状態監視
  - 設定ウィンドウ表示
- **推奨修正**:
  ```swift
  // 分離案
  class MenuBarController: NSObject {
      private let statusItemManager: StatusItemManager
      private let keyboardManager: KeyboardManager
      private let permissionManager: PermissionManager
  }
  ```

#### 1.3 依存関係注入の不備
- **ファイル**: `MenuBarApp.swift:12-21`
- **問題**: 具象クラスに直接依存、テスト困難
- **現在のコード**:
  ```swift
  private var keyMonitor: KeyMonitor?
  private lazy var imeController = ImeController()
  ```
- **推奨修正**:
  ```swift
  protocol IMEControlling {
      func getCurrentInputSource() -> String
      func switchToSpecificIME(_ imeId: String)
  }
  private let imeController: IMEControlling
  ```

#### 1.4 状態管理の非同期不整合
- **ファイル**: `MenuBarApp.swift:150-170`
- **問題**: アイコン更新とアプリケーション状態が非同期で不整合
- **修正方法**: 状態管理をObservableObjectパターンに統一

#### 1.5 初期化順序の依存関係問題
- **ファイル**: `MenuBarApp.swift:25-45`
- **問題**: KeyMonitor初期化前にIME状態監視を開始
- **修正方法**: 依存関係を明確化し、初期化順序を修正

#### 1.6 エラーハンドリングの分散
- **ファイル**: `MenuBarApp.swift:全体`
- **問題**: エラー処理が各メソッドに分散、一貫性なし
- **修正方法**: 統一されたエラーハンドリング戦略を実装

### 2. KeyMonitor設計欠陥

#### 2.1 CGEventTapコールバック内重処理
- **ファイル**: `KeyMonitor.swift:153-329`
- **問題**: システムレベルイベント処理内でIME切り替えを同期実行
- **現在のコード**:
  ```swift
  private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
      // 重い処理がコールバック内で実行される
      imeController.switchToSpecificIME(targetIME)
  }
  ```
- **推奨修正**:
  ```swift
  private func handleEvent(...) -> Unmanaged<CGEvent>? {
      // 軽量な処理のみ
      DispatchQueue.main.async { [weak self] in
          self?.scheduleIMESwitch(targetIME)
      }
  }
  ```

#### 2.2 複数タイマーの競合状態
- **ファイル**: `KeyMonitor.swift:39-44`
- **問題**: idle/retry/healthタイマーが非同期で競合
- **現在のタイマー**:
  - `idleTimer?: Timer?`
  - `retryTimer: Timer?`
  - `eventTapHealthTimer: Timer?`
- **修正方法**: タイマー管理を統一クラスに集約

#### 2.3 スレッドセーフティ問題
- **ファイル**: `KeyMonitor.swift:32-36`
- **問題**: `stateQueue.sync`でのデッドロック可能性
- **修正方法**: actorパターンまたは非同期処理に変更

#### 2.4 EventTap再作成の競合
- **ファイル**: `KeyMonitor.swift:501-511`
- **問題**: 複数の再作成リクエストが同時実行される可能性
- **修正方法**: 状態管理による排他制御

#### 2.5 メモリ使用量の最適化不備
- **ファイル**: `KeyMonitor.swift:25-36`
- **問題**: keyStatesの効率的でない構造体使用
- **修正方法**: より効率的なデータ構造への変更

### 3. ImeController設計欠陥

#### 3.1 CoreFoundationメモリ管理不備 ✅ **修正完了**
- **ファイル**: `ImeController.swift:186-302`
- **問題**: `TISCreateInputSourceList`の手動メモリ管理が不適切
- **修正内容**:
  - `takeRetainedValue()`を使用（自動的にメモリ管理）
  - 手動CFReleaseを削除
  - ARC下での適切なメモリ管理を実装
- **修正日**: 2025-06-27

#### 3.2 キャッシュ競合状態 ✅ **修正完了**
- **ファイル**: `ImeController.swift:11-22`
- **問題**: concurrent queueでの書き込み操作が競合
- **修正内容**:
  - cacheQueueを`.concurrent`から直列キューに変更
  - スロットリング用の専用直列キューを追加
  - スレッドセーフなキャッシュアクセスを実装
- **修正日**: 2025-06-27

#### 3.3 通知オブザーバーのリーク
- **ファイル**: `ImeController.swift:462-467`
- **問題**: 複数通知センターのクリーンアップが不完全
- **修正方法**: 各通知センターごとの個別observer管理

#### 3.4 同期処理によるUI応答性低下
- **ファイル**: `ImeController.swift:305-316`
- **問題**: `refreshCacheSync`でメインスレッドブロック
- **修正方法**: 完全非同期処理への変更

#### 3.5 スロットリング機構の非効率性
- **ファイル**: `ImeController.swift:113-149`
- **問題**: スロットリングロジックが複雑で保守困難
- **修正方法**: シンプルなデバウンス機構への変更

#### 3.6 エラー復旧の不備
- **ファイル**: `ImeController.swift:194-218`
- **問題**: リトライ機構が限定的、根本原因対処なし
- **修正方法**: より堅牢なエラー復旧戦略

### 4. メモリ・リソース管理問題

#### 4.1 ThreadSafetyUtilsセマフォリーク
- **ファイル**: `ThreadSafetyUtils.swift:17-31`
- **問題**: タイムアウト時にセマフォが適切に解放されない
- **現在のコード**:
  ```swift
  if semaphore.wait(timeout: .now() + timeout) == .timedOut {
      return nil // セマフォがリークする
  }
  ```
- **推奨修正**:
  ```swift
  let waitResult = semaphore.wait(timeout: .now() + timeout)
  defer { if waitResult == .timedOut { semaphore.signal() } }
  ```

#### 4.2 inputSourceCacheの無制限拡張
- **ファイル**: `ImeController.swift:57-73`
- **問題**: キャッシュにサイズ制限なし
- **修正方法**: LRUキャッシュまたは定期的なクリーンアップ

#### 4.3 DistributedNotificationCenter観察者リーク
- **ファイル**: `MenuBarApp.swift`, `ImeController.swift`
- **問題**: DistributedNotificationCenterの観察者が適切に削除されない
- **修正方法**: 観察者の明示的な管理とクリーンアップ

#### 4.4 タイマーの循環参照
- **ファイル**: `KeyMonitor.swift:369-374`
- **問題**: Timer内でのself強参照
- **修正方法**: [weak self]パターンの徹底

#### 4.5 CoreFoundationオブジェクトのリーク
- **ファイル**: `ImeController.swift:全体`
- **問題**: CF系オブジェクトの手動管理が不適切
- **修正方法**: Swiftラッパーまたは自動管理への移行

### 5. スレッドセーフティ問題

#### 5.1 CGEventTapコールバックでのデッドロック
- **ファイル**: `KeyMonitor.swift:153-197`
- **問題**: CGEventコールバックとメインスレッドでの相互ロック
- **修正方法**: 非同期イベント処理への変更

#### 5.2 Combineパブリッシャーの非同期更新競合
- **ファイル**: `KeyMonitor.swift:424-445`
- **問題**: Preferencesの@Publishedがマルチスレッドで競合
- **修正方法**: MainActorまたは専用キューでの処理

#### 5.3 複数DispatchQueueの依存関係不明
- **ファイル**: `ImeController.swift:12, 16, 22`
- **問題**: 3つのキューの実行順序が保証されない
- **修正方法**: キュー階層の明確化

#### 5.4 keyStatesの非原子的更新
- **ファイル**: `KeyMonitor.swift:32-36`
- **問題**: 辞書の更新操作が非原子的
- **修正方法**: actorまたはNSLockによる保護

#### 5.5 EventTap状態の競合
- **ファイル**: `KeyMonitor.swift:58-151`
- **問題**: start/stop操作の競合状態
- **修正方法**: 状態機械パターンの導入

### 6. エラーハンドリング問題

#### 6.1 エラー復旧戦略の不備
- **ファイル**: `ErrorHandling.swift:52-59`
- **問題**: 限定的なエラーのみ自動復旧対象
- **修正方法**: 包括的な復旧戦略の実装

#### 6.2 エラーレスポンス時間の問題
- **ファイル**: `ErrorHandling.swift:41-50`
- **問題**: 重要エラーでもユーザー通知が遅延
- **修正方法**: エラー重要度による即座通知

#### 6.3 エラーコンテキストの損失
- **ファイル**: `ErrorHandling.swift:76-82`
- **問題**: スタックトレースが失われる
- **修正方法**: 詳細なエラー情報の保持

#### 6.4 非同期エラーハンドリングの不備
- **ファイル**: `KeyMonitor.swift:515-535`
- **問題**: 非同期操作中のエラーが適切に伝播されない
- **修正方法**: Result型による明示的エラー処理

### 7. パフォーマンス問題

#### 7.1 同期処理によるUI応答性低下
- **ファイル**: `ImeController.swift:305-316`
- **問題**: セマフォによるメインスレッドブロック
- **修正方法**: 完全非同期処理への変更

#### 7.2 頻繁なIMEキャッシュ更新
- **ファイル**: `ImeController.swift:76-81`
- **問題**: システム通知ごとに全キャッシュ再構築
- **修正方法**: 差分更新機構の実装

#### 7.3 非効率的なタイマー管理
- **ファイル**: `KeyMonitor.swift:359-420`
- **問題**: 最適化されていない間隔設定
- **修正方法**: 動的間隔調整の実装

#### 7.4 不要なDispatchQueue作成
- **ファイル**: `ImeController.swift:12, 16, 22`
- **問題**: 類似目的で複数キュー作成
- **修正方法**: キューの統合と最適化

#### 7.5 CGEventコールバック内重処理
- **ファイル**: `KeyMonitor.swift:153-329`
- **問題**: システムレベルイベント内で重い処理
- **修正方法**: 軽量な処理のみコールバック内で実行

---

## 📊 中程度問題（優先度: 中）

### MenuBarApp中程度問題

#### M1.1 設定ウィンドウの状態管理
- **ファイル**: `MenuBarApp.swift:85-95`
- **問題**: PreferencesWindowの表示状態管理が不完全
- **修正方法**: WindowControllerパターンの採用

#### M1.2 アクセシビリティ権限チェックの頻度
- **ファイル**: `MenuBarApp.swift:60-75`
- **問題**: 権限チェックが過度に頻繁
- **修正方法**: キャッシュ機構の導入

#### M1.3 アイコン更新の効率性
- **ファイル**: `MenuBarApp.swift:180-200`
- **問題**: IME変更のたびに全アイコン再構築
- **修正方法**: 差分更新の実装

#### M1.4 通知観察者の重複登録
- **ファイル**: `MenuBarApp.swift:55-70`
- **問題**: 同じ通知に複数の観察者登録可能性
- **修正方法**: 重複チェック機構

### KeyMonitor中程度問題

#### M2.1 デバッグログの過剰出力
- **ファイル**: `KeyMonitor.swift:250-255`
- **問題**: リリースビルドでもデバッグ情報出力
- **修正方法**: ログレベル制御の実装

#### M2.2 イベントタップヘルスチェックの効率性
- **ファイル**: `KeyMonitor.swift:459-498`
- **問題**: 固定間隔でのヘルスチェック
- **修正方法**: 適応的間隔調整

#### M2.3 Preference変更の即座反映
- **ファイル**: `KeyMonitor.swift:424-445`
- **問題**: 設定変更の反映に遅延
- **修正方法**: 即座更新機構の実装

### ImeController中程度問題

#### M3.1 キャッシュ有効性の検証不足
- **ファイル**: `ImeController.swift:186-230`
- **問題**: キャッシュされたTISInputSourceの有効性未確認
- **修正方法**: 定期的な有効性チェック

#### M3.2 アプリケーションフォーカス監視の過負荷
- **ファイル**: `ImeController.swift:379-417`
- **問題**: 全アプリケーション切り替えを監視
- **修正方法**: 関連アプリのみに限定

#### M3.3 リトライ機構のスマート化不足
- **ファイル**: `ImeController.swift:194-218`
- **問題**: 固定的なリトライ戦略
- **修正方法**: エラー種別による適応的リトライ

#### M3.4 IME検証ロジックの厳格性
- **ファイル**: `ImeController.swift:254-269`
- **問題**: 過度に厳格なIME切り替え検証
- **修正方法**: 柔軟性のある検証ロジック

---

## 🔧 修正実装ガイドライン

### 短期修正（1-2週間）

1. **メモリリーク対応**
   ```swift
   // ImeController.swift
   private func buildCacheSync() {
       guard let cfInputSources = TISCreateInputSourceList(nil, false) else { return }
       defer { CFRelease(cfInputSources) } // 追加
       // 既存処理...
   }
   ```

2. **通知オブザーバーのクリーンアップ**
   ```swift
   // MenuBarApp.swift
   private var notificationObservers: [NSObjectProtocol] = []
   
   deinit {
       notificationObservers.forEach { 
           DistributedNotificationCenter.default().removeObserver($0) 
       }
   }
   ```

### 中期修正（1-2ヶ月）

1. **依存関係注入の実装**
   ```swift
   protocol IMEControlling {
       func getCurrentInputSource() -> String
       func switchToSpecificIME(_ imeId: String)
   }
   
   class MenuBarApp {
       private let imeController: IMEControlling
       
       init(imeController: IMEControlling = ImeController()) {
           self.imeController = imeController
       }
   }
   ```

2. **非同期エラーハンドリング**
   ```swift
   enum IMEResult<T> {
       case success(T)
       case failure(ModSwitchIMEError)
   }
   
   func switchToSpecificIME(_ imeId: String) async -> IMEResult<Void> {
       // 実装
   }
   ```

### 長期修正（3-6ヶ月）

1. **アーキテクチャ再設計**
   ```
   ┌─────────────────┐    ┌──────────────────┐
   │   MenuBarApp    │    │  KeyEventHandler │
   │   (UI Only)     │    │  (Event Only)    │
   └─────────────────┘    └──────────────────┘
            │                       │
            └───────┬───────────────┘
                    │
   ┌─────────────────▼─────────────────┐
   │        IMEManager                 │
   │    (Business Logic Only)          │
   └───────────────────────────────────┘
   ```

2. **状態管理の統一**
   ```swift
   @MainActor
   class AppState: ObservableObject {
       @Published var currentIME: String = ""
       @Published var isMonitoring: Bool = false
       @Published var hasPermission: Bool = false
   }
   ```

---

## 🧪 テスト戦略

### 単体テスト強化

1. **Mock・Stubの活用**
   ```swift
   class MockImeController: IMEControlling {
       var switchCallCount = 0
       var currentIME = "com.apple.keylayout.ABC"
       
       func switchToSpecificIME(_ imeId: String) {
           switchCallCount += 1
           currentIME = imeId
       }
   }
   ```

2. **メモリリークテスト**
   ```swift
   func testNoMemoryLeak() {
       weak var weakController: ImeController?
       autoreleasepool {
           let controller = ImeController()
           weakController = controller
       }
       XCTAssertNil(weakController)
   }
   ```

### 統合テスト強化

1. **システムイベントテスト**
2. **マルチスレッドテスト**
3. **エラー復旧テスト**

---

## 📈 進捗追跡

### 修正完了項目 ✅

| 日付 | 項目 | 担当 | 詳細 |
|------|------|------|------|
| 2025-06-27 | ImeController重複生成 | Claude | シングルトン化完了 |
| 2025-06-27 | CoreFoundationメモリリーク | Claude | takeRetainedValue()使用 |
| 2025-06-27 | キャッシュ競合状態 | Claude | 直列キューに変更 |
| 2025-06-27 | テストケース追加 | Claude | SingletonTests, MemoryManagementTests追加 |
| 2025-06-27 | スロットリングテスト修正 | Claude | MockableImeControllerにスロットリング実装 |

### 修正予定項目 📅

| 優先度 | 項目 | 予定日 | 担当 |
|--------|------|--------|------|
| 高 | CGEventTapコールバック重処理 | TBD | TBD |
| 高 | 通知オブザーバーのリーク | TBD | TBD |
| 高 | EventTap再作成の競合 | TBD | TBD |

---

## 📝 注意事項

1. **修正順序**: 依存関係を考慮し、下位レイヤーから修正
2. **テスト**: 各修正後に回帰テストを実施
3. **パフォーマンス**: 修正後のパフォーマンス計測を実施
4. **互換性**: 既存設定ファイルとの互換性を維持

---

## 🔄 継続的改善

1. **定期監査**: 月次でのコード品質監査
2. **メトリクス**: メモリ使用量、応答時間の継続的監視
3. **ユーザーフィードバック**: エラー報告の体系的分析

---

**最終更新**: 2025年6月27日  
**監査実施者**: Claude (Anthropic)  
**次回監査予定**: TBD