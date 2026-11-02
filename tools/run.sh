#!/usr/bin/env bash
# 操作服務：在目標主機的 ~/<服務>/ 執行 docker compose 指令，或列出該服務的容器狀態。
# 服務須先以 tools/install.sh 安裝。
# 連線：一律經 ssh。建議在 ~/.ssh/config 為主機設 Host 別名（HostName／User／IdentityFile），
#       並以 ssh key 免密碼登入（ssh-keygen ＋ ssh-copy-id），<ssh 主機> 直接填別名，例：
#         Host minipc-01
#           HostName 192.168.1.21
#           User fetuser
#           IdentityFile ~/.ssh/id_ed25519
set -euo pipefail

# 印出用法並以 2 結束（參數錯誤）
usage() {
  cat >&2 <<'EOF'
用法：tools/run.sh [指令] <服務> <ssh 主機> [compose 服務...]
  [指令] 省略或 list          列出該服務 compose 定義的容器與狀態（不收 compose 服務）
  up|down|start|stop|restart  對應 docker compose 同名指令；up 一律加 -d 背景執行
  [compose 服務...]           只作用於指定容器；省略時作用於該服務全部容器
例：tools/run.sh traefik minipc-01
    tools/run.sh up vpn-router minipc-01 dashboard netbird-server
EOF
  exit 2
}

# 參數：第一個是已知指令才當指令，否則省略即 list；接著服務、主機必填，其餘為 compose 服務名
cmd=list
case "${1:-}" in up|down|start|stop|restart|list) cmd=$1; shift ;; esac
[[ $# -ge 2 ]] || usage
svc=$1 host=$2; shift 2
root=$(cd "$(dirname "$0")/.." && pwd)
[[ -d "$root/services/$svc" ]] || { echo "找不到服務：services/$svc" >&2; exit 1; }

case "$cmd" in
  # 狀態查詢：腳本整段送到主機執行，輸出每個 compose 服務一行「名稱 狀態 說明」
  list)
    [[ $# -eq 0 ]] || usage
    ssh "$host" bash -s -- "$svc" <<'EOF'
svc=$1
if [[ ! -f ~/$svc/compose.yaml ]]; then echo "$svc：未安裝"; exit 0; fi
cd ~/"$svc"
# 已建立的容器：以 compose project 標籤查，不受 .env 是否完整影響（project 名稱即服務目錄名）
states=$(docker ps -a --filter "label=com.docker.compose.project=$svc" \
  --format '{{.Label "com.docker.compose.service"}}	{{.State}}	{{.Status}}')
# 定義的服務：compose 解析失敗（多半是 .env 缺必填值）時退回只列已建立的容器
defined=$(docker compose config --services 2>/dev/null) \
  || { echo "(compose 設定不全，見 .env；只列已建立的容器)"; defined=$(cut -f1 <<<"$states"); }
# 逐一對上狀態，尚未建立的標「未建立」
for s in $defined; do
  line=$(awk -F'\t' -v s="$s" '$1==s{print $2"\t"$3}' <<<"$states")
  printf '%-16s %s\n' "$s" "${line:-未建立}"
done
EOF
    ;;
  # compose 操作：參數逐一跳脫後組成遠端指令，避免主機 shell 再解析
  up|down|start|stop|restart)
    args=("$cmd")
    [[ "$cmd" == up ]] && args+=(-d)
    args+=("$@")
    ssh "$host" "cd ~/$(printf %q "$svc") && docker compose $(printf '%q ' "${args[@]}")"
    ;;
  *) usage ;;
esac
