#!/bin/bash
# M2 側で実行するランナー。リポジトリを iBook に rsync してからスクリプトを回し、
# 生成ログを logs/ に持ち帰る。
#
#   ./run.sh                 # 同期のみ
#   ./run.sh 00_recon        # 同期 + scripts/00_recon.sh を実行
#   ./run.sh 40_build_cpython PY_VERSION=3.12.11
#
# 長時間ジョブは iBook 側の nohup で回すので、SSH が切れても継続する。
set -eu
HOST="${IBOOK_HOST:-ibook}"
REMOTE_DIR="apython3"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "[sync] -> $HOST:~/$REMOTE_DIR/"
rsync -az --delete \
  --exclude '.git' --exclude 'work/' --exclude 'dl/' \
  "$HERE/" "$HOST:$REMOTE_DIR/"

[ $# -eq 0 ] && { echo "[done] 同期のみ"; exit 0; }

SCRIPT="$1"; shift || true
ENVARGS="$*"
LOG="logs/${SCRIPT}.$(date +%Y%m%d-%H%M%S).log"

echo "[run] $HOST: scripts/$SCRIPT.sh $ENVARGS"
ssh "$HOST" "cd $REMOTE_DIR && mkdir -p logs && \
  nohup env $ENVARGS bash scripts/$SCRIPT.sh > $LOG 2>&1 & \
  echo \"  PID \$! -> ~/$REMOTE_DIR/$LOG\""

echo
echo "[tail] Ctrl-C で抜けてもジョブは継続。再開は: ssh $HOST 'tail -f $REMOTE_DIR/$LOG'"
sleep 2
ssh "$HOST" "tail -f $REMOTE_DIR/$LOG" || true
