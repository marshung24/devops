#!/usr/bin/env bash
# 安裝服務：把 repo 的 services/<服務>/ 同步到目標主機的 ~/<服務>/，只同步檔案、不啟動容器。
# 用法：不帶參數或加 -h 執行即印出（內容在 usage()）。
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
用法：tools/install.sh [-n] [-p <profile>] <服務> <ssh 主機>
  <服務>     services/ 下的目錄名，同步到主機 ~/<服務>/
  <ssh 主機>  ssh 可連的主機名或 user@host
  -n         預演：只列出會變動的檔案，不實際寫入
  -p         以本機 services/<服務>/.env.<profile> 作為主機的 .env，檔案不存在即報錯
             profile 只是設定檔檔名，通常與主機名相同但不一定
             未指定時依序找 .env.<主機名>、.env：本機有才同步覆蓋，都沒有就保留主機那份
             不論選到哪個檔，主機上一律存成 ~/<服務>/.env
             要上傳的設定檔須以 INSTALL_HOSTS 列出目標主機名（不是 profile），否則中止；空值時補填本次主機
例：tools/install.sh vpn-router minipc-01
    tools/install.sh -p minipc-02 traefik minipc-02
EOF
  exit 2
}

# 參數：-n 轉成 rsync 預演旗標，-p 指定 profile，其餘須剛好是服務與主機
dry=() profile=""
while getopts ":np:" opt; do
  case "$opt" in
    n) dry=(--dry-run) ;;
    p) [[ -n "$OPTARG" ]] || usage; profile=$OPTARG ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))
[[ $# -eq 2 ]] || usage
svc=$1 host=$2

# 來源目錄：以腳本位置推 repo 根目錄，不依賴目前工作目錄
root=$(cd "$(dirname "$0")/.." && pwd)
src="$root/services/$svc"
[[ -d "$src" ]] || { echo "找不到服務：services/$svc" >&2; exit 1; }

# 設定檔順序：-p 指定 > .env.<主機名> > .env；-p 指定的檔案不存在即報錯，不往下找
target=${host#*@}
[[ -n "$profile" || ! -f "$src/.env.$target" ]] || profile=$target

# profile：須於同步前確認存在
envfile="$src/.env"
if [[ -n "$profile" ]]; then
  envfile="$src/.env.$profile"
  [[ -f "$envfile" ]] || { echo "找不到 profile 檔：services/$svc/.env.$profile" >&2; exit 1; }
fi

# 防呆：本機有設定檔要上傳時，目標主機須列在其 INSTALL_HOSTS；空值視為首次部署，同步成功後綁定本次主機
fill=""
if [[ -f "$envfile" ]]; then
  name="services/$svc/${envfile##*/}"
  # 行首空白、export、等號旁空白、引號都是合法 dotenv 寫法，漏讀會被當成空值放行
  key='^[[:space:]]*(export[[:space:]]+)?INSTALL_HOSTS[[:space:]]*=[[:space:]]*'
  allowed=$(sed -nE "s/$key//p" "$envfile" | tr -d "\"'")
  if [[ -z "${allowed// /}" ]]; then
    fill=1
  elif [[ " $allowed " != *" $target "* ]]; then
    cat >&2 <<EOF
❌ 已中止，未同步任何檔案：$name 不允許部署到 $target。
   這份設定允許的主機：$allowed
   若繼續，其他主機的設定與密鑰會覆蓋 $target 的 ~/$svc/.env。
   處理方式：
     - 要部署到 $target：建立 .env.$target，或用 -p <profile> 指定 $target 的設定檔
     - 這份確定也適用 $target：把 $target 加進檔案的 INSTALL_HOSTS
EOF
    exit 1
  fi
fi

# 同步：以本機為準並刪除主機多餘檔案，-i 逐檔列出變動；主機 .env 不受影響，由下段處理
# 各 profile 含其他主機的設定與密鑰，一律不上傳；README.md 不經 rsync，改由下段加註後寫入
rsync -rlptzi --delete "${dry[@]}" \
  --include /.env.example --exclude /.env --exclude '/.env.*' --exclude /README.md \
  "$src/" "$host:$svc/"

# 選定的設定檔以 .env 名稱寫入主機，本機沒有就保留主機那份；預演時主機目錄可能尚未建立，只列出對應關係
# 用 --checksum：不同設定檔可能大小與時間相同，預設比對會跳過而留下舊設定
if [[ -f "$envfile" ]]; then
  echo "${envfile##*/} → $host:$svc/.env"
  [[ ${#dry[@]} -gt 0 ]] || rsync -ptz --checksum "$envfile" "$host:$svc/.env"
fi

# 補填須在同步成功後：主機打錯時才不會把設定檔綁到錯的名稱
if [[ -n "$fill" ]]; then
  if [[ ${#dry[@]} -gt 0 ]]; then
    echo "$name 的 INSTALL_HOSTS 為空，實際執行時會補填為 $target（預演）"
  else
    if grep -qE "$key" "$envfile"; then
      sed -i -E "s/$key.*/INSTALL_HOSTS=$target/" "$envfile"
    else
      printf '\nINSTALL_HOSTS=%s\n' "$target" >> "$envfile"
    fi
    echo "⚠️ $name 的 INSTALL_HOSTS 為空，已補填為 $target；之後只能部署到這台"
  fi
fi

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
