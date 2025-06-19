#!/bin/bash

# アクセシビリティ権限をリセットするスクリプト
# 開発中の権限問題を解決するために使用

echo "ModSwitchIME のアクセシビリティ権限をリセットします..."

# Bundle IDを取得
BUNDLE_ID="${PRODUCT_BUNDLE_IDENTIFIER:-com.shun-fu-tech.ModSwitchIME}"

# TCCデータベースから権限を削除（要管理者権限）
echo "TCCデータベースから権限を削除中..."
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
    "DELETE FROM access WHERE client='$BUNDLE_ID';"

# ユーザーのTCCデータベースからも削除
USER_TCC="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
if [ -f "$USER_TCC" ]; then
    sqlite3 "$USER_TCC" "DELETE FROM access WHERE client='$BUNDLE_ID';" 2>/dev/null
fi

echo "権限がリセットされました。次回アプリ起動時に権限を再度要求します。"
echo ""
echo "注意: 本番環境では、適切なコード署名により、この問題は発生しません。"