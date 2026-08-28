#!/bin/bash
# ビルドした python3.12 の要所を確認する。web スタックに効くモジュール中心。
. "$(dirname "$0")/../env.sh"
PY="$PREFIX/bin/python3.12"
export SSL_CERT_FILE="$PREFIX/etc/cacert.pem"

"$PY" -VV
echo "sys.byteorder / platform:"
"$PY" -c "import sys,platform;print(sys.byteorder, platform.platform())"

echo
echo "==== 標準モジュール import ===="
"$PY" - <<'EOF'
mods = ["ssl","hashlib","_hashlib","ctypes","sqlite3","lzma","bz2","zlib",
        "decimal","readline","socket","select","struct","array","zoneinfo",
        "unicodedata","_datetime","_csv","json","xml.etree.ElementTree",
        "concurrent.futures","multiprocessing","asyncio"]
ok, bad = [], []
for m in mods:
    try:
        __import__(m); ok.append(m)
    except Exception as e:
        bad.append(f"{m}: {e!r}")
print("OK  :", ", ".join(ok))
print("FAIL:", "\n       ".join(bad) if bad else "(none)")
EOF

echo
echo "==== ctypes 実呼び出し（ビッグエンディアンで壊れやすい箇所） ===="
"$PY" - <<'EOF'
import ctypes, ctypes.util
libc = ctypes.CDLL(ctypes.util.find_library("c") or "/usr/lib/libc.dylib")
libc.printf(b"  ctypes printf ok: %d %s\n", 123, b"str")
# 構造体・戻り値の型
libc.strlen.restype = ctypes.c_size_t
libc.strlen.argtypes = [ctypes.c_char_p]
assert libc.strlen(b"hello") == 5
# コールバック（クロージャ）
CMP = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int))
arr = (ctypes.c_int * 5)(5,2,4,1,3)
libc.qsort(arr, 5, ctypes.sizeof(ctypes.c_int), CMP(lambda a,b: a[0]-b[0]))
print("  qsort via callback:", list(arr))
assert list(arr) == [1,2,3,4,5]
print("  ctypes OK")
EOF

echo
echo "==== TLS ハンドシェイク（pypi へ実接続） ===="
"$PY" - <<'EOF'
import ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen("https://pypi.org/simple/", context=ctx, timeout=30) as r:
    print("  pypi:", r.status, r.headers.get("content-type"))
print("  OpenSSL:", ssl.OPENSSL_VERSION)
EOF

echo
echo "==== sqlite3 動作 ===="
"$PY" - <<'EOF'
import sqlite3
c = sqlite3.connect(":memory:")
c.execute("create table t(x)"); c.executemany("insert into t values(?)",[(i,) for i in range(10)])
print("  sqlite:", sqlite3.sqlite_version, "sum=", c.execute("select sum(x) from t").fetchone()[0])
EOF

echo
echo "smoke done"
