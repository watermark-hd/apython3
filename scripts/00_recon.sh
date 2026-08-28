#!/bin/bash
# iBook G4 の環境を再確認する。何度実行しても副作用なし。
. "$(dirname "$0")/../env.sh"

echo "==== OS / CPU ===="
uname -a
sw_vers
sysctl -n hw.model hw.cpufrequency hw.memsize hw.ncpu 2>/dev/null
df -h / /usr/local "$HOME"

echo "==== システムコンパイラ ===="
/usr/bin/gcc --version 2>&1 | head -1

echo "==== tigerbrew ===="
"$BREW_PREFIX/bin/brew" --version 2>&1 | head -1
"$BREW_PREFIX/bin/brew" list 2>&1 | tr '\n' ' '; echo

echo "==== 目標コンパイラ ===="
if [ -x "$CC" ]; then "$CC" --version 2>&1 | head -1; else echo "未インストール: $CC"; fi

echo "==== TLS 到達性 (portable-curl) ===="
for u in https://pypi.org/simple/ https://www.python.org/ https://archive.org/download/tigerbrew/ ; do
  printf '%s -> ' "$u"
  "$PCURL" -sI -o /dev/null -w '%{http_code}\n' "$u" 2>&1
done

echo "==== 既存の apython312 ===="
if [ -x "$PREFIX/bin/python3.12" ]; then
  "$PREFIX/bin/python3.12" -VV
else
  echo "未ビルド: $PREFIX/bin/python3.12"
fi
