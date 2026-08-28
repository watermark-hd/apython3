#!/bin/bash
# M2 側で実行。iBook のログ一式をローカル logs/ に取り込む。
set -eu
HOST="${IBOOK_HOST:-ibook}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
rsync -az "$HOST:apython3/logs/" "$HERE/logs/"
ls -lt "$HERE/logs/" | head -20
