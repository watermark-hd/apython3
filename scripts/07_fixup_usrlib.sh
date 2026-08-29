#!/bin/bash
# この Tiger は /usr/include がほぼ空・/usr/lib も startup オブジェクトや
# libSystemStubs.a 等が欠落しており、-isysroot 無しの素ビルドが全滅する。
# 10.4u SDK は完全なので、そこからシステムへ復元する。
#
#   使い方（iBook で1回）:  sudo bash ~/apython3/scripts/07_fixup_usrlib.sh
set -e
[ "$(id -u)" = 0 ] || { echo "!! root で: sudo bash $0"; exit 1; }
export MACOSX_DEPLOYMENT_TARGET=10.4      # 未設定だと gcc-4.0 が 10.1 を既定にして -undefined dynamic_lookup が壊れる
SDK=/Developer/SDKs/MacOSX10.4u.sdk
[ -d "$SDK" ] || { echo "!! $SDK が無い"; exit 1; }

echo "== /usr/include を SDK から復元（既存ファイルは上書きしない） =="
n=$(find /usr/include -type f 2>/dev/null | wc -l | tr -d ' ')
echo "  現在 $n files"
if [ "$n" -lt 100 ]; then
  ( cd "$SDK/usr/include" && /bin/pax -rw -pe . /usr/include/ )
  echo "  -> $(find /usr/include -type f | wc -l | tr -d ' ') files"
else
  echo "  十分あるのでスキップ"
fi

echo "== /usr/lib: SDK にあってシステムに無い .o/.a/.dylib を補完 =="
cd "$SDK/usr/lib"
for f in *.o *.a *.dylib; do
  [ -e "$f" ] || continue
  if [ ! -e "/usr/lib/$f" ]; then
    cp -Rp "$f" /usr/lib/ && echo "  + /usr/lib/$f"
  fi
done

echo "== フレームワークのヘッダ有無（Python が使う分） =="
for fw in CoreFoundation CoreServices SystemConfiguration Security ApplicationServices; do
  h="/System/Library/Frameworks/$fw.framework/Headers"
  if [ -d "$h" ]; then
    echo "  = $fw OK"
  elif [ -d "$SDK/System/Library/Frameworks/$fw.framework/Headers" ]; then
    # 実フレームワークにヘッダだけ足す（バイナリは触らない）
    mkdir -p "$h"
    ( cd "$SDK/System/Library/Frameworks/$fw.framework/Headers" && /bin/pax -rw -pe . "$h/" )
    echo "  + $fw ヘッダ復元"
  else
    echo "  ? $fw ヘッダ SDK にも無し"
  fi
done

echo
echo "== リンク検証（-isysroot なし / deploy target=10.4） =="
cd /tmp
printf 'int main(void){return 0;}\n'                                                   > lx.c
printf 'int f(void){return 42;}\n'                                                     > ly.c
printf '#include <stdio.h>\n#include <memory>\nint main(){auto p=std::make_shared<int>(7);printf("%%d\\n",*p);return 0;}\n' > lz.cpp
rc=0
gcc lx.c -o lx.exe                                       && echo "  exe    OK" || { echo "  exe    FAIL"; rc=1; }
gcc -dynamiclib ly.c -o ly.dylib                         && echo "  dylib  OK" || { echo "  dylib  FAIL"; rc=1; }
gcc -bundle -undefined dynamic_lookup ly.c -o ly.bundle  && echo "  bundle OK" || { echo "  bundle FAIL"; rc=1; }
g++ lz.cpp -o lz.exe && ./lz.exe                         && echo "  c++    OK" || { echo "  c++    FAIL"; rc=1; }
echo
[ $rc = 0 ] && echo "全 OK。次: M2 から ./run.sh 10_brew_bootstrap" || echo "!! まだ失敗あり。出力を貼って。"
exit $rc
