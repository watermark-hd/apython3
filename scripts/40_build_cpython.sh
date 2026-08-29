#!/bin/bash
# CPython 3.12 を iBook G4 上でネイティブビルドして $PREFIX に入れる。
#   - ソースは .tgz（GNU tar 1.14 は .xz 非対応のため）
#   - PGO/LTO はオフ（この toolchain では不安定・激遅）
#   - 依存は tigerbrew の openssl3 / libffi / sqlite / xz / readline / gdbm / zlib
#   - patches/*.patch があれば configure 前に適用
. "$(dirname "$0")/../env.sh"
BREW="$BREW_PREFIX/bin/brew"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

TARBALL="Python-$PY_VERSION.tgz"
SRCURL="https://www.python.org/ftp/python/$PY_VERSION/$TARBALL"
SRCDIR="$WORK/Python-$PY_VERSION"

# ---- 取得 ----
if [ ! -f "$DL/$TARBALL" ]; then
  echo "==== download $SRCURL ===="
  if ! "$PCURL" -fSL -o "$DL/$TARBALL.part" "$SRCURL"; then
    echo "!! ダウンロード失敗。利用可能な 3.12.x を確認:"
    "$PCURL" -sL https://www.python.org/ftp/python/ | grep -oE '3\.12\.[0-9]+' | sort -u -t. -k3 -n
    exit 1
  fi
  mv "$DL/$TARBALL.part" "$DL/$TARBALL"
fi
echo "sha256: $(openssl dgst -sha256 "$DL/$TARBALL" 2>/dev/null | awk '{print $NF}')"
[ -n "${PY_SHA256:-}" ] && {
  got=$(openssl dgst -sha256 "$DL/$TARBALL" | awk '{print $NF}')
  [ "$got" = "$PY_SHA256" ] || { echo "!! sha256 不一致 ($got != $PY_SHA256)"; exit 1; }
}

# ---- 展開 & パッチ（RESUME=1 かつ Makefile 既存なら丸ごとスキップ） ----
if [ "${RESUME:-0}" = 1 ] && [ -f "$SRCDIR/Makefile" ]; then
  echo "==== RESUME: 既存ツリーで make を継続（download/extract/patch/configure スキップ） ===="
  SKIP_CONFIGURE=1
else
  rm -rf "$SRCDIR"
  ( cd "$WORK" && gzip -dc "$DL/$TARBALL" | tar xf - )
  PATCH="$BREW_PREFIX/opt/gpatch/bin/patch"; [ -x "$PATCH" ] || PATCH=/usr/bin/patch
  if ls "$HERE"/patches/*.patch >/dev/null 2>&1; then
    for p in "$HERE"/patches/*.patch; do
      echo "==== apply $(basename "$p") ===="
      ( cd "$SRCDIR" && "$PATCH" -p1 --forward < "$p" ) || { echo "!! パッチ失敗: $p"; exit 1; }
    done
  fi
fi

# ---- 依存パス収集 ----
OSSL="$(brew_opt openssl3)"
FFI="$(brew_opt libffi)"
SQLITE="$(brew_opt sqlite)"
XZ="$(brew_opt xz)"
RL="$(brew_opt readline)"
GDBM="$(brew_opt gdbm)"
ZLIB="$(brew_opt zlib)"

export PKG_CONFIG_PATH="$FFI/lib/pkgconfig:$OSSL/lib/pkgconfig:$SQLITE/lib/pkgconfig:$XZ/lib/pkgconfig:$ZLIB/lib/pkgconfig"
export CPPFLAGS="-I$SQLITE/include -I$XZ/include -I$RL/include -I$GDBM/include -I$ZLIB/include"
export LDFLAGS="-L$SQLITE/lib -L$XZ/lib -L$RL/lib -L$GDBM/lib -L$ZLIB/lib"
export CFLAGS="-O2 -pipe"

# ---- configure ----
cd "$SRCDIR"
if [ "${SKIP_CONFIGURE:-0}" != 1 ]; then
  echo "==== configure ===="
  ./configure \
    --prefix="$PREFIX" \
    --with-openssl="$OSSL" \
    --with-system-ffi \
    --with-computed-gotos \
    --with-ensurepip=install \
    --enable-ipv6 \
    --disable-test-modules \
    2>&1 | tee "$HERE/logs/40_configure.log"
  echo
  echo "==== configure が検出したモジュール状況（末尾） ===="
  tail -40 "$HERE/logs/40_configure.log"
fi

# ---- make ----
echo "==== make（G4 単コア。1〜3時間） ===="
make -j1 2>&1 | tee "$HERE/logs/40_make.log"

echo "==== 失敗/未ビルドモジュールの要約 ===="
grep -nE 'Failed to build|could not be found|necessary bits' -A20 "$HERE/logs/40_make.log" || true

# ---- install ----
echo "==== make install ===="
make install 2>&1 | tee "$HERE/logs/40_install.log"

echo
"$PREFIX/bin/python3.12" -VV || { echo "!! python3.12 が起動しない"; exit 1; }
echo "build OK -> $PREFIX/bin/python3.12"
