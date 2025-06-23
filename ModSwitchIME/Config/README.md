# xcconfig設定ガイド

## 概要
このディレクトリには、ModSwitchIMEのビルド設定を管理するxcconfigファイルが含まれています。

## ファイル構成
- `Version.xcconfig` - バージョン番号の一元管理
- `Base.xcconfig` - 共通設定
- `Debug.xcconfig` - デバッグビルド設定
- `Release.xcconfig` - リリースビルド設定

## Xcodeでの設定方法

### 1. プロジェクト設定を開く
1. Xcodeで`ModSwitchIME.xcodeproj`を開く
2. プロジェクトナビゲータで`ModSwitchIME`プロジェクトを選択
3. `PROJECT`セクションの`ModSwitchIME`を選択

### 2. Configuration Filesを設定
1. `Info`タブを選択
2. `Configurations`セクションで：
   - `Debug`行の右側のドロップダウンから`Debug`を選択
   - `Release`行の右側のドロップダウンから`Release`を選択

### 3. ターゲット設定
1. `TARGETS`セクションの`ModSwitchIME`を選択
2. `Build Settings`タブを選択
3. 検索バーに`config`と入力
4. `Based on Configuration File`が適切に設定されていることを確認

## バージョン管理

### 現在のバージョンを確認
```bash
make version
```

### バージョンを更新
```bash
# バージョンを1.0.1に更新（ビルド番号は自動的に1にリセット）
make bump-version VERSION=1.0.1

# ビルド番号のみをインクリメント
make bump-build
```

### 手動でバージョンを更新
```bash
# バージョンとビルド番号を指定
./Scripts/update_version.sh 1.0.1 42
```

## 注意事項
- Info.plistの`CFBundleShortVersionString`と`CFBundleVersion`は自動的に更新されます
- xconfigファイルの変更はXcodeの再ビルドで反映されます
- コミット時は必ず`Version.xcconfig`の変更も含めてください