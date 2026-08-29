#!/bin/bash
# Xcode 2.5 の個別 pkg ペイロードを installer スクリプトを迂回して直接展開する。
# CLI installer が古い形式の pkg スクリプトでコケるため。
#
#   使い方（iBook で1回、パスワード入力1回）:
#     sudo bash ~/apython3/scripts/06_xcode25_extract.sh
#
# 事前に DMG がマウントされていること:
#     hdiutil attach ~/apython3/dl/xcode25_8m2558_developerdvd.dmg
set -e
set -o pipefail 2>/dev/null || true

P="/Volumes/Xcode Tools/Packages/Packages"
[ -d "$P" ] || { echo "!! '$P' が無い。先に: hdiutil attach ~/apython3/dl/xcode25_8m2558_developerdvd.dmg"; exit 1; }
[ "$(id -u)" = 0 ] || { echo "!! root で実行して: sudo bash $0"; exit 1; }

extract() {  # $1=pkg  $2=展開先
  local pkg="$1" dest="$2"
  local ar="$P/$pkg/Contents/Archive.pax.gz"
  [ -f "$ar" ] || { echo "!! $ar が無い"; return 1; }
  echo "==== $pkg -> $dest  ($(gzcat "$ar" | pax | wc -l | tr -d ' ') entries) ===="
  mkdir -p "$dest"
  gzcat "$ar" | ( cd "$dest" && pax -r -pe )
}

# SDK は /Developer 配下、残りは / 直下
extract MacOSX10.4.Universal.pkg /Developer
extract DeveloperToolsCLI.pkg    /
extract gcc4.0.pkg               /
extract DevToolsSystem.pkg       /
# 必要になったら追加: BSDSDK.pkg(/) , DevSDK.pkg(/) , DeveloperTools.pkg(/)  ※IDE本体は不要

echo
echo "==== 検証 ===="
if [ -d /Developer/SDKs/MacOSX10.4u.sdk ]; then
  echo "SDK OK: /Developer/SDKs/MacOSX10.4u.sdk"
  ls /Developer/SDKs/MacOSX10.4u.sdk/usr/include/stdio.h 2>/dev/null && echo "  usr/include OK"
  ls -d /Developer/SDKs/MacOSX10.4u.sdk/System/Library/Frameworks/Foundation.framework 2>/dev/null && echo "  Frameworks OK"
else
  echo "!! SDK が展開されていない"
fi
echo "-- compiler --"
/usr/bin/gcc-4.0 --version | head -1
echo "-- linker (cctools) --"
/usr/bin/ld -v 2>&1 | head -3 || true
echo "-- install_name_tool --"
/usr/bin/install_name_tool 2>&1 | head -2 || true

echo
echo "extract done. 次: M2 から ./run.sh 11_rebootstrap_brew"
