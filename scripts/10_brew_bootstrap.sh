#!/bin/bash
# tigerbrew を使える状態にし、小さな補助ツールを入れる。
# tigerbrew 本体はインストール済み・Formula ツリーも展開済み（git チェックアウトではない）。
# git checkout ではないので `brew update` は不可。既存スナップショットのまま使う。
. "$(dirname "$0")/../env.sh"

echo "==== brew doctor（参考。失敗しても続行） ===="
"$BREW" doctor 2>&1 | head -40 || true

echo "==== 補助ツールを入れる（gpatch / pkg-config / xz） ===="
for f in gpatch pkg-config xz; do
  if brew_installed "$f"; then
    echo "  already: $f"
  else
    echo "  install: $f"
    "$BREW" install "$f" 2>&1 | tail -30 || echo "  !! $f 失敗"
  fi
done

echo "==== 結果 ===="
for f in gpatch pkg-config xz; do
  printf '%s: ' "$f"; brew_installed "$f" && echo "$(ls "$BREW_PREFIX/Cellar/$f")" || echo "NOT installed"
done
