# ModSwitchIME リリース手順書

## 前提条件

1. **Developer ID Application証明書**がインストール済み
2. **Apple ID**と**App-Specific Password**が設定済み（.envrc）
3. **Team ID**: R7LKF73J2W

## リリース手順

### 1. コードの準備

```bash
# バージョン番号の更新（必要に応じて）
export VERSION="1.0.1"  # 新しいバージョン番号
export BUILD_NUMBER="2"  # ビルド番号

# 最新のコードを取得
git pull origin main

# すべてのテストが通ることを確認
make lint
make test
```

### 2. クリーンビルド

```bash
# ビルドディレクトリをクリーン
make clean-all

# 環境変数を読み込み
source .envrc
```

### 3. リリースビルドの作成

```bash
# Developer ID証明書でリリースビルド
DEVELOPMENT_TEAM=R7LKF73J2W CODE_SIGN_IDENTITY="Developer ID Application" make release
```

このコマンドは以下を実行します：
- クリーンビルド
- SwiftLintチェック
- テスト実行
- アーカイブ作成
- アプリのエクスポート
- DMG作成

### 4. 手動署名の確認と修正（必要な場合）

```bash
# 署名状態の確認
codesign -dvv build/export/ModSwitchIME.app

# 必要に応じて再署名（タイムスタンプ付き）
codesign --force --deep --timestamp \
  --sign "Developer ID Application: Yoshihiko Nishida (R7LKF73J2W)" \
  --options runtime \
  --entitlements ModSwitchIME/ModSwitchIME.entitlements \
  build/export/ModSwitchIME.app -v

# DMGの再作成
rm -f build/ModSwitchIME.dmg
hdiutil create -volname "ModSwitchIME" -srcfolder "build/export" \
  -ov -format UDZO "build/ModSwitchIME.dmg"
```

### 5. Notarization（公証）

```bash
# Notarizationの実行
APPLE_ID="ni@sheeda.jp" \
APPLE_PASSWORD="nvqy-ivdz-ueiy-hskj" \
DEVELOPMENT_TEAM="R7LKF73J2W" \
make notarize
```

または、.envrcに設定済みの場合：
```bash
source .envrc && make notarize
```

### 6. Notarizationステータスの確認

```bash
# ステータス確認（submission IDを使用）
xcrun notarytool info <submission-id> \
  --apple-id "$APPLE_ID" \
  --password "$APPLE_PASSWORD" \
  --team-id "$DEVELOPMENT_TEAM"
```

### 7. 配布物の最終確認

```bash
# DMGファイルの確認
ls -lh build/ModSwitchIME.dmg

# 署名の確認
spctl -a -t open --context context:primary-signature -v build/ModSwitchIME.dmg

# DMGをマウントしてアプリを確認
hdiutil attach build/ModSwitchIME.dmg
codesign -dvv /Volumes/ModSwitchIME/ModSwitchIME.app
hdiutil detach /Volumes/ModSwitchIME
```

### 8. リリース

1. **GitHubリリース**の作成
   - タグ: v1.0.1（バージョンに合わせる）
   - リリースノートを記載
   - build/ModSwitchIME.dmgをアップロード

2. **配布**
   - 公式サイトにアップロード
   - ダウンロードリンクの更新

## トラブルシューティング

### Notarizationが失敗する場合

```bash
# エラーログの確認
xcrun notarytool log <submission-id> \
  --apple-id "$APPLE_ID" \
  --password "$APPLE_PASSWORD" \
  --team-id "$DEVELOPMENT_TEAM"
```

### 一般的なエラーと対処法

1. **"The binary is not signed with a valid Developer ID certificate"**
   - Developer ID Application証明書で再署名が必要

2. **"The signature does not include a secure timestamp"**
   - `--timestamp`オプションを付けて再署名

3. **"Team ID not found"**
   - 正しいTeam IDを使用（R7LKF73J2W）

## 自動化スクリプト

完全な自動化が必要な場合は、以下のスクリプトを使用：

```bash
#!/bin/bash
# release.sh

set -e  # エラーで停止

# 環境変数の読み込み
source .envrc

# バージョン確認
echo "Current version: $VERSION"
echo "Continue? (y/n)"
read -r response
if [[ "$response" != "y" ]]; then
    exit 1
fi

# クリーンビルド
make clean-all

# リリースビルド
DEVELOPMENT_TEAM=R7LKF73J2W CODE_SIGN_IDENTITY="Developer ID Application" make release

# 再署名（確実にするため）
codesign --force --deep --timestamp \
  --sign "Developer ID Application: Yoshihiko Nishida (R7LKF73J2W)" \
  --options runtime \
  --entitlements ModSwitchIME/ModSwitchIME.entitlements \
  build/export/ModSwitchIME.app -v

# DMG再作成
rm -f build/ModSwitchIME.dmg
hdiutil create -volname "ModSwitchIME" -srcfolder "build/export" \
  -ov -format UDZO "build/ModSwitchIME.dmg"

# Notarization
make notarize

echo "Release build completed: build/ModSwitchIME.dmg"
```

## チェックリスト

- [ ] バージョン番号の更新
- [ ] CHANGELOGの更新
- [ ] すべてのテストがパス
- [ ] SwiftLintエラーなし
- [ ] Developer ID証明書で署名
- [ ] タイムスタンプ付き署名
- [ ] Notarization完了
- [ ] DMGの動作確認
- [ ] GitHubリリース作成
- [ ] ダウンロードリンク更新