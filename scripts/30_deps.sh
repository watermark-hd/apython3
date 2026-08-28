#!/bin/bash
# CPython 3.12 + Flask/Django に必要な C ライブラリを tigerbrew で入れる。
#   openssl3 : _ssl / _hashlib（3.12 は 1.1.1 以上必須。3.5.x を使う）
#   libffi   : _ctypes（PPC ビッグエンディアンのクロージャは要実機確認）
#   sqlite   : Django のデフォルト DB
#   xz       : _lzma
#   readline : REPL
#   gdbm     : dbm.gnu（任意）
#   zlib     : _zlib（システムは 1.2.3。念のため新しめを）
. "$(dirname "$0")/../env.sh"

if [ ! -x "$CC" ]; then echo "!! gcc-14 が無い。先に 20_toolchain。"; exit 1; fi

DEPS="openssl3 libffi sqlite xz readline gdbm zlib"
for f in $DEPS; do
  if brew_installed "$f"; then
    echo "already: $f $(ls "$BREW_PREFIX/Cellar/$f")"
  else
    echo "==== install: $f ===="
    "$BREW" install --force-bottle "$f" 2>&1 | tail -30 \
      || "$BREW" install --build-from-source "$f" 2>&1 | tail -60
    brew_installed "$f" || echo "!! $f インストールできず"
  fi
done

echo
echo "==== CA 証明書バンドル（ca-certificates formula が無いので curl.se から取得） ===="
CACERT="$PREFIX/etc/cacert.pem"
mkdir -p "$PREFIX/etc"
"$PCURL" -fsSL -o "$CACERT" https://curl.se/ca/cacert.pem && \
  echo "  -> $CACERT ($(wc -c < "$CACERT") bytes)"

echo
echo "==== 結果 ===="
"$BREW" list --versions $DEPS 2>&1
for f in $DEPS; do echo "  opt/$f -> $(readlink "$BREW_PREFIX/opt/$f" 2>/dev/null || echo '?')"; done
