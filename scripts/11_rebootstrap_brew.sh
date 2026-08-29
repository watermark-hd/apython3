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
echo "tarball: $(wc -c < "$TB") bytes"
gzip -t "$TB" 2>/dev/null || { echo "!! gzip 整合性 NG（HTML エラーページ？）"; dd if="$TB" bs=1 count=200 2>/dev/null; echo; exit 1; }
rm -rf "$EX" && mkdir -p "$EX"
# Tiger の GNU tar 1.14 は --strip-components 非対応。素で展開して単一トップに入る。
( cd "$EX" && gzip -dc "$TB" | tar xf - )
TOP="$EX/$(ls "$EX" | head -1)"
echo "展開: $TOP"
[ -d "$TOP/Library/Homebrew" ] || { echo "!! $TOP に Library/Homebrew が無い。中身: $(ls "$TOP" | tr '\n' ' ')"; exit 1; }
ls "$TOP/Library" | tr '\n' ' '; echo

echo "==== バックアップ（Library/Homebrew と bin/brew のみ） ===="
ts=$(date +%Y%m%d-%H%M%S)
mkdir -p "$HOME/apython3/brew-backup-$ts"
cp -Rp "$BREW_PREFIX/bin/brew" "$HOME/apython3/brew-backup-$ts/" 2>/dev/null || true
cp -Rp "$BREW_PREFIX/Library/Homebrew" "$HOME/apython3/brew-backup-$ts/" 2>/dev/null || true
echo "-> $HOME/apython3/brew-backup-$ts"

echo "==== コードを上書き（状態ディレクトリは除外） ===="
rsync -a --delete \
  --exclude 'vendor/' \
  "$TOP/Library/Homebrew/" "$BREW_PREFIX/Library/Homebrew/"
rsync -a "$TOP/Library/ENV/"           "$BREW_PREFIX/Library/ENV/"           2>/dev/null || true
rsync -a "$TOP/Library/Aliases/"       "$BREW_PREFIX/Library/Aliases/"       2>/dev/null || true
rsync -a "$TOP/Library/Contributions/" "$BREW_PREFIX/Library/Contributions/" 2>/dev/null || true
rsync -a --delete "$TOP/Library/Formula/" "$BREW_PREFIX/Library/Formula/"
cp -p "$TOP/bin/brew" "$BREW_PREFIX/bin/brew"

echo "==== 確認 ===="
"$BREW" --version 2>&1 | head -2
"$BREW" config 2>&1 | grep -iE "HOMEBREW_VERSION|CLT|Xcode|GCC|SDK"

echo
if [ "${INSTALL_GIT:-0}" = 1 ]; then
  echo "==== git を入れる（依存が多く長い。INSTALL_GIT=1 指定時のみ） ===="
  brew_installed git && echo "git: already" || \
    "$BREW" install git 2>&1 | tail -40 || echo "!! git ビルド失敗。tarball 運用で続行。"
else
  echo "（git インストールはスキップ。必要なら INSTALL_GIT=1 で再実行。tarball 運用で進む）"
fi

echo
echo "rebootstrap done"
