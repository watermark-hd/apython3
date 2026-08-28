#!/bin/bash
# tigerbrew を使える状態にし、小さな補助ツールを入れる。
# tigerbrew 本体はインストール済み・Formula ツリーも展開済み（git チェックアウトではない）。
# git checkout ではないので `brew update` は不可。既存スナップショットのまま使う。
. "$(dirname "$0")/../env.sh"

BREW="$BREW_PREFIX/bin/brew"

echo "==== brew doctor（参考。失敗しても続行） ===="
"$BREW" doctor 2>&1 | head -40 || true

# HOMEBREW_DEVELOPER などは不要。ネットワークは portable-curl 経由で brew が自前で使う。
echo "==== 補助ツールを入れる ===="
# gpatch: パッチ適用（システム patch は BSD 版で -p の癖がある）
# pkg-config: CPython configure の各種検出
# xz: 使うかもしれないので（Python ソースは .tgz を使うので必須ではない）
for f in gpatch pkg-config xz; do
  if "$BREW" list --versions "$f" >/dev/null 2>&1; then
    echo "  already: $f"
  else
    echo "  install: $f"
    "$BREW" install "$f" 2>&1 | tail -20
  fi
done

echo "==== 結果 ===="
"$BREW" list --versions gpatch pkg-config xz 2>&1
