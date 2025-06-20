#!/bin/bash
# ModSwitchIME Release Script
# 本番配布用のDMGを作成する自動化スクリプト

set -e  # エラーで停止

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}ModSwitchIME Release Builder${NC}"
echo "==============================="

# 環境変数の読み込み
if [ -f .envrc ]; then
    source .envrc
    echo -e "${GREEN}✓ Environment variables loaded${NC}"
else
    echo -e "${RED}✗ .envrc not found${NC}"
    exit 1
fi

# 必要な環境変数のチェック
if [ -z "$DEVELOPMENT_TEAM" ] || [ -z "$APPLE_ID" ] || [ -z "$APPLE_PASSWORD" ]; then
    echo -e "${RED}✗ Required environment variables not set${NC}"
    echo "Please ensure DEVELOPMENT_TEAM, APPLE_ID, and APPLE_PASSWORD are set in .envrc"
    exit 1
fi

# バージョン情報の表示
echo -e "\n${BLUE}Build Configuration:${NC}"
echo "  Version: ${VERSION:-1.0.0}"
echo "  Build: ${BUILD_NUMBER:-1}"
echo "  Team ID: ${DEVELOPMENT_TEAM}"
echo ""

# 確認
echo -e "${YELLOW}This will create a production release. Continue? (y/n)${NC}"
read -r response
if [[ "$response" != "y" ]]; then
    echo "Release cancelled."
    exit 0
fi

# 1. クリーンビルド
echo -e "\n${BLUE}1. Cleaning build artifacts...${NC}"
make clean-all

# 2. テスト実行
echo -e "\n${BLUE}2. Running tests...${NC}"
make test

# 3. リリースビルド作成
echo -e "\n${BLUE}3. Creating release build...${NC}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" \
CODE_SIGN_IDENTITY="Developer ID Application" \
make archive

# 4. アプリのエクスポート
echo -e "\n${BLUE}4. Exporting app...${NC}"
make package

# 5. 再署名（タイムスタンプ付き）
echo -e "\n${BLUE}5. Re-signing with timestamp...${NC}"
codesign --force --deep --timestamp \
  --sign "Developer ID Application: Yoshihiko Nishida (${DEVELOPMENT_TEAM})" \
  --options runtime \
  --entitlements ModSwitchIME/ModSwitchIME.entitlements \
  build/export/ModSwitchIME.app -v

# 署名の確認
echo -e "\n${BLUE}Verifying signature...${NC}"
codesign -dvv build/export/ModSwitchIME.app 2>&1 | grep -E "Authority|TeamIdentifier|Timestamp"

# 6. DMG作成
echo -e "\n${BLUE}6. Creating DMG...${NC}"
rm -f build/ModSwitchIME.dmg
hdiutil create -volname "ModSwitchIME" -srcfolder "build/export" \
  -ov -format UDZO "build/ModSwitchIME.dmg"

# 7. Notarization
echo -e "\n${BLUE}7. Starting notarization...${NC}"
echo "This may take 5-15 minutes..."

# Notarizationの実行
RESPONSE=$(xcrun notarytool submit "build/ModSwitchIME.dmg" \
  --apple-id "${APPLE_ID}" \
  --password "${APPLE_PASSWORD}" \
  --team-id "${DEVELOPMENT_TEAM}" \
  --wait 2>&1)

# Submission IDの抽出
SUBMISSION_ID=$(echo "$RESPONSE" | grep -E "id: [a-f0-9-]+" | head -1 | awk '{print $2}')

if [ -z "$SUBMISSION_ID" ]; then
    echo -e "${RED}✗ Failed to get submission ID${NC}"
    echo "$RESPONSE"
    exit 1
fi

echo "Submission ID: $SUBMISSION_ID"

# ステータスの確認
STATUS=$(echo "$RESPONSE" | grep -E "status: [A-Za-z]+" | tail -1 | awk '{print $2}')

if [ "$STATUS" = "Accepted" ]; then
    echo -e "${GREEN}✓ Notarization accepted${NC}"
    
    # 8. Staple
    echo -e "\n${BLUE}8. Stapling notarization...${NC}"
    xcrun stapler staple "build/ModSwitchIME.dmg"
    
    echo -e "\n${GREEN}✓ Release build completed successfully!${NC}"
    echo -e "Output: ${BLUE}build/ModSwitchIME.dmg${NC}"
    
    # 最終確認
    echo -e "\n${BLUE}Final verification:${NC}"
    spctl -a -t open --context context:primary-signature -v build/ModSwitchIME.dmg
    
else
    echo -e "${RED}✗ Notarization failed with status: $STATUS${NC}"
    echo "Check the log with:"
    echo "xcrun notarytool log $SUBMISSION_ID --apple-id \"$APPLE_ID\" --password \"$APPLE_PASSWORD\" --team-id \"$DEVELOPMENT_TEAM\""
    exit 1
fi

echo -e "\n${GREEN}🎉 Release ready for distribution!${NC}"