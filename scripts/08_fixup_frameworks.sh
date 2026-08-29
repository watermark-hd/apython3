#!/bin/bash
# このシステムは /System/Library/Frameworks/*/Headers も剥がされている
# （/usr/include が空だったのと同根）。CPython の _scproxy 等が使う分を
# 10.4u SDK から実フレームワークへ復元する（Headers のみ。バイナリは触らない）。
#
#   sudo bash ~/apython3/scripts/08_fixup_frameworks.sh
set -e
[ "$(id -u)" = 0 ] || { echo "!! root で: sudo bash $0"; exit 1; }
SDK=/Developer/SDKs/MacOSX10.4u.sdk
FW=/System/Library/Frameworks
SFW="$SDK/System/Library/Frameworks"

restore_headers() {  # $1 = framework 相対パス（例 CoreServices.framework/Frameworks/CarbonCore.framework）
  local rel="$1"
  local src="$SFW/$rel/Headers"
  local dst="$FW/$rel/Headers"
  if [ ! -d "$src" ]; then echo "  . $rel : SDK に Headers 無し"; return; fi
  if [ -d "$dst" ] && [ -n "$(ls -A "$dst" 2>/dev/null)" ]; then echo "  = $rel : 既にあり"; return; fi
  mkdir -p "$dst"
  ( cd "$src" && /bin/pax -rw -pe . "$dst/" )
  echo "  + $rel : $(ls "$dst" | wc -l | tr -d " ") headers"
}

echo "== CoreFoundation / CoreServices umbrella =="
restore_headers CoreFoundation.framework
for sub in CarbonCore OSServices AE LaunchServices Metadata SearchKit CFNetwork WebServicesCore DictionaryServices; do
  restore_headers "CoreServices.framework/Frameworks/$sub.framework"
done
restore_headers CoreServices.framework

echo "== Carbon umbrella（CF ヘッダが参照することがある） =="
restore_headers Carbon.framework
for sub in HIToolbox HIServices Ink NavigationServices CommonPanels Help Print SecurityHI ImageCapture SpeechRecognition CarbonSound OpenScripting; do
  restore_headers "Carbon.framework/Frameworks/$sub.framework"
done

echo "== その他 CPython が触りうるもの =="
for f in Security.framework SystemConfiguration.framework ApplicationServices.framework IOKit.framework DiskArbitration.framework; do
  restore_headers "$f"
done
# ApplicationServices もアンブレラ
for sub in ATS ColorSync CoreGraphics CoreText HIServices LangAnalysis PrintCore QD SpeechSynthesis; do
  restore_headers "ApplicationServices.framework/Frameworks/$sub.framework"
done

echo
echo "== 検証: _scproxy が include する連鎖 =="
cat > /tmp/fwtest.c <<'EOF'
#include <SystemConfiguration/SystemConfiguration.h>
#include <CoreFoundation/CoreFoundation.h>
int main(void){ CFArrayRef a = NULL; (void)a; return 0; }
EOF
export MACOSX_DEPLOYMENT_TARGET=10.4
/usr/local/bin/gcc-14 -std=c11 -c /tmp/fwtest.c -o /tmp/fwtest.o \
  -framework SystemConfiguration -framework CoreFoundation 2>&1 | head -20 \
  && echo "framework include chain OK" || echo "!! まだ何か足りない（上の No such file を見て追加）"
