#!/bin/bash
# pip を最新化し、証明書を設定する。
. "$(dirname "$0")/../env.sh"
PY="$PREFIX/bin/python3.12"
export SSL_CERT_FILE="$PREFIX/etc/cacert.pem"
export PIP_CERT="$PREFIX/etc/cacert.pem"

if ! "$PY" -m pip --version 2>/dev/null; then
  echo "==== ensurepip ===="
  "$PY" -m ensurepip --upgrade || {
    echo "ensurepip 失敗 -> get-pip.py で再試行"
    "$PCURL" -fsSL -o "$WORK/get-pip.py" https://bootstrap.pypa.io/get-pip.py
    "$PY" "$WORK/get-pip.py"
  }
fi

echo "==== pip / setuptools / wheel を更新 ===="
"$PY" -m pip install --upgrade pip setuptools wheel

echo "==== 恒久設定を書き込む ===="
"$PY" -m pip config set global.cert "$PREFIX/etc/cacert.pem"
"$PY" -m pip config list

"$PY" -m pip --version
