#!/bin/bash
# 現行 tigerbrew(mistydemeo/tigerbrew master) のコードを /usr/local に上書きして
# brew 0.9.5 の pkgutil ハードエラー等を解消する。
#   - git は無いので tarball で持ってくる（後で brew install git して git 化する）
#   - Cellar / opt / etc / var / Taps / vendor などの状態は保持する
. "$(dirname "$0")/../env.sh"

# --- 事前チェック: 10.4u SDK が無いとどのみち何もビルドできない ---
if [ ! -d /Developer/SDKs/MacOSX10.4u.sdk ]; then
  echo "!! /Developer/SDKs/MacOSX10.4u.sdk が無い。先に scripts/05_xcode25.sh の手順で Xcode 2.5 を入れること。"
  exit 1
fi

TB="$WORK/tigerbrew-master.tar.gz"
EX="$WORK/tigerbrew-src"

echo "==== 現行 tigerbrew を取得 ===="
"$PCURL" -fSL -o "$TB" "https://github.com/mistydemeo/tigerbrew/archive/refs/heads/master.tar.gz"
rm -rf "$EX" && mkdir -p "$EX"
( cd "$EX" && gzip -dc "$TB" | tar xf - --strip-components=1 )
echo "取得: $(ls "$EX" | tr '\n' ' ')"

echo "==== バックアップ（Library/Homebrew と bin/brew のみ） ===="
ts=$(date +%Y%m%d-%H%M%S)
mkdir -p "$HOME/apython3/brew-backup-$ts"
cp -Rp "$BREW_PREFIX/bin/brew" "$HOME/apython3/brew-backup-$ts/" 2>/dev/null || true
cp -Rp "$BREW_PREFIX/Library/Homebrew" "$HOME/apython3/brew-backup-$ts/" 2>/dev/null || true
echo "-> $HOME/apython3/brew-backup-$ts"

echo "==== コードを上書き（状態ディレクトリは除外） ===="
rsync -a --delete \
  --exclude 'Library/Homebrew/vendor/' \
  "$EX/Library/Homebrew/" "$BREW_PREFIX/Library/Homebrew/"
rsync -a "$EX/Library/ENV/"          "$BREW_PREFIX/Library/ENV/"          2>/dev/null || true
rsync -a "$EX/Library/Aliases/"      "$BREW_PREFIX/Library/Aliases/"      2>/dev/null || true
rsync -a "$EX/Library/Contributions/" "$BREW_PREFIX/Library/Contributions/" 2>/dev/null || true
rsync -a --delete "$EX/Library/Formula/" "$BREW_PREFIX/Library/Formula/"
cp -p "$EX/bin/brew" "$BREW_PREFIX/bin/brew"

echo "==== 確認 ===="
"$BREW" --version 2>&1 | head -2
"$BREW" config 2>&1 | grep -iE "HOMEBREW_VERSION|CLT|Xcode|GCC|SDK"

echo
echo "==== git を入れて本物の checkout にする（失敗しても tarball 運用で続行可） ===="
if brew_installed git; then
  echo "git: already"
else
  "$BREW" install git 2>&1 | tail -30 || echo "!! git ビルド失敗。tarball 運用のまま進める。"
fi
if [ -x "$BREW_PREFIX/bin/git" ]; then
  cd "$BREW_PREFIX"
  "$BREW_PREFIX/bin/git" init -q 2>/dev/null || true
  "$BREW_PREFIX/bin/git" config --global --add safe.directory /usr/local 2>/dev/null || true
  "$BREW_PREFIX/bin/git" remote add origin https://github.com/mistydemeo/tigerbrew.git 2>/dev/null || true
  echo "git checkout 化の準備done（必要なら手で fetch/reset）"
fi

echo
echo "rebootstrap done"
