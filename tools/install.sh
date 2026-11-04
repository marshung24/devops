#!/usr/bin/env bash
# 安裝服務：把 repo 的 services/<服務>/ 同步到目標主機的 ~/<服務>/，只同步檔案、不啟動容器。
# 啟動與狀態查詢用 tools/run.sh；兩端皆需 rsync。
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
用法：tools/install.sh [-n] <服務> <ssh 主機>
  <服務>     services/ 下的目錄名，同步到主機 ~/<服務>/
  <ssh 主機>  ssh 可連的主機名或 user@host
  -n         預演：只列出會變動的檔案，不實際寫入
例：tools/install.sh vpn-router minipc-01
EOF
  exit 2
}

# 參數：可選 -n 轉成 rsync 預演旗標，其餘須剛好是服務與主機
dry=()
if [[ "${1:-}" == "-n" ]]; then dry=(--dry-run); shift; fi
[[ $# -eq 2 ]] || usage
svc=$1 host=$2

# 來源目錄：以腳本位置推 repo 根目錄，不依賴目前工作目錄
root=$(cd "$(dirname "$0")/.." && pwd)
src="$root/services/$svc"
[[ -d "$src" ]] || { echo "找不到服務：services/$svc" >&2; exit 1; }

# 同步：以本機為準並刪除主機多餘檔案；.env 受保護不被刪除（本機有才同步覆蓋，沒有就保留主機那份）；-i 逐檔列出變動
# README.md 不經 rsync，改由下段加註後寫入
rsync -rlptzi --delete "${dry[@]}" \
  --filter 'P .env' --exclude /README.md \
  "$src/" "$host:$svc/"

# README 加註作者（首次 commit 者）與最後更新（末次 commit 者與日期）；未提交時改記本機使用者與今天
readme="$src/README.md"
if [[ -f "$readme" ]]; then
  me=$(git -C "$root" config user.name || whoami)
  first=$(git -C "$root" log --follow --format='%an' -- "$readme" | tail -1)
  if git -C "$root" diff --quiet HEAD -- "$readme" 2>/dev/null && [[ -n "$first" ]]; then
    last_by=$(git -C "$root" log -1 --format='%an' -- "$readme")
    last_at=$(git -C "$root" log -1 --format='%ad' --date=short -- "$readme")
  else
    last_by=$me last_at="$(date +%F)（未 commit）"
  fi
  first=${first:-$me}
  # 最後更新者與作者相同時只寫日期
  [[ "$last_by" == "$first" ]] && last=$last_at || last="$last_by $last_at"
  stamp="作者：$first｜最後更新：$last"
  if [[ ${#dry[@]} -eq 0 ]]; then
    # 插在第 1 行標題之後，自成一段引言
    awk -v s="> $stamp" 'NR==1 {print; print ""; print s; next} 1' "$readme" | ssh "$host" "cat > '$svc/README.md'"
  fi
  echo "README.md ← $stamp"
fi

# 實際同步後檢查主機 .env：缺少時提醒，服務啟動前須先建立
if [[ ${#dry[@]} -eq 0 ]]; then
  ssh "$host" "test -f '$svc/.env'" \
    || echo "提醒：$host:~/$svc/.env 尚未建立，先 cp .env.example .env 再填值" >&2
fi
