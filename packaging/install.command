#!/bin/bash
# apython312 — Python 3.12 for Mac OS X 10.4 Tiger (PowerPC)
# Finder でダブルクリックするとこのスクリプトが Terminal で実行されます。
set -e
cd "$(dirname "$0")"

TARBALL=$(ls apython312-*-macosx10.4-powerpc.tar.bz2 2>/dev/null | head -1)
[ -n "$TARBALL" ] || { echo "!! $(pwd) に apython312-*.tar.bz2 が見つかりません"; exit 1; }

DEFAULT="$HOME/Applications/apython312"
echo "=========================================================="
echo " apython312 installer"
echo "=========================================================="
printf "インストール先 [%s]: " "$DEFAULT"
read DEST
[ -n "$DEST" ] || DEST="$DEFAULT"
# ~ 展開
case "$DEST" in "~"*) DEST="$HOME${DEST#~}";; esac
PARENT=$(dirname "$DEST")

if [ -e "$DEST" ]; then
  printf "%s は既に存在します。削除して入れ直しますか? [y/N]: " "$DEST"
  read yn; case "$yn" in [yY]*) rm -rf "$DEST";; *) echo "中止"; exit 1;; esac
fi

echo "-> 展開中: $DEST"
mkdir -p "$PARENT"
tar xjf "$TARBALL" -C "$PARENT"
# tarball の中身は apython312/ なので、DEST 名が違うならリネーム
[ "$(basename "$DEST")" = "apython312" ] || mv "$PARENT/apython312" "$DEST"

echo "-> bin/ の shebang を $DEST に合わせて書き換え"
for f in "$DEST"/bin/*; do
  [ -f "$f" ] || continue
  case "$(head -1 "$f" 2>/dev/null)" in
    "#!"*python*) /usr/bin/sed -i.bak "1s|^#!.*|#!$DEST/bin/python3.12|" "$f" && rm -f "$f.bak";;
  esac
done

echo "-> 動作確認"
"$DEST/bin/python3.12" -c 'import ssl,sqlite3,ctypes; print("Python", __import__("platform").python_version(), "OK  /  OpenSSL", ssl.OPENSSL_VERSION)'

cat <<EOF

=========================================================="
 完了しました。

   $DEST/bin/python3.12

 PATH に通すには ~/.bash_profile に次を追加:

   export PATH="$DEST/bin:\$PATH"

 パッケージのインストール例:
   $DEST/bin/python3.12 -m pip install flask "django>=5.2,<5.3"

 注意: Rust を要するパッケージ（cryptography>=3.4 等）は入りません。
       C 拡張を含むパッケージは、このマシンにビルド環境が無い場合
       純 Python フォールバックがあるものだけ入ります。
=========================================================="
EOF
