#!/bin/bash
# Xcode 2.5 の DMG を検証し、インストール手順を表示する。
# 実インストールは root が要るのでこのスクリプトはやらない（手順だけ出す）。
. "$(dirname "$0")/../env.sh"

DMG="$DL/xcode25_8m2558_developerdvd.dmg"
WANT_MD5=3bd6c24d8fbbdf9007e15861d173764d
WANT_SIZE=946768492

echo "==== DMG の状態 ===="
if [ ! -f "$DMG" ]; then
  echo "未取得: $DMG"
  echo "取得中ログ: tail -f $DL/xcode_dl.log"
  exit 1
fi
sz=$(stat -f%z "$DMG" 2>/dev/null || wc -c < "$DMG")
echo "size: $sz (期待 $WANT_SIZE)"
if [ "$sz" != "$WANT_SIZE" ]; then
  echo "!! サイズ不一致。ダウンロード未完了かも。tail -f $DL/xcode_dl.log"
  exit 1
fi
echo "md5 計算中..."
got=$(md5 -q "$DMG" 2>/dev/null || openssl md5 "$DMG" | awk '{print $NF}')
echo "md5: $got (期待 $WANT_MD5)"
[ "$got" = "$WANT_MD5" ] || { echo "!! md5 不一致"; exit 1; }
echo "DMG OK"

echo
echo "==== 次に手で実行（root パスワードが要るので SSH 自動化不可） ===="
cat <<EOF
  hdiutil attach "$DMG"
  # マウント名を確認（たいてい "Xcode Tools"）
  ls /Volumes/
  # インストーラ（.mpkg のパスはマウント後に確認して調整）
  sudo installer -verbose -pkg "/Volumes/Xcode Tools/Packages/XcodeTools.mpkg" -target /
  hdiutil detach "/Volumes/Xcode Tools"

  # 確認:
  ls -d /Developer/SDKs/MacOSX10.4u.sdk
  gcc --version | head -1        # -> build 5370 になれば成功
EOF
