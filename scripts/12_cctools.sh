#!/bin/bash
# モダンな cctools / ld64 をソースからビルドする。
# これが入ると install_name_tool / otool / ld が新 Mach-O を扱えるようになり、
# 以後 tiger_altivec の bottle が pour できるようになる（今はここで詰まっている）。
. "$(dirname "$0")/../env.sh"

if [ ! -d /Developer/SDKs/MacOSX10.4u.sdk ]; then
  echo "!! 10.4u SDK が無い。先に Xcode 2.5。"; exit 1
fi

# システムコンパイラでビルドさせる（gcc-14 はまだ無い）
export HOMEBREW_CC=gcc-4.0
unset CC CXX

for f in cctools ld64; do
  if brew_installed "$f"; then
    echo "== $f: already =="
    continue
  fi
  echo "== brew install --build-from-source $f =="
  "$BREW" install --build-from-source "$f" 2>&1 | tail -60
done

echo
echo "==== 確認: 新しい install_name_tool / ld ===="
for t in install_name_tool otool ld lipo; do
  p="$BREW_PREFIX/opt/cctools/bin/$t"
  [ -x "$p" ] || p="$BREW_PREFIX/opt/ld64/bin/$t"
  [ -x "$p" ] || p="$BREW_PREFIX/bin/$t"
  printf '%s -> %s\n' "$t" "$p"
done
"$BREW_PREFIX/bin/install_name_tool" 2>&1 | head -2 || true

echo
echo "==== bottle pour の再確認: 小さい formula で試す ===="
"$BREW" install --force-bottle xz 2>&1 | tail -20
brew_installed xz && "$BREW_PREFIX/opt/xz/bin/xz" --version

echo
echo "cctools done"
