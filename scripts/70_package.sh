#!/bin/bash
# ~/apython312 を再配置可能なパッケージにする。
#   - .so が引く /usr/local dylib 8 本を lib/_vendor/ に同梱
#   - install name を @loader_path 相対に書き換え
#   - bin/ の shebang は install.command 側で最終パスに書換
#   - 生成物: dist/apython312-<ver>-macosx10.4-powerpc.tar.bz2 + install.command + README.txt
#             さらに dist/apython312-<ver>-macosx10.4-powerpc.dmg（ダブルクリック配布用）
. "$(dirname "$0")/../env.sh"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

VER="$("$PREFIX/bin/python3.12" -c 'import platform;print(platform.python_version())')"
STAGE="$WORK/pkgstage"
PKGROOT="$STAGE/apython312"
DIST="$HERE/dist"
BASE="apython312-$VER-macosx10.4-powerpc"

rm -rf "$STAGE"; mkdir -p "$PKGROOT" "$DIST"
echo "==== コピー: $PREFIX -> $PKGROOT ===="
( cd "$PREFIX" && /bin/pax -rw -pe . "$PKGROOT/" )

echo "==== 不要物のトリム ===="
rm -rf "$PKGROOT/lib/python3.12/test" \
       "$PKGROOT/lib/python3.12/"*/test "$PKGROOT/lib/python3.12/"*/tests \
       "$PKGROOT/lib/python3.12/turtledemo" \
       "$PKGROOT/lib/python3.12/tkinter" \
       "$PKGROOT/lib/python3.12/idlelib" \
       "$PKGROOT/share/doc"
find "$PKGROOT" -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true

VEND="$PKGROOT/lib/_vendor"
mkdir -p "$VEND"
INT="$BREW_PREFIX/opt/cctools/bin/install_name_tool"
[ -x "$INT" ] || INT=/usr/bin/install_name_tool
OTOOL="$BREW_PREFIX/opt/cctools/bin/otool"
[ -x "$OTOOL" ] || OTOOL=/usr/bin/otool

echo "==== vendor dylib 収集（.so から再帰的に） ===="
# 開始集合
resolve() { r="$1"; while [ -L "$r" ]; do d=$(dirname "$r"); r="$d/$(readlink "$r")"; done; echo "$r"; }
collect() {  # 引数のバイナリが引く /usr/local dylib を $VEND にコピー（再帰）
  local bin="$1" dep real bn
  for dep in $("$OTOOL" -L "$bin" 2>/dev/null | grep -oE '/usr/local/[^ ]+\.dylib'); do
    bn=$(basename "$dep")
    [ -f "$VEND/$bn" ] && continue
    real=$(resolve "$dep")
    [ -f "$real" ] || { echo "  !! 見つからない: $dep"; continue; }
    cp -p "$real" "$VEND/$bn"; chmod u+w "$VEND/$bn"
    echo "  + $bn  (<- $real)"
    collect "$VEND/$bn"
  done
}
for so in "$PKGROOT"/lib/python3.12/lib-dynload/*.so; do collect "$so"; done

echo "==== install name 書き換え ===="
# vendor 内: id を @loader_path/<name> に、相互依存も @loader_path/ に
for lib in "$VEND"/*.dylib; do
  bn=$(basename "$lib")
  "$INT" -id "@loader_path/$bn" "$lib"
  for dep in $("$OTOOL" -L "$lib" | grep -oE '/usr/local/[^ ]+\.dylib'); do
    "$INT" -change "$dep" "@loader_path/$(basename "$dep")" "$lib"
  done
done
# .so 側: /usr/local/... を @loader_path/../../_vendor/<name> に
#   .so は lib/python3.12/lib-dynload/ にあり、_vendor は lib/_vendor/ なので ../../
for so in "$PKGROOT"/lib/python3.12/lib-dynload/*.so; do
  for dep in $("$OTOOL" -L "$so" | grep -oE '/usr/local/[^ ]+\.dylib'); do
    "$INT" -change "$dep" "@loader_path/../../_vendor/$(basename "$dep")" "$so"
  done
done

echo "==== 検証: 残存 /usr/local 参照 ===="
LEFT=$(for f in "$PKGROOT"/bin/python3.12 "$PKGROOT"/lib/python3.12/lib-dynload/*.so "$VEND"/*.dylib; do "$OTOOL" -L "$f"; done | grep -c '/usr/local' || true)
echo "  残り $LEFT 件（0 が目標）"
"$OTOOL" -L "$PKGROOT"/lib/python3.12/lib-dynload/_ssl*.so | sed 's/^/    /'

echo "==== 別パスで実起動テスト ===="
TESTDIR="$WORK/reloc-test"; rm -rf "$TESTDIR"; mkdir -p "$TESTDIR"
( cd "$STAGE" && /bin/pax -rw -pe apython312 "$TESTDIR/" )
sed -i.bak "1s|.*|#!$TESTDIR/apython312/bin/python3.12|" "$TESTDIR/apython312/bin/"* 2>/dev/null || true
"$TESTDIR/apython312/bin/python3.12" - <<'EOF'
import ssl, sqlite3, ctypes, lzma, readline, _gdbm, zlib, hashlib
c = sqlite3.connect(":memory:"); c.execute("create table t(x)"); c.execute("insert into t values(1)")
print("relocated run OK / ssl:", ssl.OPENSSL_VERSION, "/ sqlite:", sqlite3.sqlite_version)
EOF

echo "==== アーカイブ生成 ===="
( cd "$STAGE" && tar cf - apython312 | bzip2 -9 > "$DIST/$BASE.tar.bz2" )
cp "$HERE/packaging/install.command" "$DIST/" 2>/dev/null || true
cp "$HERE/packaging/PACKAGE_README.txt" "$DIST/README.txt" 2>/dev/null || true
ls -la "$DIST"

echo "==== dmg 生成（Tiger hdiutil） ===="
DMGSRC="$WORK/dmgsrc"; rm -rf "$DMGSRC"; mkdir -p "$DMGSRC"
cp "$DIST/$BASE.tar.bz2" "$DMGSRC/"
cp "$HERE/packaging/install.command" "$DMGSRC/" 2>/dev/null || true
cp "$HERE/packaging/PACKAGE_README.txt" "$DMGSRC/README.txt" 2>/dev/null || true
hdiutil create -fs HFS+ -volname "apython312 $VER" -srcfolder "$DMGSRC" -ov "$DIST/$BASE.dmg" && \
  echo "  -> $DIST/$BASE.dmg"

echo
echo "package done -> $DIST/"
