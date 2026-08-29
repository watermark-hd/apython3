#!/bin/bash
# このシステムの /usr/lib には C ランタイム起動オブジェクト（crt1.o / dylib1.o /
# bundle1.o / gcrt1.o）が欠けており、-isysroot を付けない素のリンクが
#   ld: can't locate file for: -lcrt1.o
# で全滅する。10.4u SDK には揃っているので、そこから /usr/lib へ補完する。
#
#   使い方（iBook で1回、パスワード入力1回）:
#     sudo bash ~/apython3/scripts/07_fixup_usrlib.sh
set -e
[ "$(id -u)" = 0 ] || { echo "!! root で: sudo bash $0"; exit 1; }
SDK=/Developer/SDKs/MacOSX10.4u.sdk
[ -d "$SDK" ] || { echo "!! $SDK が無い（先に 06_xcode25_extract）"; exit 1; }

echo "== startup オブジェクトを SDK から補完 =="
for o in crt1.o gcrt1.o dylib1.o bundle1.o lazydylib1.o; do
  if [ -e "/usr/lib/$o" ]; then
    echo "  = /usr/lib/$o (既存)"
  elif [ -e "$SDK/usr/lib/$o" ]; then
    cp -p "$SDK/usr/lib/$o" /usr/lib/ && echo "  + /usr/lib/$o"
  else
    echo "  . $o は SDK にも無し（不要かも）"
  fi
done

echo "== 共有ランタイムが無ければ補完 =="
for l in libgcc_s.10.4.dylib libgcc_s.10.5.dylib \
         libstdc++.6.dylib libstdc++.6.0.9.dylib \
         libgcc_s.1.dylib crt3.o; do
  if [ ! -e "/usr/lib/$l" ] && [ -e "$SDK/usr/lib/$l" ]; then
    cp -p "$SDK/usr/lib/$l" /usr/lib/ && echo "  + /usr/lib/$l"
  fi
done

echo
echo "== リンク検証（-isysroot なし） =="
cd /tmp
printf 'int main(void){return 0;}\n'                                   > lx.c
printf 'int f(void){return 42;}\n'                                     > ly.c
printf '#include <memory>\nint main(){auto p=std::make_shared<int>(1);return *p-1;}\n' > lz.cpp
rc=0
gcc lx.c -o lx.exe                                        && echo "  exe    OK" || { echo "  exe    FAIL"; rc=1; }
gcc -dynamiclib ly.c -o ly.dylib                          && echo "  dylib  OK" || { echo "  dylib  FAIL"; rc=1; }
gcc -bundle -undefined dynamic_lookup ly.c -o ly.bundle   && echo "  bundle OK" || { echo "  bundle FAIL"; rc=1; }
g++ lz.cpp -o lz.exe && ./lz.exe                          && echo "  c++    OK" || { echo "  c++    FAIL"; rc=1; }
echo
[ $rc = 0 ] && echo "全 OK。次: M2 から ./run.sh 10_brew_bootstrap" || echo "!! まだ失敗あり。出力を貼って。"
exit $rc
