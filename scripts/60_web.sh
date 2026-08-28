#!/bin/bash
# Flask と Django を入れて、それぞれ最小アプリを起動→ curl で疎通確認。
#   注意: cryptography（Rust 必須）を引くパッケージは PPC Tiger では入らない。
#         Django コア / Flask コアは不要。必要になったら cryptography<3.4 を検討。
. "$(dirname "$0")/../env.sh"
PY="$PREFIX/bin/python3.12"
export SSL_CERT_FILE="$PREFIX/etc/cacert.pem"

echo "==== Flask ===="
"$PY" -m pip install "flask"
cat > "$WORK/flask_app.py" <<'EOF'
from flask import Flask
app = Flask(__name__)
@app.get("/")
def index():
    return {"ok": True, "framework": "flask"}
EOF
"$PY" -m flask --app "$WORK/flask_app.py" run --port 8001 &
FPID=$!
sleep 8
curl -s http://127.0.0.1:8001/ ; echo
kill $FPID 2>/dev/null

echo
echo "==== Django ===="
# 5.2 系は Python 3.10-3.13 対応
"$PY" -m pip install "django>=5.2,<5.3"
rm -rf "$WORK/djdemo" && mkdir -p "$WORK/djdemo" && cd "$WORK/djdemo"
"$PREFIX/bin/django-admin" startproject demo .
"$PY" manage.py migrate --noinput
"$PY" manage.py runserver 127.0.0.1:8002 &
DPID=$!
sleep 12
curl -s -o /dev/null -w "django runserver -> %{http_code}\n" http://127.0.0.1:8002/
kill $DPID 2>/dev/null

echo
echo "web stack done"
